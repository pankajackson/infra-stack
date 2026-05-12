resource "local_file" "helmfile" {
  depends_on = [null_resource.generated_dir]

  content  = templatefile("${path.module}/templates/kube/helmfile.yaml", {
		metallb_enabled = local.metallb_enabled

		nginx_ingress_enabled = local.nginx_ingress_enabled
		nginx_ingress_loadbalancer_ip = local.nginx_ingress_loadbalancer_ip

		nfs_storage_enabled = local.nfs_storage_enabled
		nfs_storage_server = local.nfs_storage_server
		nfs_storage_path = local.nfs_storage_path
		nfs_storage_class = local.nfs_storage_class
		nfs_storage_default_class = local.nfs_storage_default_class

		headlamp_enabled = local.headlamp_enabled
		headlamp_hostname  = local.headlamp_hostname
	})
  filename = "${path.module}/.generated/helmfile.yaml"
}

resource "local_file" "metallb_config" {
  depends_on = [null_resource.generated_dir]
  
  content  = templatefile("${path.module}/templates/kube/metallb-config.yaml", {
		metallb_ipaddress_pool = local.metallb_ipaddress_pool
	})
  filename = "${path.module}/.generated/metallb-config.yaml"
}

resource "null_resource" "bootstrap" {
  depends_on = [
    null_resource.cluster_credentials,
    local_file.helmfile,
    local_file.metallb_config,
  ]

  triggers = {
    cluster_id = local.cluster_id

    helmfile_sha         = sha256(local_file.helmfile.content)
    metallb_config_sha   = sha256(local_file.metallb_config.content)
    # bootstrap_script_sha = sha256(local_file.bootstrap_script.content)
  }

  connection {
    type        = "ssh"
    host        = local.master_ip
    user        = local.ssh_user
    private_key = tls_private_key.vm_key.private_key_pem
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
    source      = "${path.module}/.generated/helmfile.yaml"
    destination = "/home/${local.ssh_user}/bootstrap/.generated/helmfile.yaml"
  }

  provisioner "file" {
    source      = "${path.module}/.generated/metallb-config.yaml"
    destination = "/home/${local.ssh_user}/bootstrap/.generated/metallb-config.yaml"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x ~/bootstrap/bootstrap.sh",
      "cd ~/bootstrap && sudo ROOT_DIR=$(pwd) ./bootstrap.sh"
    ]
  }
}