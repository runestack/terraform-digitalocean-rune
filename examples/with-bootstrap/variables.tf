variable "do_token" {
  type      = string
  sensitive = true
}

variable "ssh_key_name" {
  type        = string
  description = "Name of an SSH key already uploaded to your DigitalOcean account."
}

variable "ssh_private_key_path" {
  type        = string
  description = "Path to the matching PEM-encoded private key on this machine."
  default     = "~/.ssh/id_ed25519"
}

variable "acme_email" {
  type = string
}
