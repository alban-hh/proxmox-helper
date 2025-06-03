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
