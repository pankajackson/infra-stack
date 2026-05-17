# Terraform Proxmox K3s Cluster Module

Provision a fully automated K3s cluster on Proxmox VE using Terraform.

This module provisions:

- K3s master and worker nodes
- Cloud-init based VM bootstrap
- Automatic cluster join and cleanup lifecycle
- Optional Kubernetes addons
- Kubeconfig export
- Helmfile-based addon management

---

## Features

- Fully automated K3s cluster provisioning
- Static IP auto-allocation
- Cloud-init provisioning
- Stateful cluster bootstrap using Terraform state
- Optional reuse of existing Proxmox cloud images
- Worker lifecycle cleanup during destroy
- Optional addons:
  - MetalLB
  - NGINX Ingress
  - NFS Storage Class
  - Headlamp
- Automatic kubeconfig export
- SSH key generation
- Helmfile-based addon deployment
- Proxmox VM ID auto-generation

---

## Requirements

| Name       | Version  |
| ---------- | -------- |
| Terraform  | `>= 1.5` |
| Proxmox VE | `>= 7.x` |

---

## Providers

| Name    | Source             |
| ------- | ------------------ |
| proxmox | `bpg/proxmox`      |
| tls     | `hashicorp/tls`    |
| local   | `hashicorp/local`  |
| null    | `hashicorp/null`   |
| random  | `hashicorp/random` |
| time    | `hashicorp/time`   |

---

## Usage

### Basic Example

```hcl id="6q4k5f"
module "k3s" {
  source  = "pankajackson/k8s/proxmox"
  version = "0.0.2"

  proxmox = {
    node = "pve"
  }

  cluster = {
    name = "lab"

    tags = [
      "terraform",
      "k3s",
      "homelab"
    ]
  }

  workers = {
    count = 2
  }

  network = {
    cidr   = "192.168.1.0/24"
    bridge = "vmbr0"
  }

  addons = {
    metallb = {
      enabled = true
    }

    ingress_nginx = {
      enabled = true
    }
  }
}
```

---

## Architecture

```text id="e7f2bc"
Proxmox VE
├── K3s Master Node
├── K3s Worker Nodes
├── Cloud-init Bootstrap
├── Terraform State Coordination
└── Optional Addons
    ├── MetalLB
    ├── NGINX Ingress
    ├── NFS CSI
    └── Headlamp
```

---

## Inputs

### cluster

Cluster level configuration.

| Name               | Type           | Default      | Description                                         |
| ------------------ | -------------- | ------------ | --------------------------------------------------- |
| `cluster.name`     | `string`       | `"lab"`      | Cluster name                                        |
| `cluster.id`       | `string`       | `null`       | Unique cluster identifier. Auto-generated when null |
| `cluster.domain`   | `string`       | `null`       | Optional DNS domain                                 |
| `cluster.data_dir` | `string`       | `"/lxa_k8s"` | Cluster working directory                           |
| `cluster.tags`     | `list(string)` | `[]`         | Tags applied to all Proxmox VMs                     |

---

### proxmox

Proxmox VM configuration.

| Name                        | Type     | Default           | Description                         |
| --------------------------- | -------- | ----------------- | ----------------------------------- |
| `proxmox.node`              | `string` | `"pve"`           | Proxmox target node                 |
| `proxmox.cpu_type`          | `string` | `"x86-64-v2-AES"` | VM CPU type                         |
| `proxmox.disk_datastore_id` | `string` | `"local-lvm"`     | Proxmox datastore used for VM disks |

---

### defaults

Default compute configuration inherited by all nodes.

| Name              | Type     | Default | Description             |
| ----------------- | -------- | ------- | ----------------------- |
| `defaults.cpu`    | `number` | `2`     | Default CPU cores       |
| `defaults.memory` | `number` | `2048`  | Default memory in MB    |
| `defaults.disk`   | `number` | `20`    | Default disk size in GB |

---

### master

Master node configuration.

