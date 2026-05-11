# ---------------------------------------------------------------
# Required
# ---------------------------------------------------------------

variable "ssh_key_ids" {
  type        = list(string)
  description = "DigitalOcean SSH key IDs (or fingerprints) to install on the droplet. At least one is required so cloud-init / bootstrap can reach the host."
  validation {
    condition     = length(var.ssh_key_ids) > 0
    error_message = "ssh_key_ids must contain at least one key."
  }
}

# ---------------------------------------------------------------
# Naming + placement
# ---------------------------------------------------------------

variable "environment" {
  type        = string
  description = "Environment label used in the droplet name and tags (e.g. 'dev', 'prod')."
  default     = "dev"
}

variable "region" {
  type        = string
  description = "DigitalOcean region slug."
  default     = "lon1"
}

variable "droplet_size" {
  type        = string
  description = "DigitalOcean droplet size slug. Edge nodes terminating ACME-signed traffic should be at least s-1vcpu-2gb."
  default     = "s-2vcpu-4gb"
}

variable "image" {
  type        = string
  description = "Base image slug. Tested on Ubuntu 24.04 LTS; older Debian/Ubuntu releases may work but are unsupported."
  default     = "ubuntu-24-04-x64"
}

variable "tags" {
  type        = list(string)
  description = "Extra droplet tags. The module always adds 'rune' and 'rune-<environment>'."
  default     = []
}

variable "project_id" {
  type        = string
  description = "Optional DigitalOcean project ID to attach the droplet to. Empty disables attachment."
  default     = ""
}

# ---------------------------------------------------------------
# Droplet features
# ---------------------------------------------------------------

variable "enable_backups" {
  type        = bool
  description = "Enable weekly droplet backups."
  default     = false
}

variable "enable_monitoring" {
  type        = bool
  description = "Enable DigitalOcean monitoring agent."
  default     = true
}

variable "enable_ipv6" {
  type        = bool
  description = "Enable IPv6 on the droplet."
  default     = true
}

# ---------------------------------------------------------------
# Firewall
# ---------------------------------------------------------------

variable "create_firewall" {
  type        = bool
  description = "Create a DigitalOcean firewall in front of the droplet. Disable if you manage firewalls externally."
  default     = true
}

variable "ssh_allowed_cidrs" {
  type        = list(string)
  description = "CIDR blocks allowed to reach SSH (port 22). Tighten in production."
  default     = ["0.0.0.0/0", "::/0"]
}

variable "api_allowed_cidrs" {
  type        = list(string)
  description = "CIDR blocks allowed to reach the rune gRPC + HTTP API ports."
  default     = ["0.0.0.0/0", "::/0"]
}

variable "ingress_allowed_cidrs" {
  type        = list(string)
  description = "CIDR blocks allowed to reach :80 and :443 when node_role = 'edge'. Public by default since edge nodes terminate user traffic."
  default     = ["0.0.0.0/0", "::/0"]
}

variable "extra_inbound_tcp_ports" {
  type        = list(number)
  description = "Additional TCP ports to open inbound (gated by api_allowed_cidrs). Useful while you stand up apps before they sit behind the edge ingress."
  default     = []
}

# ---------------------------------------------------------------
# Rune installation
# ---------------------------------------------------------------

variable "rune_version" {
  type        = string
  description = "Rune release tag passed to install-server.sh (e.g. 'v0.0.1-dev.32'). Pinned by default for reproducibility; bump per module release."
  default     = "v0.0.1-dev.32"
}

# ---------------------------------------------------------------
# Rune runtime config (rendered into /etc/rune/runefile.toml)
# ---------------------------------------------------------------

variable "node_role" {
  type        = string
  description = "Rune node role. 'edge' nodes bind :80/:443 and run the ACME orchestrator; 'worker' nodes only run services."
  default     = "edge"
  validation {
    condition     = contains(["edge", "worker"], var.node_role)
    error_message = "node_role must be 'edge' or 'worker'."
  }
}

