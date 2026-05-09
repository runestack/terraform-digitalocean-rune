variable "do_token" {
  type        = string
  description = "DigitalOcean API token."
  sensitive   = true
}

variable "ssh_key_name" {
  type        = string
  description = "Name of an SSH key already uploaded to your DigitalOcean account."
}
