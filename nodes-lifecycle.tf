resource "null_resource" "worker_cleanup" {
  count = var.workers.count

  # depends_on = [
  #   proxmox_virtual_environment_vm.lxa-k8s-master
  # ]

  triggers = {
    node_name   = local.worker_names[count.index]
    master_ip   = local.master_ip
    ssh_user    = local.ssh_user
    private_key = nonsensitive(tls_private_key.vm_key.private_key_pem)
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

resource "null_resource" "cluster_credentials" {
  depends_on = [
    proxmox_virtual_environment_vm.lxa-k8s-master
  ]

  triggers = {
    master_ip   = local.master_ip
    ssh_user    = local.ssh_user
    private_key = nonsensitive(tls_private_key.vm_key.private_key_pem)
    kubeconfig_path = "${var.cluster.data_dir}/${local.cluster_name}/kubeconfig-${local.cluster_id}"
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
    set -euxo pipefail

    mkdir -p .generated

    echo "$SSH_KEY" > .generated/vm_key.pem
    chmod 600 .generated/vm_key.pem

    MASTER="${self.triggers.ssh_user}@${self.triggers.master_ip}"
    KUBECONFIG_PATH="${self.triggers.kubeconfig_path}"

    SSH_CMD="ssh -i .generated/vm_key.pem \
      -o StrictHostKeyChecking=no \
      -o UserKnownHostsFile=/dev/null \
      -o BatchMode=yes \
      -o ConnectTimeout=10"

    echo "Waiting for SSH..."

    for i in $(seq 1 60); do
      if $SSH_CMD $MASTER "echo ok" >/dev/null 2>&1; then
        echo "SSH ready"
        break
      fi

      echo "SSH not ready yet..."
      sleep 5
    done

    echo "Waiting for cloud-init..."

    for i in $(seq 1 60); do
      if $SSH_CMD $MASTER \
        "cloud-init status --wait >/dev/null 2>&1"
      then
        echo "Cloud-init finished"
        break
      fi

      echo "Cloud-init still running..."
      sleep 10
    done

    echo "Waiting for kubeconfig..."

    for i in $(seq 1 60); do
      if $SSH_CMD $MASTER \
        "sudo test -f $KUBECONFIG_PATH"
      then
        echo "Kubeconfig exists"
        break
      fi

      echo "Kubeconfig not ready..."
      sleep 5
    done

    echo "Downloading kubeconfig..."

    $SSH_CMD $MASTER \
      "sudo cat $KUBECONFIG_PATH" \
      > .generated/kubeconfig.yaml

    echo "Kubeconfig downloaded successfully"
    EOT
    }

}
