# Security

These scripts run as root and pull software from upstream projects. A few
things are worth knowing before you run one.

- Scripts download release assets straight from the upstream GitHub release
  or the vendor's own repository. Nothing is mirrored here.
- Some addons (Coolify, Dokploy, Runtipi, Homebrew, CrowdSec) run the
  vendor's own installer. The script says so and asks before doing it.
- Generated passwords are printed once and, where noted, written to a
  `.creds` file in root's home with mode 600.
- `GITHUB_TOKEN` is only ever sent to `api.github.com`.

If you find a problem, open an issue with the affected script and the exact
failure. For anything sensitive, email the address on my GitHub profile
instead.
