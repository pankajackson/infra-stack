locals {
  worker_count = 2
}

resource "proxmox_virtual_environment_vm" "lxa-k8s-worker" {
  count = local.worker_count

  name        = local.worker_names[count.index]
  description = "Managed by Terraform"
  tags        = ["terraform", "ubuntu"]
  node_name   = "proxmox"
  vm_id       = 4321 + count.index + 1

  agent {
    # read 'Qemu guest agent' section, change to true only when ready
    enabled = true
    timeout = "5m"
    wait_for_ip {
      ipv4 = true
    }
  }

  # if agent is not enabled, the VM may not be able to shutdown properly, and may need to be forced off
  stop_on_destroy = true

  startup {
    order      = "3"
    up_delay   = "60"
    down_delay = "60"
  }

  cpu {
    cores = 2
    type  = "x86-64-v2-AES" # recommended for modern CPUs
  }

  memory {
    dedicated = 2048
    floating  = 2048 # set equal to dedicated to enable ballooning
  }

  disk {
    datastore_id = "local-lvm"
    import_from  = proxmox_download_file.latest_ubuntu_22_jammy_qcow2_img.id
    interface    = "scsi0"
    size         = 20
  }

  disk {
    datastore_id = "local-lvm"
    interface    = "scsi1"
    size         = 30
  }

  initialization {
    ip_config {
      ipv4 {
        address = "192.168.1.${61 + count.index}/24"
        gateway = "192.168.1.1"
      }
    }

    user_data_file_id = proxmox_virtual_environment_file.worker_cloud_init[count.index].id

  }

  network_device {
    bridge = "vmbr0"
  }

  operating_system {
    type = "l26"
  }

  tpm_state {
    version = "v2.0"
  }

  serial_device {}

}
