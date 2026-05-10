#!/usr/bin/env bash

set -euo pipefail

# -----------------------------------------------------------------------------
# Configuration (from environment)
# -----------------------------------------------------------------------------

# ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${ROOT_DIR}" # from environment
GENERATED_DIR="${ROOT_DIR}/.generated"
BIN_DIR="${GENERATED_DIR}/bin"

KUBECONFIG_PATH="${GENERATED_DIR}/kubeconfig.yaml"
SSH_KEY_PATH="${GENERATED_DIR}/vm_key.pem"

SSH_USER="${SSH_USER}"
MASTER_IP="${MASTER_IP}"

HELMFILE_VERSION="v1.1.4"

SSH_OPTS=(
  -i "${SSH_KEY_PATH}"
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null
)

mkdir -p "${BIN_DIR}"

export KUBECONFIG="${KUBECONFIG_PATH}"
export PATH="${BIN_DIR}:${PATH}"

# -----------------------------------------------------------------------------
# Logging
# -----------------------------------------------------------------------------

log() {
  echo "[INFO] $*"
}

error() {
  echo "[ERROR] $*" >&2
}

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

detect_arch() {
  local arch
  arch="$(uname -m)"

  case "${arch}" in
    x86_64)
      echo "amd64"
      ;;
    aarch64)
      echo "arm64"
      ;;
    armv7l)
      echo "arm"
      ;;
    *)
      error "Unsupported architecture: ${arch}"
      exit 1
      ;;
  esac
}

# -----------------------------------------------------------------------------
# Kubectl
# -----------------------------------------------------------------------------

ensure_kubectl() {
  if command_exists kubectl; then
    log "Using system kubectl: $(command -v kubectl)"
    return
  fi

  local local_kubectl="${BIN_DIR}/kubectl"

  if [ -x "${local_kubectl}" ]; then
    log "Using local kubectl: ${local_kubectl}"
    return
  fi

  log "Downloading kubectl from K3s master..."

  scp "${SSH_OPTS[@]}" \
    "${SSH_USER}@${MASTER_IP}:/usr/local/bin/kubectl" \
    "${local_kubectl}"

  chmod +x "${local_kubectl}"

  log "kubectl downloaded"
}

# -----------------------------------------------------------------------------
# Helmfile
# -----------------------------------------------------------------------------

ensure_helmfile() {
  if command_exists helmfile; then
    log "Using system helmfile: $(command -v helmfile)"
    return
  fi

  local local_helmfile="${BIN_DIR}/helmfile"

  if [ -x "${local_helmfile}" ]; then
    log "Using local helmfile: ${local_helmfile}"
    return
  fi

  log "Downloading helmfile..."

  local os
  local arch
  local tmp_dir

  os="$(uname -s | tr '[:upper:]' '[:lower:]')"
  arch="$(detect_arch)"

  tmp_dir="$(mktemp -d)"

  curl -fsSL \
    -o "${tmp_dir}/helmfile.tar.gz" \
    "https://github.com/helmfile/helmfile/releases/download/${HELMFILE_VERSION}/helmfile_${HELMFILE_VERSION#v}_${os}_${arch}.tar.gz"

  tar -xzf "${tmp_dir}/helmfile.tar.gz" \
    -C "${tmp_dir}" \
    helmfile

  mv "${tmp_dir}/helmfile" "${local_helmfile}"

  chmod +x "${local_helmfile}"

  rm -rf "${tmp_dir}"

  log "helmfile downloaded"
}

# -----------------------------------------------------------------------------
# Cluster Readiness
# -----------------------------------------------------------------------------

wait_for_nodes_ready() {
  log "Waiting for Kubernetes nodes to become Ready..."

  kubectl wait \
    --for=condition=Ready nodes \
    --all \
    --timeout=10m

  log "All nodes are Ready"
}

wait_for_metallb_ready() {
  log "Waiting for MetalLB controller..."

  kubectl wait \
    --namespace metallb-system \
    --for=condition=Available deployment/controller \
    --timeout=5m

  log "MetalLB controller is Ready"
}

# -----------------------------------------------------------------------------
# Bootstrap
# -----------------------------------------------------------------------------

apply_helmfile() {
  log "Applying Helmfile..."

  KUBECONFIG="${KUBECONFIG_PATH}" \
  helmfile -f "${GENERATED_DIR}/helmfile.yaml" apply

  log "Helmfile applied"
}

apply_metallb_config() {
  log "Applying MetalLB configuration..."

  kubectl apply -f "${GENERATED_DIR}/metallb-config.yaml"

  log "MetalLB configuration applied"
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

main() {
  : "${SSH_USER:?SSH_USER not set}"
  : "${MASTER_IP:?MASTER_IP not set}"

  ensure_kubectl
  kubectl version --client

  ensure_helmfile
  helmfile version

  echo "$KUBECONFIG"

  wait_for_nodes_ready

  apply_helmfile

  wait_for_metallb_ready

  apply_metallb_config

  log "Bootstrap completed successfully"
}

main "$@"