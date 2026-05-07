resource "proxmox_virtual_environment_vm" "lxa-k8s-worker" {
  count = var.workers.count

  name        = local.worker_names[count.index]
  description = "LXA k8s worker node"
  tags        = ["terraform", "lxa", "kube", "worker"]
  node_name   = var.proxmox.node_name
  vm_id       = local.worker_vmids[count.index]

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
    cores = var.workers.cpu
    type  = var.proxmox.cpu_type
  }

  memory {
    dedicated = var.workers.memory
    floating  = var.workers.memory # set equal to dedicated to enable ballooning
  }

  disk {
    datastore_id = var.proxmox.disk_datastore_id
    import_from  = proxmox_download_file.latest_ubuntu_22_jammy_qcow2_img.id
    interface    = "scsi0"
    size         = var.workers.disk
  }

  initialization {
    ip_config {
      ipv4 {
        address = local.worker_ips[count.index]
        gateway = var.network.gateway
      }
    }

    user_data_file_id = proxmox_virtual_environment_file.worker_cloud_init[count.index].id

  }

  network_device {
    bridge = var.network.bridge
  }

  operating_system {
    type = "l26"
  }

  tpm_state {
    version = "v2.0"
  }

  serial_device {}

}