variable "grpc_port" {
  type        = number
  description = "Port for the rune gRPC API."
  default     = 7863
}

variable "http_port" {
  type        = number
  description = "Port for the rune HTTP API."
  default     = 7861
}

variable "cluster_cidr" {
  type        = string
  description = "Cluster CIDR used by the rune networking layer for service IPs."
  default     = "10.96.0.0/16"
}

variable "log_level" {
  type        = string
  description = "Log level (debug, info, warn, error)."
  default     = "info"
}

variable "log_format" {
  type        = string
  description = "Log format (text or json)."
  default     = "text"
}

variable "metrics_addr" {
  type        = string
  description = "Address for the Prometheus metrics endpoint. Default binds to loopback only; expose by setting to ':9100' AND opening the port via extra_inbound_tcp_ports."
  default     = "127.0.0.1:9100"
}

variable "acme_email" {
  type        = string
  description = "Contact email for Let's Encrypt account registration. Required when node_role = 'edge' and you intend to use tls.mode = auto/acme on services."
  default     = ""
  validation {
    condition     = var.acme_email == "" || can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.acme_email))
    error_message = "acme_email must be a valid email address or empty."
  }
}

# ---------------------------------------------------------------
# Docker registry credentials (rendered into [[docker.registries]])
#
# Each entry maps to one block in the runefile. Two shapes are
# supported:
#
#   1) Inline credentials (rendered as plaintext into the runefile).
#      Simplest, but the credential lives in TF state + on the
#      droplet's filesystem.
#
#        docker_registries = [
#          {
#            name     = "ghcr"
#            registry = "ghcr.io"
#            username = "my-github-user"
#            password = var.ghcr_pat   # sensitive
#          }
#        ]
#
#   2) Stored as an encrypted Rune Secret (`fromSecret` reference).
#      The runefile carries only the secret name; runed loads the
#      cipher‑text from its Secret store at pull time.
#
#      Bootstrap mode (`bootstrap = true` + `data = { ... }`) lets
#      runed create the Secret on first start using env‑expanded
#      values. The env values reach runed via the EnvironmentFile
#      written from `var.runed_environment` (see below).
#
#        docker_registries = [
#          {
#            name        = "ghcr"
#            registry    = "ghcr.io"
#            from_secret = "ghcr-credentials"   # ns defaults to "system"
#            bootstrap   = true                  # create-or-update on startup
#            manage      = "update"              # create | update | ignore
#            immutable   = false
#            data = {
#              username = "$${GHCR_USERNAME}"
#              password = "$${GHCR_PAT}"
#            }
#          }
#        ]
#        runed_environment = {
#          GHCR_USERNAME = var.ghcr_username
#          GHCR_PAT      = var.ghcr_pat   # sensitive
#        }
#
# For ECR pass auth_type = "ecr" with the AWS region; runed will
# use its instance role / env credentials to mint short-lived
# tokens. For long-lived bearer tokens use auth_type = "token"
# with the `token` field instead of username/password.
# ---------------------------------------------------------------

