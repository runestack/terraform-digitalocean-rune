# terraform-digitalocean-rune

Provision a [Rune](https://github.com/runestack/rune) node on
DigitalOcean: droplet, firewall, cloud-init installation, and an
optional one-shot admin bootstrap.

> Open-source Terraform module. Tracks Rune releases under
> `var.rune_version`.

## Features

- **Single-droplet** provisioning with sensible defaults
  (Ubuntu 24.04, `s-2vcpu-4gb`, `lon1`).
- **Cloud-init** runs the upstream `install-server.sh`, pins to a
  specific `runed` version, and writes a templated
  `runefile.toml`.
- **Edge or worker** role via `var.node_role`. Edge nodes bind
  :80/:443, open them in the firewall, and run the ACME
  orchestrator for `tls.mode = auto` services.
- **Optional bootstrap** (`var.bootstrap = true`) that waits for
  the gRPC port, runs `rune admin bootstrap`, copies the token
  locally, and emits a ready-to-paste `rune login` command as an
  output.
- **Project attachment**, **monitoring**, and **backups** toggles
  for production hygiene.

## Quick start

```hcl
module "rune" {
  source  = "runestack/rune/digitalocean"
  version = "0.0.3"

  ssh_key_ids = [data.digitalocean_ssh_key.main.id]

  node_role  = "edge"
  acme_email = "ops@example.com"
}

output "ip" {
  value = module.rune.ipv4_address
}
```

```bash
terraform init
terraform apply
```

Then point your DNS at `module.rune.ipv4_address` and SSH in to
bootstrap, or set `bootstrap = true` to do it automatically.

## Examples

| Path | What it shows |
|---|---|
| [`examples/minimal`](./examples/minimal) | Single worker node, no TLS. |
| [`examples/edge-with-tls`](./examples/edge-with-tls) | Edge node with ACME-managed TLS. |
| [`examples/with-bootstrap`](./examples/with-bootstrap) | Edge + automated `rune admin bootstrap`. |

## After `terraform apply`

If you set `bootstrap = true`, you're done — paste the
`rune_login_command` output. Otherwise:

```bash
ssh root@$(terraform output -raw ipv4_address) \
  'rune admin bootstrap --out-file /tmp/rune-admin.token'

scp root@$(terraform output -raw ipv4_address):/tmp/rune-admin.token \
  ./rune-admin.token

rune login dev \
  --server $(terraform output -raw grpc_endpoint) \
  --token-file ./rune-admin.token
```

## Cloud-init is at-most-once

Cloud-init runs **only on first boot**. Changing `var.rune_version`
or any value rendered into `runefile.toml` after the droplet exists
will NOT take effect on the running droplet. To roll a new config:

```bash
terraform apply -replace=module.rune.digitalocean_droplet.this
```

A non-destructive in-place upgrade path is on the roadmap (see
`CHANGELOG.md`).

## Bootstrap: re-rotate

```bash
terraform apply -replace=module.rune.null_resource.bootstrap[0]
```

This re-runs the SSH bootstrap and overwrites the local token file.
The previous token is invalidated by `rune admin bootstrap` itself
(it refuses to run twice on the same server unless reset).

## Compatibility

- Terraform `>= 1.5.0`
- `digitalocean/digitalocean` provider `>= 2.40, < 3.0`
- Ubuntu 24.04 LTS (older releases may work; not supported)

## Related modules

| Cloud | Module |
|---|---|
| DigitalOcean | This repo |
| AWS | `runestack/rune/aws` *(planned)* |
| Hetzner Cloud | `runestack/rune/hcloud` *(planned)* |
| GCP | `runestack/rune/google` *(planned)* |
| Azure | `runestack/rune/azurerm` *(planned)* |

## Contributing

Issues and PRs welcome. Please run `terraform fmt -recursive` and
`terraform validate` (in the root and each `examples/*` directory)
before opening a PR; CI will block otherwise.

## License

MIT — see [LICENSE](./LICENSE).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_digitalocean"></a> [digitalocean](#requirement\_digitalocean) | >= 2.40, < 3.0 |
| <a name="requirement_local"></a> [local](#requirement\_local) | >= 2.4 |
| <a name="requirement_null"></a> [null](#requirement\_null) | >= 3.2 |
## Providers

| Name | Version |
|------|---------|
| <a name="provider_digitalocean"></a> [digitalocean](#provider\_digitalocean) | >= 2.40, < 3.0 |
| <a name="provider_null"></a> [null](#provider\_null) | >= 3.2 |
## Resources

| Name | Type |
|------|------|
| [digitalocean_droplet.this](https://registry.terraform.io/providers/digitalocean/digitalocean/latest/docs/resources/droplet) | resource |
| [digitalocean_firewall.this](https://registry.terraform.io/providers/digitalocean/digitalocean/latest/docs/resources/firewall) | resource |
| [digitalocean_project_resources.this](https://registry.terraform.io/providers/digitalocean/digitalocean/latest/docs/resources/project_resources) | resource |
| [null_resource.bootstrap](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_acme_email"></a> [acme\_email](#input\_acme\_email) | Contact email for Let's Encrypt account registration. Required when node\_role = 'edge' and you intend to use tls.mode = auto/acme on services. | `string` | `""` | no |
| <a name="input_api_allowed_cidrs"></a> [api\_allowed\_cidrs](#input\_api\_allowed\_cidrs) | CIDR blocks allowed to reach the rune gRPC + HTTP API ports. | `list(string)` | <pre>[<br/>  "0.0.0.0/0",<br/>  "::/0"<br/>]</pre> | no |
| <a name="input_bootstrap"></a> [bootstrap](#input\_bootstrap) | When true, the module SSHes into the droplet after cloud-init finishes, runs `rune admin bootstrap`, copies the token to local disk, and outputs a `rune login` command. | `bool` | `false` | no |
| <a name="input_bootstrap_context_name"></a> [bootstrap\_context\_name](#input\_bootstrap\_context\_name) | CLI context name used in the emitted `rune login` command. Defaults to 'rune' when unset; the module appends '-<environment>'. | `string` | `""` | no |
| <a name="input_bootstrap_namespace"></a> [bootstrap\_namespace](#input\_bootstrap\_namespace) | Default namespace baked into the emitted `rune login` command. | `string` | `"default"` | no |
| <a name="input_bootstrap_ssh_private_key"></a> [bootstrap\_ssh\_private\_key](#input\_bootstrap\_ssh\_private\_key) | PEM-encoded SSH private key matching one of ssh\_key\_ids. Sensitive. Required when bootstrap = true. | `string` | `""` | no |
| <a name="input_bootstrap_ssh_user"></a> [bootstrap\_ssh\_user](#input\_bootstrap\_ssh\_user) | SSH user for the bootstrap step. DigitalOcean Ubuntu images use 'root'. | `string` | `"root"` | no |
| <a name="input_bootstrap_token_path"></a> [bootstrap\_token\_path](#input\_bootstrap\_token\_path) | Local path where the bootstrap admin token is written. Relative paths resolve against the consuming Terraform working directory. | `string` | `"rune-admin.token"` | no |
| <a name="input_bootstrap_wait_timeout"></a> [bootstrap\_wait\_timeout](#input\_bootstrap\_wait\_timeout) | How long to wait for the runed gRPC port to come up before bootstrapping. Format: '<n>m' or '<n>s'. | `string` | `"10m"` | no |
| <a name="input_cluster_cidr"></a> [cluster\_cidr](#input\_cluster\_cidr) | Cluster CIDR used by the rune networking layer for service IPs. | `string` | `"10.96.0.0/16"` | no |
| <a name="input_create_firewall"></a> [create\_firewall](#input\_create\_firewall) | Create a DigitalOcean firewall in front of the droplet. Disable if you manage firewalls externally. | `bool` | `true` | no |
| <a name="input_docker_registries"></a> [docker\_registries](#input\_docker\_registries) | Private Docker registries rendered into [[docker.registries]] in runefile.toml. Three shapes: (1) from\_secret reference to an externally-managed Rune Secret — runed infers auth\_type from the secret's keys; (2) from\_secret + bootstrap = true + data = { ... } — runed creates/updates the secret on first start using env-expanded values supplied via var.runed\_environment; (3) inline username/password/token rendered as plaintext into the runefile (demo use only). | <pre>list(object({<br/>    name      = string<br/>    registry  = string<br/>    auth_type = optional(string, "basic")<br/>    username  = optional(string, "")<br/>    password  = optional(string, "")<br/>    token     = optional(string, "")<br/>    region    = optional(string, "")<br/><br/>    # fromSecret mode (RUNE-018). When from_secret is non-empty<br/>    # runed reads credentials from the named Rune Secret and<br/>    # infers auth_type from the secret's keys; the inline<br/>    # username/password/token/auth_type fields are ignored.<br/>    # Combine with bootstrap = true + a data map to have runed<br/>    # create-or-update the secret on first start (data values<br/>    # are env-expanded against /etc/rune/runed.env, see<br/>    # var.runed_environment).<br/>    from_secret           = optional(string, "")<br/>    from_secret_namespace = optional(string, "")<br/>    bootstrap             = optional(bool, false)<br/>    manage                = optional(string, "")<br/>    immutable             = optional(bool, false)<br/>    data                  = optional(map(string), {})<br/>  }))</pre> | `[]` | no |
| <a name="input_droplet_size"></a> [droplet\_size](#input\_droplet\_size) | DigitalOcean droplet size slug. Edge nodes terminating ACME-signed traffic should be at least s-1vcpu-2gb. | `string` | `"s-2vcpu-4gb"` | no |
| <a name="input_enable_backups"></a> [enable\_backups](#input\_enable\_backups) | Enable weekly droplet backups. | `bool` | `false` | no |
| <a name="input_enable_ipv6"></a> [enable\_ipv6](#input\_enable\_ipv6) | Enable IPv6 on the droplet. | `bool` | `true` | no |
| <a name="input_enable_monitoring"></a> [enable\_monitoring](#input\_enable\_monitoring) | Enable DigitalOcean monitoring agent. | `bool` | `true` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment label used in the droplet name and tags (e.g. 'dev', 'prod'). | `string` | `"dev"` | no |
| <a name="input_extra_inbound_tcp_ports"></a> [extra\_inbound\_tcp\_ports](#input\_extra\_inbound\_tcp\_ports) | Additional TCP ports to open inbound (gated by api\_allowed\_cidrs). Useful while you stand up apps before they sit behind the edge ingress. | `list(number)` | `[]` | no |
| <a name="input_grpc_port"></a> [grpc\_port](#input\_grpc\_port) | Port for the rune gRPC API. | `number` | `7863` | no |
| <a name="input_http_port"></a> [http\_port](#input\_http\_port) | Port for the rune HTTP API. | `number` | `7861` | no |
| <a name="input_image"></a> [image](#input\_image) | Base image slug. Tested on Ubuntu 24.04 LTS; older Debian/Ubuntu releases may work but are unsupported. | `string` | `"ubuntu-24-04-x64"` | no |
| <a name="input_ingress_allowed_cidrs"></a> [ingress\_allowed\_cidrs](#input\_ingress\_allowed\_cidrs) | CIDR blocks allowed to reach :80 and :443 when node\_role = 'edge'. Public by default since edge nodes terminate user traffic. | `list(string)` | <pre>[<br/>  "0.0.0.0/0",<br/>  "::/0"<br/>]</pre> | no |
| <a name="input_log_format"></a> [log\_format](#input\_log\_format) | Log format (text or json). | `string` | `"text"` | no |
| <a name="input_log_level"></a> [log\_level](#input\_log\_level) | Log level (debug, info, warn, error). | `string` | `"info"` | no |
| <a name="input_metrics_addr"></a> [metrics\_addr](#input\_metrics\_addr) | Address for the Prometheus metrics endpoint. Default binds to loopback only; expose by setting to ':9100' AND opening the port via extra\_inbound\_tcp\_ports. | `string` | `"127.0.0.1:9100"` | no |
| <a name="input_node_role"></a> [node\_role](#input\_node\_role) | Rune node role. 'edge' nodes bind :80/:443 and run the ACME orchestrator; 'worker' nodes only run services. | `string` | `"edge"` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Optional DigitalOcean project ID to attach the droplet to. Empty disables attachment. | `string` | `""` | no |
| <a name="input_region"></a> [region](#input\_region) | DigitalOcean region slug. | `string` | `"lon1"` | no |
| <a name="input_rune_version"></a> [rune\_version](#input\_rune\_version) | Rune release tag passed to install-server.sh (e.g. 'v0.0.1-dev.35'). Pinned by default for reproducibility; bump per module release. | `string` | `"v0.0.1-dev.35"` | no |
| <a name="input_runed_environment"></a> [runed\_environment](#input\_runed\_environment) | Environment variables exported to the runed process via /etc/rune/runed.env (referenced by the systemd unit's EnvironmentFile). Use for secrets consumed by runefile bootstrap blocks (e.g. GHCR\_PAT for a registry's bootstrap data map). Pass via TF\_VAR\_runed\_environment or a sensitive tfvars file; values are written to the droplet's filesystem with mode 0600. | `map(string)` | `{}` | no |
| <a name="input_ssh_allowed_cidrs"></a> [ssh\_allowed\_cidrs](#input\_ssh\_allowed\_cidrs) | CIDR blocks allowed to reach SSH (port 22). Tighten in production. | `list(string)` | <pre>[<br/>  "0.0.0.0/0",<br/>  "::/0"<br/>]</pre> | no |
| <a name="input_ssh_key_ids"></a> [ssh\_key\_ids](#input\_ssh\_key\_ids) | DigitalOcean SSH key IDs (or fingerprints) to install on the droplet. At least one is required so cloud-init / bootstrap can reach the host. | `list(string)` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Extra droplet tags. The module always adds 'rune' and 'rune-<environment>'. | `list(string)` | `[]` | no |
## Outputs

| Name | Description |
|------|-------------|
| <a name="output_bootstrap_token_path"></a> [bootstrap\_token\_path](#output\_bootstrap\_token\_path) | Local path where the admin bootstrap token was written. Empty when bootstrap = false. |
| <a name="output_droplet_id"></a> [droplet\_id](#output\_droplet\_id) | DigitalOcean droplet ID. |
| <a name="output_droplet_name"></a> [droplet\_name](#output\_droplet\_name) | Droplet name (rune-<environment>). |
| <a name="output_firewall_id"></a> [firewall\_id](#output\_firewall\_id) | Firewall ID (empty when create\_firewall = false). |
| <a name="output_grpc_endpoint"></a> [grpc\_endpoint](#output\_grpc\_endpoint) | Address to point the rune CLI `--server` flag at. |
| <a name="output_http_endpoint"></a> [http\_endpoint](#output\_http\_endpoint) | rune HTTP API base URL. |
| <a name="output_ipv4_address"></a> [ipv4\_address](#output\_ipv4\_address) | Public IPv4 address of the droplet. |
| <a name="output_ipv6_address"></a> [ipv6\_address](#output\_ipv6\_address) | Public IPv6 address of the droplet (empty if disabled). |
| <a name="output_rune_login_command"></a> [rune\_login\_command](#output\_rune\_login\_command) | Ready-to-paste `rune login` command. Empty when bootstrap = false. |
| <a name="output_urn"></a> [urn](#output\_urn) | Droplet URN, useful when wiring further DigitalOcean resources. |
<!-- END_TF_DOCS -->
