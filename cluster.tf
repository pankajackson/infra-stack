resource "proxmox_download_file" "os_image" {
  count = var.os.image.download ? 1 : 0
  
  content_type = "import"
  datastore_id = var.os.image.datastore_id
  node_name    = coalesce(var.os.image.node_name, var.proxmox.node)
  url          = var.os.image.url
  file_name    = var.os.image.file_name
  overwrite = var.os.image.overwrite
  overwrite_unmanaged = var.os.image.overwrite_unmanaged
}

resource "random_id" "k3s_token" {
  byte_length = 32
}

resource "random_id" "cluster_id" {
  byte_length = 8
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

resource "proxmox_virtual_environment_file" "master_cloud_init" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = "proxmox"

  source_raw {
    data = templatefile("${path.module}/templates/master-cloud-init.yaml", {
      cluster_id     = random_id.cluster_id.hex,
      cluster_name   = var.cluster.name,
      node_packages  = local.node_packages,
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

resource "random_id" "worker_node_id" {
  count       = var.workers.count
  byte_length = 4
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
      node_packages  = local.node_packages,
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

resource "null_resource" "generated_dir" {
  provisioner "local-exec" {
    command = "mkdir -p .generated"
  }
}

resource "local_file" "vm_private_key" {
  depends_on = [null_resource.generated_dir]

  content         = tls_private_key.vm_key.private_key_pem
  filename        = ".generated/vm_key.pem"
  file_permission = "0600"
}

resource "null_resource" "cluster_credentials" {
  depends_on = [
    proxmox_virtual_environment_vm.lxa-k8s-master,
    local_file.vm_private_key,
    null_resource.generated_dir
  ]

  triggers = {
    master_ip       = local.master_ip
    ssh_user        = local.ssh_user
    kubeconfig_path = "${var.cluster.data_dir}/${local.cluster_name}/kubeconfig-${local.cluster_id}"
    cluster_id      = local.cluster_id
  }

  lifecycle {
    replace_triggered_by = [
      time_static.master_identifier
    ]
  }

  provisioner "local-exec" {

    when = create

    command = <<EOT
set -euo pipefail

MASTER="${self.triggers.ssh_user}@${self.triggers.master_ip}"
KUBECONFIG_PATH="${self.triggers.kubeconfig_path}"

SSH="ssh \
  -i .generated/vm_key.pem \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o BatchMode=yes \
  -o ConnectTimeout=10 \
  -o ServerAliveInterval=5 \
  -o ServerAliveCountMax=2"

retry() {
  local attempts=$1
  local sleep_time=$2
  shift 2

  for ((i=1; i<=attempts; i++)); do
    if "$@"; then
      return 0
    fi

    echo "Attempt $i failed..."
    sleep "$sleep_time"
  done

  return 1
}

echo "Waiting for SSH..."
retry 60 5 \
  $SSH $MASTER "echo ok"

echo "Waiting for cloud-init..."
retry 60 10 \
  $SSH $MASTER "cloud-init status --wait >/dev/null 2>&1"

echo "Waiting for kubeconfig..."
retry 60 5 \
  $SSH $MASTER "sudo test -f $KUBECONFIG_PATH"

echo "Downloading kubeconfig..."

$SSH $MASTER \
  "sudo cat $KUBECONFIG_PATH" \
  > .generated/kubeconfig.yaml

chmod 600 .generated/kubeconfig.yaml

echo "Kubeconfig downloaded successfully"
EOT
  }
}
