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

# Edge node terminating ACME-managed TLS for one or more services
# whose `expose.host` resolves to the droplet's IP.
module "rune" {
  source = "../.."

  environment = var.environment
  region      = var.region
  ssh_key_ids = [data.digitalocean_ssh_key.main.id]

  node_role  = "edge"
  acme_email = var.acme_email
}

output "ipv4_address" { value = module.rune.ipv4_address }
output "grpc_endpoint" { value = module.rune.grpc_endpoint }

output "next_steps" {
  value = <<-EOT
    1. Point your DNS A record at: ${module.rune.ipv4_address}
    2. Wait for cloud-init: ssh root@${module.rune.ipv4_address} 'tail -f /var/log/user-data.log'
    3. Bootstrap:           ssh root@${module.rune.ipv4_address} 'rune admin bootstrap --out-file /tmp/rune-admin.token'
    4. Login + cast a service with expose.host + tls.mode = auto.
  EOT
}
