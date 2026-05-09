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
  description = "Rune release tag passed to install-server.sh (e.g. 'v0.0.1-dev.22'). Pinned by default for reproducibility; bump per module release."
  default     = "v0.0.1-dev.22"
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
