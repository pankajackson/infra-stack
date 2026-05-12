output "cluster_name" {
  value = local.cluster_name
}

output "cluster_id" {
  value = local.cluster_id
}

output "master_ip" {
  value = local.master_ip
}

output "worker_ips" {
  value = [
    for vm in proxmox_virtual_environment_vm.lxa-k8s-worker :
    vm.ipv4_addresses[1][0]
  ]
}

output "vm_password" {
  value     = random_password.vm_password.result
  sensitive = true
}

output "vm_private_key" {
  value     = tls_private_key.vm_key.private_key_pem
  sensitive = true
}

output "vm_public_key" {
  value = tls_private_key.vm_key.public_key_openssh
}

output "k3s_token" {
  value     = random_id.k3s_token.hex
  sensitive = true
}

output "kubeconfig_path" {
  value = "${path.module}/.generated/kubeconfig.yaml"
}

output "kubeconfig_export_command" {
  value = "export KUBECONFIG=${path.module}/.generated/kubeconfig.yaml"
}

output "master_ssh_command" {
  value = "ssh -i .generated/vm_key.pem ${local.ssh_user}@${local.master_ip}"
}