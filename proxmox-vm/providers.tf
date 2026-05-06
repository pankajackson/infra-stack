terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.5"
    }
  }
}

provider "proxmox" {
  endpoint = "https://<PROXMOX_HOST>:<PROXMOX_PORT>"
  username = "<PROXMOX_USER>"
  password = "<PASSWORD>"
  insecure = true

  ssh {
    agent = true
  }
}

provider "random" {}

provider "tls" {}

provider "null" {}

provider "local" {}
