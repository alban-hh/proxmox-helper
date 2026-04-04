# Changelog

## Unreleased

- Add SparkyFitness Garmin addon.
- Add Arcane addon.
- Add CronMaster addon.
- Move Komodo to the v2 environment layout during updates.

## 0.1.0

First public cut.

- Shared library under `lib/` for output, packages, services, GitHub
  releases, Docker and Proxmox host helpers.
- 25 addons that run inside an LXC container and 3 tools that run on the
  Proxmox host.
- `pxh` launcher with `list`, `run`, `update`, `update-all` and `doctor`.
- `--yes` and `--verbose` flags on every addon.
- Smoke tests and CI with shellcheck and shfmt.
