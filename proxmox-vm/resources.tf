resource "proxmox_download_file" "latest_ubuntu_22_jammy_qcow2_img" {
  content_type = "import"
  datastore_id = "local"
  node_name    = "proxmox"
  url          = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
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

resource "local_file" "ssh_key" {
  content         = tls_private_key.ubuntu_vm_key.private_key_pem
  filename        = "${path.module}/vm_key.pem"
  file_permission = "0600"
}

resource "proxmox_virtual_environment_file" "master_cloud_init" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = "proxmox"

  source_raw {
    data = templatefile("${path.module}/templates/master-cloud-init.yaml", {
      cluster_id     = random_id.cluster_id.hex,
      ssh_public_key = trimspace(tls_private_key.ubuntu_vm_key.public_key_openssh),
      ssh_password   = random_password.ubuntu_vm_password.result,
      k3s_token      = random_id.k3s_token.hex,
      k3s_version    = "v1.30.0+k3s1",
      cluster_name   = "lab",
      master_address = "192.168.1.60",
      install_flags  = "--disable local-storage --disable traefik --disable metrics-server",
      other_flags    = ""
    })

    file_name = "k8s-master-cloud-init.yaml"
  }
}

resource "proxmox_virtual_environment_file" "worker_cloud_init" {
  count = var.workers.count

  content_type = "snippets"
  datastore_id = "local"
  node_name    = "proxmox"

  source_raw {
    data = templatefile("${path.module}/templates/worker-cloud-init.yaml", {
      cluster_id     = random_id.cluster_id.hex,
      node_name      = local.worker_names[count.index]
      ssh_public_key = trimspace(tls_private_key.ubuntu_vm_key.public_key_openssh),
      ssh_password   = random_password.ubuntu_vm_password.result,
      k3s_token      = random_id.k3s_token.hex,
      k3s_version    = "v1.30.0+k3s1",
      cluster_name   = "lab",
      master_address = "192.168.1.60",
      install_flags  = "--disable local-storage --disable traefik",
      other_flags    = ""
    })

    file_name = "k8s-worker-${count.index}-cloud-init.yaml"
  }
}


resource "random_id" "k3s_token" {
  byte_length = 32
}

resource "random_id" "cluster_id" {
  byte_length = 8
}

resource "random_id" "worker_node_id" {
  count       = var.workers.count
  byte_length = 8
}
