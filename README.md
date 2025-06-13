# proxmox-helper

Bash scripts I use to bolt tools onto my Proxmox LXC containers without
retyping the same twenty commands every time. Each script installs, updates
or removes one tool, asks the minimum number of questions, and prints the
URL when it is done. Sharing in case they save someone else an evening.

## Quick start

Inside the container (or on the host, for the few scripts that say so):

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/alban-hh/proxmox-helper/main/addons/portainer.sh)"
```

Swap `portainer` for any name in the table below. Prefer a local checkout?

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/alban-hh/proxmox-helper/main/install.sh)"
pxh list
pxh run dockge
```

## How it works

Every addon is a single file in `addons/` that sources the shared library in
`lib/`. When you run it from a checkout the library loads from disk; when you
run it through `curl` the library is fetched from this repo. Either way the
script ends up with the same helpers: coloured output with spinners, apt and
apk wrappers, GitHub release downloads, systemd and OpenRC service writers,
Docker Compose shortcuts, and a small runner that turns `is_installed`,
`install`, `update` and `uninstall` functions into an interactive menu.

Run an addon with no arguments and it looks at the box, tells you whether the
tool is already there, and offers install, update or remove. Pass
`--install`, `--update` or `--uninstall` to skip the menu.

## Addons

### Containers and Docker

| Script | What you get | Port |
| --- | --- | --- |
| `portainer` | Portainer CE via Compose, handles standalone installs too | 9443 |
| `dockge` | Dockge with a stacks directory in `/opt/stacks` | 5001 |
| `arcane` | Arcane Docker manager with generated secrets | 3552 |
| `komodo` | Komodo core with MongoDB or FerretDB | 9120 |
| `coolify` | Coolify through the upstream installer | 8000 |
| `dokploy` | Dokploy through the upstream installer | 3000 |
| `runtipi` | Runtipi through the upstream installer | 80 |

All of these expect Docker already present and offer to install it when it
is not.

### Files and sharing

| Script | What you get | Port |
| --- | --- | --- |
| `filebrowser` | FileBrowser with a generated admin password | 8080 |
| `filebrowser-quantum` | FileBrowser Quantum with ffmpeg previews, replaces a classic install if found | 8080 |
| `copyparty` | Copyparty under its own user with thumbnails | 3923 |

Each runs on Debian, Ubuntu and Alpine and writes the matching systemd or
OpenRC service.

### Monitoring and metrics

| Script | What you get | Port |
| --- | --- | --- |
| `netdata` | Netdata agent on the Proxmox host itself | 19999 |
| `glances` | Glances with the web UI in a uv-managed venv | 61208 |
| `jellystat` | Jellystat built from source with PostgreSQL 17 | 3000 |
| `actual-budget-prometheus-exporter` | Prometheus exporter for Actual Budget | 3001 |
| `nextcloud-exporter` | Prometheus exporter for Nextcloud | 9205 |
| `pihole-exporter` | Prometheus exporter for Pi-hole, built with Go | 9617 |
| `prometheus-paperless-ngx-exporter` | Prometheus exporter for Paperless-ngx | 8081 |
| `qbittorrent-exporter` | Prometheus exporter for qBittorrent, built with Go | 8090 |

The exporters ask for the target URL and credentials once and store them in
an env file with mode 600.

### Networking and security

| Script | What you get | Runs on |
| --- | --- | --- |
| `tailscale` | Adds Tailscale to an existing container, including the TUN device | host |
| `netbird` | Adds NetBird to an existing Debian or Ubuntu container | host |
| `crowdsec` | CrowdSec agent plus the iptables bouncer | container |
| `adguardhome-sync` | Keeps a replica AdGuard Home in step with the origin | container |

The two host tools pick the container from a list and tag it afterwards so
you can see at a glance which containers carry a VPN client.