| Name                | Type           | Default           | Description              |
| ------------------- | -------------- | ----------------- | ------------------------ |
| `master.ip_address` | `string`       | auto-generated    | Static master IP address |
| `master.cpu`        | `number`       | `defaults.cpu`    | CPU cores                |
| `master.memory`     | `number`       | `defaults.memory` | Memory in MB             |
| `master.disk`       | `number`       | `defaults.disk`   | Disk size in GB          |
| `master.labels`     | `list(string)` | `[]`              | Kubernetes node labels   |
| `master.taints`     | `list(string)` | `[]`              | Kubernetes node taints   |

#### Automatic Master IP Allocation

If `master.ip_address` is not provided:

```hcl id="m9j4vx"
cidrhost(network.cidr, 60)
```

Example:

```text id="a3r7yx"
network.cidr = 192.168.1.0/24
master IP    = 192.168.1.60
```

---

### workers

Worker node configuration.

| Name               | Type           | Default           | Description                                   |
| ------------------ | -------------- | ----------------- | --------------------------------------------- |
| `workers.count`    | `number`       | `2`               | Number of worker nodes                        |
| `workers.ip_start` | `number`       | `61`              | Starting host offset for worker IP allocation |
| `workers.cpu`      | `number`       | `defaults.cpu`    | CPU cores                                     |
| `workers.memory`   | `number`       | `defaults.memory` | Memory in MB                                  |
| `workers.disk`     | `number`       | `defaults.disk`   | Disk size in GB                               |
| `workers.labels`   | `list(string)` | `[]`              | Kubernetes node labels                        |
| `workers.taints`   | `list(string)` | `[]`              | Kubernetes node taints                        |

#### Automatic Worker IP Allocation

Worker IPs are generated using:

```hcl id="w5q2eh"
cidrhost(network.cidr, workers.ip_start + index)
```

Example:

```text id="r2h7ln"
network.cidr   = 192.168.1.0/24
workers.count  = 3
workers.ip_start = 61

Allocated IPs:
- 192.168.1.61
- 192.168.1.62
- 192.168.1.63
```

---

### network

Cluster network configuration.

| Name                  | Type           | Default                      | Description       |
| --------------------- | -------------- | ---------------------------- | ----------------- |
| `network.gateway`     | `string`       | `"192.168.1.1"`              | Network gateway   |
| `network.cidr`        | `string`       | `"192.168.1.0/24"`           | Cluster subnet    |
| `network.bridge`      | `string`       | `"vmbr0"`                    | Proxmox bridge    |
| `network.dns.servers` | `list(string)` | `["192.168.1.1", "8.8.8.8"]` | DNS servers       |
| `network.dns.domain`  | `string`       | `null`                       | DNS search domain |

---

### k3s

K3s cluster configuration.

| Name             | Type           | Default          | Description         |
| ---------------- | -------------- | ---------------- | ------------------- |
| `k3s.version`    | `string`       | `"v1.30.0+k3s1"` | K3s version         |
| `k3s.token`      | `string`       | `null`           | Cluster token       |
| `k3s.tls_san`    | `list(string)` | `[]`             | Additional TLS SANs |
| `k3s.extra_args` | `list(string)` | `[]`             | Extra K3s arguments |

#### k3s.features

| Name                         | Type   | Default | Description                   |
| ---------------------------- | ------ | ------- | ----------------------------- |
| `k3s.features.servicelb`     | `bool` | `true`  | Enable ServiceLB              |
| `k3s.features.traefik`       | `bool` | `false` | Enable Traefik                |
| `k3s.features.local_storage` | `bool` | `false` | Enable local-path provisioner |
| `k3s.features.metrics`       | `bool` | `false` | Enable metrics-server         |

---

### addons

Optional cluster addons.

---

#### addons.metallb

| Name                            | Type     | Default        | Description                 |
| ------------------------------- | -------- | -------------- | --------------------------- |
| `addons.metallb.enabled`        | `bool`   | `false`        | Enable MetalLB              |
| `addons.metallb.ipaddress_pool` | `string` | auto-generated | MetalLB IP allocation range |

#### Automatic MetalLB Pool Allocation

If no IP pool is specified:

```hcl id="h8f5ms"
"${cidrhost(network.cidr, 200)}-${cidrhost(network.cidr, 250)}"
```

Example:

```text
192.168.1.200-192.168.1.250
```

