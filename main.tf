# ---------------------------------------------------------------
# terraform-digitalocean-rune
#
# Provisions a single DigitalOcean droplet running the Rune server
# (`runed`). Cloud-init installs Rune via the upstream installer
# script and writes a runefile.toml shaped by this module's inputs.
#
# Optional bootstrap (var.bootstrap = true) SSHes in once the
# droplet is reachable, runs `rune admin bootstrap`, copies the
# token locally, and emits the `rune login` command as an output.
# ---------------------------------------------------------------

locals {
  name = "rune-${var.environment}"

  # The user_data script is rendered with module inputs. Cloud-init
  # is at-most-once: changing user_data does NOT re-run on existing
  # droplets, so changes here only take effect on a fresh apply.
  user_data = templatefile("${path.module}/templates/user_data.sh.tftpl", {
    rune_version = var.rune_version
    runefile     = local.runefile
  })

  runefile = templatefile("${path.module}/templates/runefile.toml.tftpl", {
    grpc_address = ":${var.grpc_port}"
    http_address = ":${var.http_port}"
    cluster_cidr = var.cluster_cidr
    node_role    = var.node_role
    log_level    = var.log_level
    log_format   = var.log_format
    metrics_addr = var.metrics_addr
    acme_email   = var.acme_email
  })
}

resource "digitalocean_droplet" "this" {
  name     = local.name
  image    = var.image
  region   = var.region
  size     = var.droplet_size
  ssh_keys = var.ssh_key_ids

  monitoring = var.enable_monitoring
  backups    = var.enable_backups
  ipv6       = var.enable_ipv6

  user_data = local.user_data

  tags = concat(["rune", "rune-${var.environment}"], var.tags)
}

resource "digitalocean_firewall" "this" {
  count = var.create_firewall ? 1 : 0

  name        = "${local.name}-fw"
  droplet_ids = [digitalocean_droplet.this.id]

  # SSH
  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = var.ssh_allowed_cidrs
  }

  # rune gRPC + HTTP API
  inbound_rule {
    protocol         = "tcp"
    port_range       = tostring(var.grpc_port)
    source_addresses = var.api_allowed_cidrs
  }
  inbound_rule {
    protocol         = "tcp"
    port_range       = tostring(var.http_port)
    source_addresses = var.api_allowed_cidrs
  }

  # Edge ingress (only opened when this node terminates traffic)
  dynamic "inbound_rule" {
    for_each = var.node_role == "edge" ? [80, 443] : []
    content {
      protocol         = "tcp"
      port_range       = tostring(inbound_rule.value)
      source_addresses = var.ingress_allowed_cidrs
    }
  }

  # Extra ports the operator wants reachable (e.g. 8080 for an app)
  dynamic "inbound_rule" {
    for_each = var.extra_inbound_tcp_ports
    content {
      protocol         = "tcp"
      port_range       = tostring(inbound_rule.value)
      source_addresses = var.api_allowed_cidrs
    }
  }

  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
  outbound_rule {
    protocol              = "icmp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}

resource "digitalocean_project_resources" "this" {
  count     = var.project_id != "" ? 1 : 0
  project   = var.project_id
  resources = [digitalocean_droplet.this.urn]
}
