terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.5"
    }
  }
}

provider "proxmox" {
  endpoint = var.proxmox_endpoint
  username = var.proxmox_username
  password = var.proxmox_password
  insecure = var.proxmox_tls_insecure

  ssh {
    agent = true
  }
}

provider "random" {}

provider "tls" {}

provider "null" {}

provider "local" {}
