output "cluster" {
  description = "Provisioned K3s cluster information including cluster name, unique identifier, master node IP address, and worker node IP addresses."

  value = {
    name    = local.cluster_name
    id      = local.cluster_id
    master  = local.master_ip
    workers = local.worker_ips_raw
  }
}

output "access" {
  description = "Cluster access details including generated kubeconfig, SSH username, and SSH connection string for the master node."

  value = {
    kubeconfig_file = ".generated/kubeconfig.yaml"
    ssh_user        = local.ssh_user
    ssh_master      = "${local.ssh_user}@${local.master_ip}"
  }
}

output "secrets" {
  description = "Sensitive cluster credentials and generated secrets including VM SSH private key, VM password, K3s cluster token, and kubeconfig content."

  sensitive = true

  value = {
    vm_private_key = tls_private_key.vm_key.private_key_pem
    vm_password    = random_password.vm_password.result
    k3s_token      = random_id.k3s_token.hex
    kubeconfig     = data.external.kubeconfig.result.kubeconfig
  }
}
