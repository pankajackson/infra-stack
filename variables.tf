variable "cluster" {
  description = "Cluster level configuration"
  type = object({
    name     = optional(string, "lab")
    id       = optional(string, null)
    domain   = optional(string, null) # TODO: remove this if we don't need it
    data_dir = optional(string, "/lxa_k8s")
  })
  default = {}
}

variable "proxmox" {
  description = "Proxmox level configuration"
  type = object({
    node              = optional(string, "pve")
    cpu_type          = optional(string, "x86-64-v2-AES")
    disk_datastore_id = optional(string, "local-lvm")
  })
  default = {}
}

variable "proxmox_endpoint" {
  description = "Proxmox API endpoint"
  type        = string
}
variable "proxmox_username" {
  description = "Proxmox API username"
  type        = string
}
variable "proxmox_password" {
  description = "Proxmox API password"
  type        = string
  sensitive   = true
  nullable    = false
}
variable "proxmox_tls_insecure" {
  description = "Use insecure connection"
  type        = bool
  default     = false
}

variable "defaults" {
  description = "Default compute configuration for all nodes"
  type = object({
    cpu    = optional(number, 2)
    memory = optional(number, 2048)
    disk   = optional(number, 20)
  })
  default = {}
}

variable "master" {
  description = "Master node configuration"
  type = object({
    ip_address = optional(string) # null = DHCP

    cpu    = optional(number)
    memory = optional(number)
    disk   = optional(number)

    labels = optional(list(string), [])
    taints = optional(list(string), [])
  })
  default = {}
}

variable "workers" {
  description = "Worker node configuration"
  type = object({
    count = optional(number, 2)

    ip_start = optional(number, 61)

    cpu    = optional(number)
    memory = optional(number)
    disk   = optional(number)

    labels = optional(list(string), [])
    taints = optional(list(string), [])
  })
  default = {}
}

variable "network" {
  description = "Network configuration"
  type = object({
    gateway = optional(string, "192.168.1.1")
    cidr    = optional(string, "192.168.1.0/24")
    bridge  = optional(string, "vmbr0")
    dns = optional(object({
      servers = optional(list(string), ["192.168.1.1", "8.8.8.8"])
      domain  = optional(string, null)
    }), {})

    nfs = optional(object({
      server = optional(string, "192.168.1.253")
      path   = optional(string, "/data/lxa_k8s")
    }), {})
  })
  default = {}
}

variable "k3s" {
  description = "K3s configuration"
  type = object({
    version    = optional(string, "v1.30.0+k3s1") # Valid list here: curl -sL https://api.github.com/repos/k3s-io/k3s/releases | jq -r '.[].tag_name'
    token      = optional(string, null)
    tls_san    = optional(list(string), [])
    extra_args = optional(list(string), [])

    features = optional(object({
      servicelb      = optional(bool, true)
      traefik       = optional(bool, false)
      local_storage = optional(bool, false)
      metrics       = optional(bool, false)
    }), {})
  })
  default = {}
}

variable "addons" {
  description = "Cluster addons"

  type = object({

    metallb = optional(object({
      enabled = optional(bool, false)
      ipaddress_pool = optional(string, null)
    }), {})

    ingress_nginx = optional(object({
      enabled = optional(bool, false)
      loadbalancer_ip = optional(string, null)
      # extra_args = optional(list(string), [])
    }), {})

    nfs_storage = optional(object({
      enabled = optional(bool, false)

      server = optional(string, null)
      path   = optional(string, null)

      storage_class = optional(string, "nfs")
      default_class = optional(bool, false)
    }), {})

    headlamp = optional(object({
      enabled = optional(bool, false)

      hostname = optional(string, "headlamp.local")
    }), {})

  })

  default = {}
}

variable "os" {
  description = "Base system configuration"
  type = object({
    image = optional(object({
      url          = optional(string, "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img")
      node_name    = optional(string, "proxmox")
      datastore_id = optional(string, "local")
      file_name    = optional(string, "jammy-server-cloudimg-amd64.qcow2")
    }), {})
    extra_packages = optional(list(string), []) # TODO: add support for extra packages
  })
  default = {}
}