resource "proxmox_virtual_environment_vm" "lxa-k8s-master" {
  name        = local.master_name
  description = "${local.cluster_name} k8s master node"
  tags        = concat(coalesce(var.cluster.tags, []), [local.cluster_name, "master"])

  node_name = var.proxmox.node
  vm_id     = local.master_vmid

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
    cores = coalesce(var.master.cpu, var.defaults.cpu)
    type  = var.proxmox.cpu_type
  }

  memory {
    dedicated = coalesce(var.master.memory, var.defaults.memory)
    floating  = coalesce(var.master.memory, var.defaults.memory) # set equal to dedicated to enable ballooning
  }

  disk {
    datastore_id = var.proxmox.disk_datastore_id
    import_from  = local.os_image_file_id
    interface    = "scsi0"
    size         = coalesce(var.master.disk, var.defaults.disk)
  }

  initialization {
    ip_config {
      ipv4 {
        address = local.master_ip_cidr
        gateway = var.network.gateway
      }
    }

    user_data_file_id = proxmox_virtual_environment_file.master_cloud_init.id

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

resource "time_static" "master_identifier" {
  triggers = {
    vm = proxmox_virtual_environment_vm.lxa-k8s-master.id
  }
}