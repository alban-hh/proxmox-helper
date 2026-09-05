# proxmox-helper

[![lint](https://github.com/alban-hh/proxmox-helper/actions/workflows/lint.yml/badge.svg)](https://github.com/alban-hh/proxmox-helper/actions/workflows/lint.yml)
![shell](https://img.shields.io/badge/shell-bash-4EAA25)
![license](https://img.shields.io/badge/license-MIT-blue)

Bash scripts that install, update and remove self-hosted tools inside Proxmox LXC containers. Each addon is one file, asks the minimum number of questions and prints the URL when it is done.

## Quick start

Run any addon straight from the repo inside the container:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/alban-hh/proxmox-helper/main/addons/portainer.sh)"
```

Or install the `pxh` launcher and work from a local checkout:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/alban-hh/proxmox-helper/main/install.sh)"
pxh list
pxh run dockge
pxh update-all
pxh doctor
```

Needs root, `curl`, and Debian 12+, Ubuntu 22.04+ or Alpine 3.19+ in the container. Host tools need Proxmox VE 8+. amd64 and arm64 are supported.

## How it works

Every addon sources the shared library in `lib/`, from disk on a checkout or from this repo when run through `curl`. The library provides coloured output, apt and apk wrappers, GitHub release downloads, systemd and OpenRC service writers, Docker Compose helpers and a runner that turns `is_installed`, `install`, `update` and `uninstall` functions into an interactive menu.

Every addon accepts `--install`, `--update` and `--uninstall` to skip the menu, `--yes` to accept all defaults, `--verbose` to show command output and `--help`. `PXH_ASSUME_YES=1` works as `--yes` for cloud-init or `pct exec` one-liners. Addons that support updates also drop an `update_<name>` script into `/usr/local/bin`.

## Addons

### Containers and Docker

| Script | What you get | Port |
| --- | --- | --- |
| `portainer` | Portainer CE via Compose | 9443 |
| `dockge` | Dockge with stacks in `/opt/stacks` | 5001 |
| `arcane` | Arcane Docker manager | 3552 |
| `komodo` | Komodo core with MongoDB or FerretDB | 9120 |
| `coolify` | Coolify via the upstream installer | 8000 |
| `dokploy` | Dokploy via the upstream installer | 3000 |
| `runtipi` | Runtipi via the upstream installer | 80 |

### Files and sharing

| Script | What you get | Port |
| --- | --- | --- |
| `filebrowser` | FileBrowser with a generated admin password | 8080 |
| `filebrowser-quantum` | FileBrowser Quantum with ffmpeg previews | 8080 |
| `copyparty` | Copyparty under its own user | 3923 |

### Monitoring and metrics

| Script | What you get | Port |
| --- | --- | --- |
| `netdata` | Netdata agent on the Proxmox host | 19999 |
| `glances` | Glances with the web UI | 61208 |
| `jellystat` | Jellystat with PostgreSQL 17 | 3000 |
| `actual-budget-prometheus-exporter` | Prometheus exporter for Actual Budget | 3001 |
| `nextcloud-exporter` | Prometheus exporter for Nextcloud | 9205 |
| `pihole-exporter` | Prometheus exporter for Pi-hole | 9617 |
| `prometheus-paperless-ngx-exporter` | Prometheus exporter for Paperless-ngx | 8081 |
| `qbittorrent-exporter` | Prometheus exporter for qBittorrent | 8090 |

### Networking and security

| Script | What you get | Runs on |
| --- | --- | --- |
| `tailscale` | Adds Tailscale to a container, including the TUN device | host |
| `netbird` | Adds NetBird to a Debian or Ubuntu container | host |
| `crowdsec` | CrowdSec agent plus the iptables bouncer | container |
| `adguardhome-sync` | Keeps a replica AdGuard Home in sync | container |

### Admin and developer tools

| Script | What you get | Port |
| --- | --- | --- |
| `webmin` | Webmin from the latest release | 10000 |
| `phpmyadmin` | phpMyAdmin behind Apache or Lighttpd | 80 |
| `coder-code-server` | VS Code in the browser | 8680 |
| `cronmaster` | CronMaster scheduler | 3000 |
| `olivetin` | OliveTin action runner | 1337 |
| `homebrew` | Linuxbrew for the first regular user | - |
| `immich-public-proxy` | Public sharing proxy for Immich | 3000 |
| `sparkyfitness-garmin` | Garmin sync service for SparkyFitness | 8000 |
| `all-templates` | Creates a container from any Proxmox template (host) | - |

## Development

```bash
make check
make test
make new-addon SLUG=my-tool NAME="My Tool"
```

The library is documented in `docs/library.md` and the addon contract in `docs/writing-addons.md`.

## License

MIT. Test on a disposable container first.
