# Changelog

All notable changes to this module are documented here. Format
follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versioning follows [SemVer](https://semver.org/).

This module is pre-1.0 and tracks Rune's own pre-1.0 development.
Breaking changes can land on any minor bump (`0.x.0`) until
`v1.0.0`. Patch bumps (`0.x.y`) stay backwards-compatible.

## [Unreleased]

### Added
- `var.docker_registries[*]` gained `from_secret`,
  `from_secret_namespace`, `bootstrap`, `manage`, `immutable`,
  and `data` fields. Setting `from_secret` makes the rendered
  runefile reference an encrypted Rune Secret instead of
  embedding plaintext credentials. Combined with
  `bootstrap = true` + a `data = { ... }` map, runed creates or
  updates the Secret on first start using env-expanded values
  (RUNE-018 secret-bootstrap mode), so PATs and tokens never
  land in the runefile or in Terraform state as cleartext config.
  Once a fromSecret is set, runed infers the auth type from the
  secret's data keys (username+password → basic, token → bearer,
  .dockerconfigjson → docker config JSON, awsAccessKeyId+… →
  ECR), so omit `auth_type` and inline credentials in that mode.
- `var.runed_environment` (sensitive map) — written to
  `/etc/rune/runed.env` (mode 0600) and consumed by the `runed`
  systemd unit via `EnvironmentFile=`. Used to supply env-backed
  values for `bootstrap` registry data (e.g. `GHCR_PAT`) and any
  other `${ENV}` references inside the runefile.
- Two new plan-time validations on `docker_registries`:
  inline `username`/`password`/`token` may not coexist with
  `from_secret` (would be silently ignored by runed); and
  `data = { ... }` requires `bootstrap = true` (data is the
  bootstrap seed and is ignored at runtime).

### Changed
- `runed.service` written by cloud-init now declares
  `EnvironmentFile=-/etc/rune/runed.env` (the leading `-` makes it
  optional, so existing applies without `runed_environment` keep
  working). The runefile is also `chmod 600` after rendering.
- `runefile.toml.tftpl` no longer renders `auth.type` when
  `from_secret` is set — runed will overwrite it from the
  secret's keys anyway, so emitting it was misleading.
- `examples/with-bootstrap` demonstrates GHCR credentials stored
  as a Rune Secret via the new `from_secret` + `bootstrap` flow.

## [0.0.4] - 2026-05-10

### Added
- `var.docker_registries` — list of registry credentials rendered
  into `[[docker.registries]]` blocks in `runefile.toml`. Supports
  `auth_type = "basic"` (username + password / GHCR PAT),
  `"token"` (long-lived bearer), and `"ecr"` (AWS region; runed
  mints short-lived tokens at pull time). Closes the gap that
  forced operators to SSH in and run `rune admin registry add`
  after every apply, or to ship credentials out-of-band.

### Changed
- `var.rune_version` default bumped from `v0.0.1-dev.22` to
  `v0.0.1-dev.32`. Pulls in: per-RPC CLI deadlines (no more
  hung `rune whoami`), gRPC + OTel security bumps, the
  ListInstances filter fix (so `rune get service <name>` shows
  instances again), the install-server.sh runefile-placement
  fix (canonical `/etc/rune/runefile.toml` + explicit `--config`
  flag), and CreateToken policy validation (so `--policy <typo>`
  fails fast instead of silently issuing a useless token).

## [0.0.3] - 2026-05-09

### Changed
- `local.rune_login_command` (output `rune_login_command`) now emits
  `--default-namespace` instead of `--namespace`. The `--namespace`
  flag on `rune login` was overloaded with the per-operation
  `--namespace` flag used everywhere else in the CLI; the new flag
  name reflects that this value is *stored* in the saved context as
  the default for future commands, not the target of the login.

### Compatibility
- Requires Rune CLI ≥ `v0.0.1-dev.23` on the operator's machine
  (the version that introduces `--default-namespace`). Older CLIs
  will reject the unknown flag. The deprecated `--namespace` alias
  remains accepted by the new CLI for one release; if you must
  support an older operator CLI, pin this module to `0.0.2`.

## [0.0.2] - 2026-05-09

### Changed
- `examples/with-bootstrap` now takes the SSH private key as PEM
  contents (`var.ssh_private_key`) instead of reading from a path
  with `file()`. The previous default (`~/.ssh/id_ed25519`) failed
  static lint runs (tflint, `terraform validate` in CI) because
  `file()` is evaluated at configuration time and the path doesn't
  exist in CI runners. Pass via
  `TF_VAR_ssh_private_key="$(cat ~/.ssh/id_ed25519)"`.

## [0.0.1] - 2026-05-09

### Added
- Initial public release.
- Single-droplet provisioning on DigitalOcean (droplet, firewall,
  optional project attachment).
- Cloud-init installs `runed` via the upstream installer pinned to
  `var.rune_version` (default `v0.0.1-dev.22`).
- `node_role` toggle between `edge` (binds :80/:443, runs ACME) and
  `worker`.
- Optional `bootstrap = true` flow: SSHes in, runs
  `rune admin bootstrap`, copies the token to disk, outputs the
  ready-to-paste `rune login` command.
- Examples: `minimal`, `edge-with-tls`, `with-bootstrap`.

[Unreleased]: https://github.com/runestack/terraform-digitalocean-rune/compare/v0.0.4...HEAD
[0.0.4]: https://github.com/runestack/terraform-digitalocean-rune/releases/tag/v0.0.4
[0.0.3]: https://github.com/runestack/terraform-digitalocean-rune/releases/tag/v0.0.3
[0.0.2]: https://github.com/runestack/terraform-digitalocean-rune/releases/tag/v0.0.2
[0.0.1]: https://github.com/runestack/terraform-digitalocean-rune/releases/tag/v0.0.1
