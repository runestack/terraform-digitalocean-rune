# Changelog

All notable changes to this module are documented here. Format
follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versioning follows [SemVer](https://semver.org/).

This module is pre-1.0 and tracks Rune's own pre-1.0 development.
Breaking changes can land on any minor bump (`0.x.0`) until
`v1.0.0`. Patch bumps (`0.x.y`) stay backwards-compatible.

## [Unreleased]

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

[Unreleased]: https://github.com/runestack/terraform-digitalocean-rune/compare/v0.0.2...HEAD
[0.0.2]: https://github.com/runestack/terraform-digitalocean-rune/releases/tag/v0.0.2
[0.0.1]: https://github.com/runestack/terraform-digitalocean-rune/releases/tag/v0.0.1
