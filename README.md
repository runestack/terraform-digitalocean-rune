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
  version = "~> 0.1"

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
<!-- terraform-docs auto-fills this section in CI -->
<!-- END_TF_DOCS -->
