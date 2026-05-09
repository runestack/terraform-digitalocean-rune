variable "do_token" {
  type      = string
  sensitive = true
}

variable "ssh_key_name" {
  type = string
}

variable "environment" {
  type    = string
  default = "edge"
}

variable "region" {
  type    = string
  default = "lon1"
}

variable "acme_email" {
  type        = string
  description = "Required: Let's Encrypt account email."
}
