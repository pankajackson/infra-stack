resource "local_file" "helmfile" {
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
  content  = templatefile("${path.module}/templates/kube/metallb-config.yaml", {
		metallb_ipaddress_pool = local.metallb_ipaddress_pool
	})
  filename = "${path.module}/.generated/metallb-config.yaml"
}

# resource "local_file" "bootstrap_script" {
#   content  = templatefile("${path.module}/templates/scripts/bootstrap.sh", {
# 		ssh_user       = local.ssh_user
# 		master_address = local.master_ip
# 	})
#   filename = "${path.module}/.generated/bootstrap.sh"

#   file_permission = "0755"
# }

resource "null_resource" "bootstrap" {
  depends_on = [
    null_resource.cluster_credentials,
    local_file.helmfile,
    local_file.metallb_config,
    # local_file.bootstrap_script
  ]

  triggers = {
    cluster_id = local.cluster_id

    helmfile_sha         = sha256(local_file.helmfile.content)
    metallb_config_sha   = sha256(local_file.metallb_config.content)
    # bootstrap_script_sha = sha256(local_file.bootstrap_script.content)
  }

  provisioner "local-exec" {
  environment = {
    SSH_USER  = local.ssh_user
    MASTER_IP = local.master_ip
		ROOT_DIR = path.module
  }
    working_dir = path.module

    command = <<EOT
      chmod +x ${path.module}/scripts/bootstrap.sh
      ./${path.module}/scripts/bootstrap.sh
    EOT
  }
}