#!/usr/bin/env bash

set -euo pipefail

eval "$(jq -r '
  @sh "
    HOST=\(.host)
    SSH_USER=\(.ssh_user)
    SSH_KEY=\(.ssh_key)
  "
')"

# -------------------------
# SSH Agent Setup
# -------------------------
cleanup() {
  ssh-agent -k >/dev/null 2>&1 || true
}
trap cleanup EXIT

eval "$(ssh-agent -s)" >/dev/null
printf '%s\n' "$SSH_KEY" | ssh-add - >/dev/null 2>&1

SSH="ssh \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o BatchMode=yes \
  -o ConnectTimeout=5 \
  ${SSH_USER}@${HOST}"

# -------------------------
# Retry helper
# -------------------------
retry() {
  local attempts=$1
  local sleep_time=$2
  shift 2

  for ((i=1; i<=attempts; i++)); do
    if "$@"; then
      return 0
    fi
    echo "Attempt $i failed, retrying..." >&2
    sleep "$sleep_time"
  done

  return 1
}

# -------------------------
# Wait for SSH
# -------------------------
echo "Waiting for SSH..." >&2
retry 60 5 $SSH "echo ok" >/dev/null

# -------------------------
# Wait for cloud-init
# -------------------------
echo "Waiting for cloud-init..." >&2
retry 60 10 $SSH "cloud-init status --wait >/dev/null 2>&1"

# -------------------------
# Wait for kubeconfig
# -------------------------
KUBECONFIG_PATH="/etc/rancher/k3s/k3s.yaml"

echo "Waiting for kubeconfig..." >&2
retry 60 5 $SSH "sudo test -f $KUBECONFIG_PATH"

# -------------------------
# Fetch kubeconfig
# -------------------------
echo "Fetching kubeconfig..." >&2
sleep 2

KUBECONFIG=$(
  $SSH "sudo cat $KUBECONFIG_PATH"
)

# -------------------------
# Return result to Terraform
# -------------------------
jq -n \
  --arg kubeconfig "$KUBECONFIG" \
  '{kubeconfig:$kubeconfig}'