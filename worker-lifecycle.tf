resource "null_resource" "worker_cleanup" {
  count = var.workers.count

  triggers = {
    node_name   = local.worker_names[count.index]
    master_ip   = local.master_ip
    ssh_user    = local.ssh_user
    private_key = tls_private_key.vm_key.private_key_pem
  }

  # lifecycle {
  #   replace_triggered_by = [
  #     time_static.master_identifier
  #   ]
  # }

  provisioner "local-exec" {
    when = destroy

    environment = {
      SSH_KEY = self.triggers.private_key
    }

    command = <<EOT
set -euo pipefail

mkdir -p .generated

echo "$SSH_KEY" > .generated/vm_key.pem
chmod 600 .generated/vm_key.pem

MASTER="${self.triggers.ssh_user}@${self.triggers.master_ip}"
NODE="${self.triggers.node_name}"

SSH_CMD="ssh -i .generated/vm_key.pem \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o BatchMode=yes \
  -o ConnectTimeout=10 \
  -o ServerAliveInterval=5 \
  -o ServerAliveCountMax=2"

echo "Checking master availability..."

if ! $SSH_CMD $MASTER "echo ok" >/dev/null 2>&1; then
  echo "Master already unavailable. Skipping cleanup."
  exit 0
fi

echo "Running worker cleanup for $NODE"

timeout 180 $SSH_CMD $MASTER \
  "sudo -n /usr/local/bin/k8s-worker-cleanup.sh $NODE" \
  || echo "Cleanup interrupted or timed out. Continuing destroy."

echo "Worker cleanup finished"
EOT
  }
}

resource "null_resource" "new_worker_lifecycle" {
  count = var.workers.count

  triggers = {
    node_name   = local.worker_names[count.index]
    master_ip   = local.master_ip
    ssh_user    = local.ssh_user
    private_key = tls_private_key.vm_key.private_key_pem
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
