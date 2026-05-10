resource "null_resource" "worker_cleanup" {
  count = var.workers.count

  triggers = {
    node_name   = local.worker_names[count.index]
    master_ip   = local.master_ip
    ssh_user    = local.ssh_user
    private_key = nonsensitive(tls_private_key.vm_key.private_key_pem)
  }

  lifecycle {
    replace_triggered_by = [
      time_static.master_identifier
    ]
  }

  provisioner "local-exec" {
    when = destroy

    environment = {
      SSH_KEY = self.triggers.private_key
    }

    command = <<EOT
eval "$(ssh-agent -s)"
echo "$SSH_KEY" | ssh-add -

ssh -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  ${self.triggers.ssh_user}@${self.triggers.master_ip} \
  "sudo /usr/local/bin/k8s-worker-cleanup.sh ${self.triggers.node_name}"

ssh-agent -k
EOT
  }
}

resource "null_resource" "new_worker_lifecycle" {
  count = var.workers.count

  triggers = {
    node_name   = local.worker_names[count.index]
    master_ip   = local.master_ip
    ssh_user    = local.ssh_user
    private_key = nonsensitive(tls_private_key.vm_key.private_key_pem)
  }

  lifecycle {
    replace_triggered_by = [
      time_static.master_identifier
    ]
  }

  provisioner "local-exec" {
    when = create

    environment = {
      SSH_KEY = self.triggers.private_key
    }

    command = <<EOT
	eval "$(ssh-agent -s)"
	echo "$SSH_KEY" | ssh-add -

	ssh -o StrictHostKeyChecking=no \
		-o UserKnownHostsFile=/dev/null \
    ${self.triggers.ssh_user}@${self.triggers.master_ip} \
  "sudo /usr/local/bin/k8s-node-label.sh ${self.triggers.node_name}"

	ssh-agent -k
	EOT
  }

}

resource "null_resource" "fetch_kubeconfig" {

  triggers = {
    master_ip   = local.master_ip
    ssh_user    = local.ssh_user
    private_key = nonsensitive(tls_private_key.vm_key.private_key_pem)
    kubeconfig_path = "${var.cluster.data_dir}/${local.cluster_name}/kubeconfig-${local.cluster_id}"
    some="thing"
  }

  lifecycle {
    replace_triggered_by = [
      time_static.master_identifier
    ]
  }

  provisioner "local-exec" {
    when = create

    environment = {
      SSH_KEY = self.triggers.private_key
    }

    command = <<EOT
	eval "$(ssh-agent -s)"
	echo "$SSH_KEY" | ssh-add -

  ssh -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    ${self.triggers.ssh_user}@${self.triggers.master_ip} \
    "sudo cat ${self.triggers.kubeconfig_path}" > kubeconfig.yaml

	ssh-agent -k
	EOT
  }

}
