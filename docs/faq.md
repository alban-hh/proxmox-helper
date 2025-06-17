# FAQ

**Do these replace the community Proxmox scripts?**
No. Those create whole containers. These add one tool to a container you
already have, or in three cases do a small job on the host.

**Can I run them on the Proxmox host?**
Only `netdata`, `tailscale`, `netbird` and `all-templates` are meant for the
host. The rest warn and ask before continuing there.

**Which distributions work inside the container?**
Debian and Ubuntu everywhere. Alpine where the tool supports it: the file
servers, the Go exporters, Glances, Docker-based addons and AdGuardHome
Sync.

**Where do generated passwords go?**
Printed once at the end of the install and, for Komodo and
Jellystat, also written to a `.creds` file in root's home.

**The GitHub API says rate limited.**
Export `GITHUB_TOKEN=ghp_...` before running the script. A token with no
scopes is enough.

**How do I see what a script is doing?**
Add `--verbose`. Without it, command output goes to `/tmp/proxmox-helper.log`
and the last twenty lines are shown when something fails.

**Can I pin a release?**
Not yet. Every addon installs the latest non-prerelease tag.
