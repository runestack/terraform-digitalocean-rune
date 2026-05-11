variable "do_token" {
  type      = string
  sensitive = true
}

variable "ssh_key_name" {
  type        = string
  description = "Name of an SSH key already uploaded to your DigitalOcean account."
}

variable "ssh_private_key" {
  type        = string
  description = "PEM-encoded private key matching ssh_key_name. Pass via TF_VAR_ssh_private_key=\"$(cat ~/.ssh/id_ed25519)\" or a tfvars file. Read from disk in the caller, not here, so the example stays evaluable by linters."
  sensitive   = true
}

variable "acme_email" {
  type = string
}

# ---------------------------------------------------------------
# Optional: GHCR credentials, stored as an encrypted Rune Secret.
# Leave empty to skip the registry-via-secret demo.
# ---------------------------------------------------------------

variable "ghcr_username" {
  type        = string
  description = "GitHub username paired with ghcr_pat. Leave empty to skip the GHCR demo."
  default     = ""
}

variable "ghcr_pat" {
  type        = string
  description = "GitHub Personal Access Token with read:packages. Sensitive."
  default     = ""
  sensitive   = true
}
