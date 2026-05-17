# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog:
https://keepachangelog.com/en/1.1.0/

---

## [0.0.2] - 2026-05-17

### Added

- Added support for Proxmox VM tags using `cluster.tags`
- Added support for reusing existing Proxmox cloud images
- Added configurable image download behavior:
  - `os.image.download`
  - `os.image.overwrite`
  - `os.image.overwrite_unmanaged`
- Added validation for `addons.nfs_storage`
- Added structured outputs:
  - `cluster`
  - `access`
  - `secrets`

### Changed

- Removed dependency on shared NFS storage for cluster bootstrap
- Cluster join metadata and kubeconfig are now coordinated using Terraform state
- Refactored resource dependencies to reduce unnecessary destruction/recreation
- Simplified bootstrap lifecycle and provisioning flow
- Improved module portability by removing external shared storage requirements
- Updated README and examples to reflect new architecture

### Removed

- Removed mandatory shared NFS requirement for kubeconfig/join command distribution

### Notes

This release significantly simplifies deployment architecture.

Previous versions required shared NFS storage between nodes to exchange:

- K3s join command
- kubeconfig
- bootstrap metadata

The module now stores and manages bootstrap state directly in Terraform state, making the module fully self-contained.

NFS is now only required when using the optional `addons.nfs_storage` addon.

---

## [0.0.1] - 2026-05-16

### Initial Release

Initial release of the Terraform Proxmox K3s module.

#### Features

- Automated K3s cluster provisioning on Proxmox VE
- Cloud-init based VM provisioning
- Automatic worker join lifecycle
- Static IP auto-allocation
- SSH key generation
- Kubeconfig export
- Helmfile-based addon deployment
- Optional Kubernetes addons:
  - MetalLB
  - NGINX Ingress
  - NFS Storage
  - Headlamp
- Automatic Proxmox VM ID allocation
- Shared NFS-based cluster coordination
