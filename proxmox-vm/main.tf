resource "proxmox_virtual_environment_vm" "ubuntu_vm" {
  name        = "terraform-provider-proxmox-ubuntu-vm"
  description = "Managed by Terraform"
  tags        = ["terraform", "ubuntu"]

  node_name = "proxmox"
  vm_id     = 4321

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
    cores        = 2
    type         = "x86-64-v2-AES"  # recommended for modern CPUs
  }

  memory {
    dedicated = 2048
    floating  = 2048 # set equal to dedicated to enable ballooning
  }

  disk {
    datastore_id = "local-lvm"
    import_from  = proxmox_download_file.latest_ubuntu_22_jammy_qcow2_img.id
    interface    = "scsi0"
    size = 20
  }

  disk {
    datastore_id = "local-lvm"
    interface    = "scsi1"
    size = 30
  }

  initialization {
    ip_config {
      ipv4 {
          address = "192.168.1.60/24"
          gateway = "192.168.1.1"
      }
    }

    user_data_file_id = proxmox_virtual_environment_file.cloud_config.id

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

  # virtiofs {
  #   mapping = "data_share"
  #   cache = "always"
  #   direct_io = true
  # }
}

resource "proxmox_download_file" "latest_ubuntu_22_jammy_qcow2_img" {
  content_type = "import"
  datastore_id = "local"
  node_name    = "proxmox"
  url = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
  # need to rename the file to *.qcow2 to indicate the actual file format for import
  file_name = "jammy-server-cloudimg-amd64.qcow2"
}

resource "random_password" "ubuntu_vm_password" {
  length           = 16
  override_special = "_%@"
  special          = true
}

resource "tls_private_key" "ubuntu_vm_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "proxmox_virtual_environment_file" "cloud_config" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = "proxmox"

  source_raw {
    data = templatefile("${path.module}/cloud-init.yaml", {
        ssh_public_key = trimspace(tls_private_key.ubuntu_vm_key.public_key_openssh),
        ssh_password_hash = bcrypt(random_password.ubuntu_vm_password.result)
		})

    file_name = "cloud-config.yaml"
  }
}

