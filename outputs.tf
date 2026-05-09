output "droplet_id" {
  description = "DigitalOcean droplet ID."
  value       = digitalocean_droplet.this.id
}

output "droplet_name" {
  description = "Droplet name (rune-<environment>)."
  value       = digitalocean_droplet.this.name
}

output "ipv4_address" {
  description = "Public IPv4 address of the droplet."
  value       = digitalocean_droplet.this.ipv4_address
}

output "ipv6_address" {
  description = "Public IPv6 address of the droplet (empty if disabled)."
  value       = digitalocean_droplet.this.ipv6_address
}

output "urn" {
  description = "Droplet URN, useful when wiring further DigitalOcean resources."
  value       = digitalocean_droplet.this.urn
}

output "grpc_endpoint" {
  description = "Address to point the rune CLI `--server` flag at."
  value       = "${digitalocean_droplet.this.ipv4_address}:${var.grpc_port}"
}

output "http_endpoint" {
  description = "rune HTTP API base URL."
  value       = "http://${digitalocean_droplet.this.ipv4_address}:${var.http_port}"
}

output "firewall_id" {
  description = "Firewall ID (empty when create_firewall = false)."
  value       = var.create_firewall ? digitalocean_firewall.this[0].id : ""
}

# --- Bootstrap outputs (empty when bootstrap = false) ---

output "bootstrap_token_path" {
  description = "Local path where the admin bootstrap token was written. Empty when bootstrap = false."
  value       = var.bootstrap ? abspath(var.bootstrap_token_path) : ""
}

output "rune_login_command" {
  description = "Ready-to-paste `rune login` command. Empty when bootstrap = false."
  value       = var.bootstrap ? local.rune_login_command : ""
}
