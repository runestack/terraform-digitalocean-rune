# Changelog

All notable changes to this module are documented here. Format
follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versioning follows [SemVer](https://semver.org/).

## [Unreleased]

### Added
- Initial public release.
- Single-droplet provisioning on DigitalOcean (droplet, firewall,
  optional project attachment).
- Cloud-init installs `runed` via the upstream installer pinned to
  `var.rune_version`.
- `node_role` toggle between `edge` (binds :80/:443, runs ACME) and
  `worker`.
- Optional `bootstrap = true` flow: SSHes in, runs
  `rune admin bootstrap`, copies the token to disk, outputs the
  ready-to-paste `rune login` command.
- Examples: `minimal`, `edge-with-tls`, `with-bootstrap`.

[Unreleased]: https://github.com/runestack/terraform-digitalocean-rune/commits/main
