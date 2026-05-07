variable "cluster" {
  description = "Cluster level configuration"
  type = object({
    name     = optional(string, "lab")
    id       = optional(string, null)
    domain   = optional(string, null)
    data_dir = optional(string, "/lxa_k8s")
  })
  default = {}
}

variable "proxmox" {
  description = "Proxmox level configuration"
  type = object({
    node_name     = optional(string, "pve")
    cpu_type      = optional(string, "x86-64-v2-AES")
    disk_datastore_id = optional(string, "local-lvm")
  })
  default = {}
}

variable "master" {
  description = "Master node configuration"
  type = object({
    ip_address = optional(string) # null = DHCP

    cpu    = optional(number, 2)
    memory = optional(number, 2048)
    disk   = optional(number, 20)

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

    cpu    = optional(number, 2)
    memory = optional(number, 2048)
    disk   = optional(number, 20)

    labels = optional(list(string), [])
    taints = optional(list(string), [])
  })
  default = {}
}

variable "network" {
  description = "Network configuration"
  type = object({
    gateway    = optional(string, "192.168.1.1")
    cidr       = optional(string, "192.168.1.0/24")
    bridge     = optional(string, "vmbr0")
		dns = optional(object({
      servers = optional(list(string), ["192.168.1.1", "8.8.8.8"])
      domain   = optional(string, null)
    }), {})

    nfs = optional(object({
      server = optional(string, "192.168.1.4")
      path   = optional(string, "/volume1/infra-storage/lxa_k8s")
    }), {})
  })
  default = {}
}

variable "k3s" {
  description = "K3s configuration"
  type = object({
    version = optional(string, "v1.30.0+k3s1")
    token   = optional(string, null)
    tls_san = optional(list(string), [])

    features = optional(object({
      traefik       = optional(bool, false)
      local_storage = optional(bool, false)
      metrics       = optional(bool, false)
    }), {})
  })
  default = {}
}

variable "system" {
  description = "Base system configuration"
  type = object({
    extra_packages = optional(list(string), [])
  })
  default = {}
}