variable "docker_registries" {
  type = list(object({
    name      = string
    registry  = string
    auth_type = optional(string, "basic")
    username  = optional(string, "")
    password  = optional(string, "")
    token     = optional(string, "")
    region    = optional(string, "")

    # fromSecret mode (RUNE-018). When from_secret is non-empty the
    # inline username/password/token fields are ignored; runed loads
    # credentials from the named Rune Secret instead.
    from_secret           = optional(string, "")
    from_secret_namespace = optional(string, "")
    bootstrap             = optional(bool, false)
    manage                = optional(string, "")
    immutable             = optional(bool, false)
    data                  = optional(map(string), {})
  }))
  description = "Private Docker registries rendered into [[docker.registries]] in runefile.toml. Use auth_type = 'basic' (username + password / PAT), 'token' (bearer), or 'ecr' (AWS region). Set from_secret to load credentials from an encrypted Rune Secret instead of embedding them in the runefile; combine with bootstrap = true + data = { ... } to have runed create/update the Secret on first start using env-expanded values supplied via var.runed_environment."
  default     = []
  sensitive   = true
  validation {
    condition = alltrue([
      for r in var.docker_registries : contains(["basic", "token", "ecr"], r.auth_type)
    ])
    error_message = "Each docker_registries[*].auth_type must be 'basic', 'token', or 'ecr'."
  }
  validation {
    condition = alltrue([
      for r in var.docker_registries :
      r.auth_type != "basic" || r.from_secret != "" || (r.username != "" && r.password != "")
    ])
    error_message = "docker_registries entries with auth_type = 'basic' require either from_secret or both username and password."
  }
  validation {
    condition = alltrue([
      for r in var.docker_registries :
      r.auth_type != "token" || r.from_secret != "" || r.token != ""
    ])
    error_message = "docker_registries entries with auth_type = 'token' require either from_secret or a non-empty token."
  }
  validation {
    condition = alltrue([
      for r in var.docker_registries :
      r.auth_type != "ecr" || r.region != ""
    ])
    error_message = "docker_registries entries with auth_type = 'ecr' require an AWS region."
  }
  validation {
    condition = alltrue([
      for r in var.docker_registries :
      r.manage == "" || contains(["create", "update", "ignore"], r.manage)
    ])
    error_message = "docker_registries[*].manage must be one of 'create', 'update', 'ignore' (or empty for the default)."
  }
  validation {
    condition = alltrue([
      for r in var.docker_registries :
      !r.bootstrap || (r.from_secret != "" && length(r.data) > 0)
    ])
    error_message = "docker_registries entries with bootstrap = true require both from_secret and a non-empty data map."
  }
  validation {
    condition = alltrue([
      for r in var.docker_registries :
      r.from_secret != "" || r.from_secret_namespace == ""
    ])
    error_message = "docker_registries[*].from_secret_namespace can only be set when from_secret is also set."
  }
}

variable "runed_environment" {
  type        = map(string)
  description = "Environment variables exported to the runed process via /etc/rune/runed.env (referenced by the systemd unit's EnvironmentFile). Use for secrets consumed by runefile bootstrap blocks (e.g. GHCR_PAT for a registry's bootstrap data map). Pass via TF_VAR_runed_environment or a sensitive tfvars file; values are written to the droplet's filesystem with mode 0600."
  default     = {}
  sensitive   = true
}

# ---------------------------------------------------------------
# Optional in-module bootstrap
# ---------------------------------------------------------------

variable "bootstrap" {
  type        = bool
  description = "When true, the module SSHes into the droplet after cloud-init finishes, runs `rune admin bootstrap`, copies the token to local disk, and outputs a `rune login` command."
  default     = false
}

variable "bootstrap_ssh_user" {
  type        = string
  description = "SSH user for the bootstrap step. DigitalOcean Ubuntu images use 'root'."
  default     = "root"
}

variable "bootstrap_ssh_private_key" {
  type        = string
  description = "PEM-encoded SSH private key matching one of ssh_key_ids. Sensitive. Required when bootstrap = true."
  default     = ""
  sensitive   = true
}

variable "bootstrap_token_path" {
  type        = string
  description = "Local path where the bootstrap admin token is written. Relative paths resolve against the consuming Terraform working directory."
  default     = "rune-admin.token"
}

variable "bootstrap_namespace" {
  type        = string
  description = "Default namespace baked into the emitted `rune login` command."
  default     = "default"
}

variable "bootstrap_context_name" {
  type        = string
  description = "CLI context name used in the emitted `rune login` command. Defaults to 'rune' when unset; the module appends '-<environment>'."
  default     = ""
}

variable "bootstrap_wait_timeout" {
  type        = string
  description = "How long to wait for the runed gRPC port to come up before bootstrapping. Format: '<n>m' or '<n>s'."
  default     = "10m"
}
