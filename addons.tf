resource "local_file" "helmfile" {
  count      = local.addons_enabled ? 1 : 0
  depends_on = [null_resource.generated_dir]

  content = templatefile("${path.module}/templates/kube/helmfile.yaml", {
    metallb_enabled = local.metallb_enabled

    nginx_ingress_enabled         = local.nginx_ingress_enabled
    nginx_ingress_loadbalancer_ip = local.nginx_ingress_loadbalancer_ip

    nfs_storage_enabled       = local.nfs_storage_enabled
    nfs_storage_server            = local.nfs_storage_server != null ? local.nfs_storage_server : ""
    nfs_storage_path              = local.nfs_storage_path   != null ? local.nfs_storage_path   : ""
    nfs_storage_class         = local.nfs_storage_class
    nfs_storage_default_class = local.nfs_storage_default_class

    headlamp_enabled  = local.headlamp_enabled
    headlamp_hostname = local.headlamp_hostname
  })
  filename = "${path.root}/.generated/helmfile.yaml"
}

resource "local_file" "metallb_config" {
  count      = local.metallb_enabled ? 1 : 0
  depends_on = [null_resource.generated_dir]

  content = templatefile("${path.module}/templates/kube/metallb-config.yaml", {
    metallb_ipaddress_pool = local.metallb_ipaddress_pool
  })
  filename = "${path.root}/.generated/metallb-config.yaml"
}

resource "null_resource" "addons_bootstrap" {
  count = local.addons_enabled ? 1 : 0

  depends_on = [
    data.external.kubeconfig,
    local_file.helmfile,
  ]

  triggers = {
    cluster_id   = local.cluster_id
    helmfile_sha = sha256(local_file.helmfile[0].content)
  }

  connection {
    type        = "ssh"
    host        = local.master_ip
    user        = local.ssh_user
    private_key = nonsensitive(tls_private_key.vm_key.private_key_pem)
  }

  provisioner "remote-exec" {
    inline = [
      "mkdir -p ~/bootstrap/.generated"
    ]
  }

  provisioner "file" {
    source      = "${path.module}/scripts/bootstrap.sh"
    destination = "/home/${local.ssh_user}/bootstrap/bootstrap.sh"
  }

  provisioner "file" {
    source      = "${path.root}/.generated/helmfile.yaml"
    destination = "/home/${local.ssh_user}/bootstrap/.generated/helmfile.yaml"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x ~/bootstrap/bootstrap.sh",
      "cd ~/bootstrap && sudo ROOT_DIR=$(pwd) ./bootstrap.sh"
    ]
  }
}

resource "null_resource" "addons_metallb_configurator" {
  count = local.metallb_enabled ? 1 : 0

  depends_on = [
    null_resource.addons_bootstrap,
    local_file.metallb_config,
  ]

  triggers = {
    cluster_id   = local.cluster_id
    helmfile_sha = sha256(local_file.metallb_config[0].content)
  }

  connection {
    type        = "ssh"
    host        = local.master_ip
    user        = local.ssh_user
    private_key = nonsensitive(tls_private_key.vm_key.private_key_pem)
  }

  provisioner "file" {
    source      = "${path.root}/.generated/metallb-config.yaml"
    destination = "/home/${local.ssh_user}/bootstrap/.generated/metallb-config.yaml"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x ~/bootstrap/bootstrap.sh",
      "cd ~/bootstrap && sudo ROOT_DIR=$(pwd) ./bootstrap.sh --setup-addons metallb"
    ]
  }
}