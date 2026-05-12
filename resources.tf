resource "proxmox_download_file" "latest_ubuntu_22_jammy_qcow2_img" {
  content_type = "import"
  datastore_id = var.os.image.datastore_id
  node_name    = var.os.image.node_name
  url          = var.os.image.url
  file_name    = var.os.image.file_name
}

resource "random_password" "vm_password" {
  length           = 16
  override_special = "_%@"
  special          = true
}

resource "tls_private_key" "vm_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# resource "local_file" "ssh_key" {
#   content         = tls_private_key.vm_key.private_key_pem
#   filename        = "${path.module}/vm_key.pem"
#   file_permission = "0600"
# }

resource "proxmox_virtual_environment_file" "master_cloud_init" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = "proxmox"

  source_raw {
    data = templatefile("${path.module}/templates/master-cloud-init.yaml", {
      cluster_id     = random_id.cluster_id.hex,
      cluster_name   = var.cluster.name,
      ssh_user       = local.ssh_user
      ssh_public_key = trimspace(tls_private_key.vm_key.public_key_openssh),
      ssh_password   = random_password.vm_password.result,
      k3s_token      = coalesce(var.k3s.token, random_id.k3s_token.hex),
      k3s_version    = var.k3s.version,
      master_address = local.master_ip,
      install_flags  = local.k3s_master_args,
      other_flags    = local.k3s_extra_args
      data_dir       = var.cluster.data_dir,
      nfs_server     = var.network.nfs.server,
      nfs_path       = var.network.nfs.path,
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
      cluster_name   = var.cluster.name,
      node_name      = local.worker_names[count.index]
      ssh_user       = local.ssh_user
      ssh_public_key = trimspace(tls_private_key.vm_key.public_key_openssh),
      ssh_password   = random_password.vm_password.result,
      data_dir       = var.cluster.data_dir,
      nfs_server     = var.network.nfs.server,
      nfs_path       = var.network.nfs.path,
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
  byte_length = 4
}
