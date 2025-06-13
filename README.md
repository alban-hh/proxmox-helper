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
