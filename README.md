# Terraform Proxmox K3s Cluster Module

A production-ready Terraform module to provision a full **K3s Kubernetes cluster on Proxmox VE**, including master, worker nodes, networking, and optional cluster addons (MetalLB, NGINX ingress, NFS storage, Headlamp).

This module automates:

- VM provisioning on Proxmox
- Cloud-init based OS bootstrap
- K3s cluster installation (master + workers)
- Worker lifecycle management (join + cleanup)
- Optional addons deployment
- Kubeconfig generation

---

## ✨ Features

- 🚀 Fully automated K3s cluster provisioning
- 🧠 Smart retry logic for SSH / cloud-init readiness
- 🧹 Safe worker cleanup during destroy
- 📦 Optional addons:
  - MetalLB
  - NGINX Ingress
  - NFS storage class
  - Headlamp UI
- 🔐 SSH key generation & kubeconfig export
- 🧩 Highly configurable via structured variables
- ⚙️ Works with Proxmox VE via `bpg/proxmox` provider

---

## 🧱 Architecture

This module provisions:

```

Proxmox
├── Master VM (K3s server)
├── Worker VMs (K3s agents)
├── Cloud-init configuration
├── K3s bootstrap scripts
└── Optional cluster addons

```

---

## 📦 Requirements

- Terraform >= 1.5
- Proxmox VE >= 7.x
- Terraform provider:
  - `bpg/proxmox`
- SSH access to Proxmox nodes
- Cloud-init enabled templates in Proxmox

---

## 🔌 Providers

This module requires:

```hcl
terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.5"
    }
  }
}
```

> ⚠️ Provider configuration is NOT defined inside this module.
> It must be configured in the root module.

---

## 🚀 Usage

### Basic Example

```hcl
module "k3s" {
  source = "git::https://github.com/pankajackson/terraform-proxmox-k8s.git"
  proxmox = {
    node = "proxmox"
  }

  cluster = {
    name = "k8s-staging"
  }

  master = {
    ip_address = "192.168.1.10"
  }

  workers = {
    count    = 2
  }

  network = {
    gateway = "192.168.1.1"
    cidr    = "192.168.1.0/24"
    nfs = {
      server = "192.168.1.4"
      path   = "/volume1/infra-storage/lxa_k8s"
    }
  }
}
```

---

## ⚙️ Inputs

### 🧩 Cluster Configuration

| Name             | Type   | Default    | Description                 |
| ---------------- | ------ | ---------- | --------------------------- |
| cluster.name     | string | "lab"      | Cluster name                |
| cluster.id       | string | generated  | Unique cluster ID           |
| cluster.data_dir | string | "/lxa_k8s" | Data directory inside nodes |

---

### 🖥 Proxmox Configuration

| Name                      | Type   | Default         |
| ------------------------- | ------ | --------------- |
| proxmox.node              | string | "pve"           |
| proxmox.cpu_type          | string | "x86-64-v2-AES" |
| proxmox.disk_datastore_id | string | "local-lvm"     |

---

### 🧠 Defaults

| Name            | Type   | Default |
| --------------- | ------ | ------- |
| defaults.cpu    | number | 2       |
| defaults.memory | number | 2048    |
| defaults.disk   | number | 20      |

---

### 🎛 Master Node

| Name              | Type         | Description                       |
| ----------------- | ------------ | --------------------------------- |
| master.ip_address | string       | Static IP (optional DHCP if null) |
| master.cpu        | number       | CPU cores                         |
| master.memory     | number       | RAM in MB                         |
| master.disk       | number       | Disk size                         |
| master.labels     | list(string) | Kubernetes labels                 |
| master.taints     | list(string) | Kubernetes taints                 |

---

### 👷 Worker Nodes

| Name             | Type   | Default          |
| ---------------- | ------ | ---------------- |
| workers.count    | number | 2                |
| workers.ip_start | number | 61               |
| workers.cpu      | number | inherits default |
| workers.memory   | number | inherits default |
| workers.disk     | number | inherits default |

---

### 🌐 Network

| Name                | Description     |
| ------------------- | --------------- |
| network.gateway     | Default gateway |
| network.cidr        | Cluster subnet  |
| network.bridge      | Proxmox bridge  |
| network.dns.servers | DNS servers     |
| network.nfs.server  | NFS server      |
| network.nfs.path    | NFS path        |

---

### ☸️ K3s Configuration

| Name            | Description                            |
| --------------- | -------------------------------------- |
| k3s.version     | K3s version                            |
| k3s.token       | Cluster token (auto-generated if null) |
| k3s.tls_san     | Extra SANs                             |
| k3s.extra_args  | Extra K3s args                         |
| k3s.features.\* | Enable/disable components              |

---

### 🧩 Addons

#### MetalLB

```hcl
addons.metallb.enabled
addons.metallb.ipaddress_pool
```

#### NGINX Ingress

```hcl
addons.ingress_nginx.enabled
addons.ingress_nginx.loadbalancer_ip
```

#### NFS Storage

```hcl
addons.nfs_storage.enabled
addons.nfs_storage.server
addons.nfs_storage.path
```

#### Headlamp

```hcl
addons.headlamp.enabled
addons.headlamp.hostname
```

---

### 💾 OS Configuration

| Name                  | Description      |
| --------------------- | ---------------- |
| os.image.url          | Cloud image URL  |
| os.image.node_name    | Proxmox node     |
| os.image.datastore_id | Storage location |
| os.extra_packages     | Extra packages   |

---

## 📤 Outputs

### Cluster Info

| Output       | Description       |
| ------------ | ----------------- |
| cluster_name | Cluster name      |
| cluster_id   | Unique cluster ID |
| master_ip    | Master node IP    |
| worker_ips   | Worker node IPs   |

---

### Credentials

| Output         | Sensitive |
| -------------- | --------- |
| vm_password    | ✅        |
| vm_private_key | ✅        |
| k3s_token      | ✅        |

---

### Access Helpers

| Output                    | Description                |
| ------------------------- | -------------------------- |
| kubeconfig_path           | Local kubeconfig file path |
| kubeconfig_export_command | Export KUBECONFIG command  |
| master_ssh_command        | SSH command to master      |

---

## 🔐 Security Notes

- SSH keys are auto-generated per cluster
- Kubeconfig is stored locally in `.generated/`
- Sensitive outputs are marked as `sensitive = true`

---

## ⚠️ Important Behavior

- Worker cleanup runs automatically during `terraform destroy`
- Master node availability is checked before cleanup
- Cloud-init readiness is validated before K3s bootstrap
- Kubeconfig is fetched only after cluster is ready

---

## 🧹 Generated Files

After apply:

```
.generated/
 ├── vm_key.pem
 ├── kubeconfig.yaml
 ├── helmfile.yaml
 └── metallb-config.yaml
```

---

## 🚀 Future Improvements (Roadmap)

- Multi-cluster support
- HA master nodes
- Terraform provider abstraction for SSH lifecycle
- Helm-based addon deployment
- Full GitOps integration

---

## 📜 License

MIT
