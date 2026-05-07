resource "null_resource" "worker_cleanup" {
  count = var.workers.count

  triggers = {
    node_name   = "lxa-lab-worker-${count.index}-${random_id.worker_node_id[count.index].hex}"
    private_key = nonsensitive(tls_private_key.ubuntu_vm_key.private_key_pem)
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
  ubuntu@192.168.1.60 \
  "sudo /usr/local/bin/k8s-worker-cleanup.sh ${self.triggers.node_name}"

ssh-agent -k
EOT
  }

}

resource "null_resource" "new_worker_lifecycle" {
  count = var.workers.count

  triggers = {
    node_name   = "lxa-lab-worker-${count.index}-${random_id.worker_node_id[count.index].hex}"
    private_key = nonsensitive(tls_private_key.ubuntu_vm_key.private_key_pem)
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
		ubuntu@192.168.1.60 \
  "sudo /usr/local/bin/k8s-node-label.sh ${self.triggers.node_name}"

	ssh-agent -k
	EOT
  }

}
