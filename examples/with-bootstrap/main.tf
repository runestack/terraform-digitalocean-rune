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

# Edge node + auto-bootstrap. After `terraform apply`, the admin
# token is on disk and `terraform output rune_login_command` prints
# a ready-to-paste login.
#
# When ghcr_username + ghcr_pat are set, runed will create an
# encrypted `ghcr-credentials` Rune Secret in the `system`
# namespace on first start (the runefile only carries a fromSecret
# reference, never the PAT itself).
module "rune" {
  source = "../.."

  environment = "demo"
  region      = "lon1"
  ssh_key_ids = [data.digitalocean_ssh_key.main.id]

  node_role  = "edge"
  acme_email = var.acme_email

  bootstrap                 = true
  bootstrap_ssh_private_key = var.ssh_private_key
  bootstrap_token_path      = "${path.cwd}/rune-admin.token"
  bootstrap_namespace       = "default"

  docker_registries = var.ghcr_username == "" ? [] : [
    {
      name        = "ghcr"
      registry    = "ghcr.io"
      auth_type   = "basic"
      from_secret = "ghcr-credentials"
      bootstrap   = true
      manage      = "update"
      data = {
        username = "$${GHCR_USERNAME}"
        password = "$${GHCR_PAT}"
      }
    }
  ]

  runed_environment = var.ghcr_username == "" ? {} : {
    GHCR_USERNAME = var.ghcr_username
    GHCR_PAT      = var.ghcr_pat
  }
}

output "ipv4_address" { value = module.rune.ipv4_address }
output "rune_login_command" { value = module.rune.rune_login_command }
output "bootstrap_token_path" { value = module.rune.bootstrap_token_path }
