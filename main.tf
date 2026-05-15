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
  name = var.name != "" ? var.name : "rune-${var.environment}"

  # Sorted KEY=VALUE lines for /etc/rune/runed.env. Sorting keeps
  # the rendered user_data stable across applies when var iteration
  # order differs. Values are written verbatim — no quoting — to
  # match systemd EnvironmentFile parsing rules; callers must not
  # include literal newlines in values.
  runed_env_file = join("\n", [
    for k in sort(keys(var.runed_environment)) :
    "${k}=${var.runed_environment[k]}"
  ])

  # The user_data script is rendered with module inputs. Cloud-init
  # is at-most-once: changing user_data does NOT re-run on existing
  # droplets, so changes here only take effect on a fresh apply.
  user_data = templatefile("${path.module}/templates/user_data.sh.tftpl", {
    rune_version      = var.rune_version
    runefile          = local.runefile
    runed_environment = local.runed_env_file
  })

  runefile = templatefile("${path.module}/templates/runefile.toml.tftpl", {
    grpc_address      = ":${var.grpc_port}"
    http_address      = ":${var.http_port}"
    cluster_cidr      = var.cluster_cidr
    node_role         = var.node_role
    log_level         = var.log_level
    log_format        = var.log_format
    metrics_addr      = var.metrics_addr
    acme_email        = var.acme_email
    docker_registries = var.docker_registries
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

  lifecycle {
    # Cloud-init runs at-most-once per droplet, so a changed user_data
    # never re-executes on an existing host — but Terraform's default
    # is to mark the droplet for REPLACEMENT (destroy + create) on any
    # user_data drift. That would wipe /var/lib/rune (KEK, BadgerDB
    # store) and any host-local volumes, which is almost never what an
    # operator who just bumped `rune_version` actually wants.
    #
    # Ignoring user_data lets the variable advance freely in code
    # (semantically tracking the desired install) while in-place
    # upgrades happen out-of-band via `scripts/upgrade-server.sh`
    # over SSH. New droplets created from scratch still pick up the
    # current `rune_version` via the rendered template.
    #
    # To deliberately force a fresh droplet at a new version
    # (greenfield / DR rebuild), use `terraform apply -replace=...`
    # or taint the droplet — both bypass this ignore_changes.
    ignore_changes = [user_data]
  }
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