> Do not use full subnet CIDRs like `192.168.1.0/24` for MetalLB pools.

---

#### addons.ingress_nginx

| Name                                   | Type     | Default | Description                     |
| -------------------------------------- | -------- | ------- | ------------------------------- |
| `addons.ingress_nginx.enabled`         | `bool`   | `false` | Enable NGINX ingress controller |
| `addons.ingress_nginx.loadbalancer_ip` | `string` | `null`  | Static LoadBalancer IP          |

---

#### addons.nfs_storage

| Name                               | Type     | Default | Description                    |
| ---------------------------------- | -------- | ------- | ------------------------------ |
| `addons.nfs_storage.enabled`       | `bool`   | `false` | Enable NFS storage provisioner |
| `addons.nfs_storage.server`        | `string` | `null`  | NFS server address             |
| `addons.nfs_storage.path`          | `string` | `null`  | NFS export path                |
| `addons.nfs_storage.storage_class` | `string` | `"nfs"` | StorageClass name              |
| `addons.nfs_storage.default_class` | `bool`   | `false` | Set as default StorageClass    |

> `addons.nfs_storage.server` and `addons.nfs_storage.path` are required when the addon is enabled.

---

#### addons.headlamp

| Name                       | Type     | Default            | Description       |
| -------------------------- | -------- | ------------------ | ----------------- |
| `addons.headlamp.enabled`  | `bool`   | `false`            | Enable Headlamp   |
| `addons.headlamp.hostname` | `string` | `"headlamp.local"` | Headlamp hostname |

---

### os

Base operating system configuration.

#### os.image

| Name                           | Type     | Default                               | Description                         |
| ------------------------------ | -------- | ------------------------------------- | ----------------------------------- |
| `os.image.url`                 | `string` | Ubuntu Jammy cloud image              | Cloud image URL                     |
| `os.image.node_name`           | `string` | `null`                                | Proxmox node for image download     |
| `os.image.datastore_id`        | `string` | `"local"`                             | Proxmox datastore for image storage |
| `os.image.file_name`           | `string` | `"jammy-server-cloudimg-amd64.qcow2"` | Image filename                      |
| `os.image.download`            | `bool`   | `true`                                | Download image automatically        |
| `os.image.overwrite`           | `bool`   | `true`                                | Overwrite managed existing image    |
| `os.image.overwrite_unmanaged` | `bool`   | `false`                               | Overwrite unmanaged existing image  |

### Using Existing Proxmox Images

Disable automatic download to reuse existing images:

```hcl
os = {
  image = {
    download  = false
    file_name = "jammy-server-cloudimg-amd64.qcow2"
  }
}
```

---

### os.extra_packages

| Name                | Type           | Default | Description                                    |
| ------------------- | -------------- | ------- | ---------------------------------------------- |
| `os.extra_packages` | `list(string)` | `[]`    | Additional packages installed during bootstrap |

---

## Outputs

### Cluster

Provisioned cluster information.

```hcl
output "cluster"
```

Example:

```hcl
cluster = {
  name    = "lab"
  id      = "abc123"
  master  = "192.168.1.60"
  workers = [
    "192.168.1.61",
    "192.168.1.62"
  ]
}
```

---

### Access

Cluster access information.

```hcl
output "access"
```

Example:

```hcl
access = {
  kubeconfig_file = ".generated/kubeconfig.yaml"
  ssh_user        = "ubuntu"
  ssh_master      = "ubuntu@192.168.1.60"
}
```

---

### Secrets

Sensitive cluster credentials and generated secrets.

```hcl
output "secrets"
```

Contains:

- VM SSH private key
- VM password
- K3s token
- Generated kubeconfig

> This output is marked as sensitive.

---

## Generated Files

```text id="z8y4ph"
.generated/
├── kubeconfig.yaml
├── helmfile.yaml
├── metallb-config.yaml
└── vm_key.pem
```

---

## Notes

- Worker cleanup executes automatically during `terraform destroy`
- Cloud-init readiness is validated before K3s bootstrap
- Addons are installed using Helmfile
- MetalLB uses dedicated IP pools instead of full subnet CIDRs
- Kubeconfig is exported after cluster bootstrap completes
