terraform {
    required_providers {
        proxmox = {
            source  = "bpg/proxmox"
            version = "~> 0.5"
        }
    }
}

provider "proxmox" {
    endpoint    = "https://<PROXMOX_HOST>:<PROXMOX_PORT>"
    api_token   = "<PROXMOX_API_TOKEN>"
    insecure    = true
}

provider "random" {}

provider "tls" {}