output "cluster" {
  value = {
    name   = local.cluster_name
    id     = local.cluster_id
    master = local.master_ip
    workers = local.worker_ips_raw
  }
}

output "access" {
  value = {
    kubeconfig_file = ".generated/kubeconfig.yaml"
    ssh_user        = local.ssh_user
    ssh_master      = "${local.ssh_user}@${local.master_ip}"
  }
}

output "secrets" {
  sensitive = true
  value = {
    vm_private_key = tls_private_key.vm_key.private_key_pem
    vm_password    = random_password.vm_password.result
    k3s_token      = random_id.k3s_token.hex
  }
}
