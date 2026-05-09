terraform {
  required_version = ">= 1.5.0"
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = ">= 2.40, < 3.0"
    }
  }
}

provider "digitalocean" {
  token = var.do_token
}

data "digitalocean_ssh_key" "main" {
  name = var.ssh_key_name
}

module "rune" {
  source = "../.."

  environment = "dev"
  region      = "lon1"
  ssh_key_ids = [data.digitalocean_ssh_key.main.id]

  # Single worker node — no edge ingress, no ACME.
  node_role = "worker"
}

output "grpc_endpoint" { value = module.rune.grpc_endpoint }
output "ipv4_address" { value = module.rune.ipv4_address }
