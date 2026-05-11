#!/usr/bin/env bash

set -euo pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

ROOT_DIR="${ROOT_DIR:-$(pwd)}"

GENERATED_DIR="${ROOT_DIR}/.generated"
BIN_DIR="${GENERATED_DIR}/bin"

HELMFILE_VERSION="v1.1.4"

mkdir -p "${BIN_DIR}"

export KUBECONFIG="/etc/rancher/k3s/k3s.yaml"
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

  error "kubectl not found"
  exit 1
}

# -----------------------------------------------------------------------------
# Helm
# -----------------------------------------------------------------------------

ensure_helm() {
  if command_exists helm; then
    log "Using system helm: $(command -v helm)"
    return
  fi

  local local_helm="${BIN_DIR}/helm"

  if [ -x "${local_helm}" ]; then
    log "Using local helm: ${local_helm}"
    return
  fi

  log "Downloading helm..."

  local os
  local arch
  local tmp_dir

  os="$(uname -s | tr '[:upper:]' '[:lower:]')"
  arch="$(detect_arch)"

  tmp_dir="$(mktemp -d)"

  curl -fsSL \
    -o "${tmp_dir}/helm.tar.gz" \
    "https://get.helm.sh/helm-v3.18.1-${os}-${arch}.tar.gz"

  tar -xzf "${tmp_dir}/helm.tar.gz" \
    -C "${tmp_dir}"

  mv "${tmp_dir}/${os}-${arch}/helm" "${local_helm}"

  chmod +x "${local_helm}"

  rm -rf "${tmp_dir}"

  log "helm downloaded"
}

# -----------------------------------------------------------------------------
# Helm Diff Plugin
# -----------------------------------------------------------------------------

ensure_helm_diff() {
  if helm plugin list | grep -q diff; then
    log "Helm diff plugin already installed"
    return
  fi

  log "Installing helm diff plugin..."

  helm plugin install https://github.com/databus23/helm-diff

  log "Helm diff plugin installed"
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
  ensure_kubectl
  kubectl version --client

  ensure_helm
  helm version

  ensure_helm_diff

  ensure_helmfile
  helmfile version

  wait_for_nodes_ready

  apply_helmfile

  wait_for_metallb_ready

  apply_metallb_config

  log "Bootstrap completed successfully"
}

main "$@"