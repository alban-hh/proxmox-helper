# Exit codes

The error handler prints the code, a short description, the failing line and
the last lines of the log. This is the mapping it uses.

| Code | Meaning |
| --- | --- |
| 1 | General error |
| 6 | DNS resolution failed |
| 7 | Failed to connect to host |
| 22 | HTTP error returned by server |
| 28 | Network operation timed out |
| 64 | Invalid arguments |
| 65 | Invalid data or unsupported format |
| 100 | Package manager error |
| 104 | Not running as root |
| 106 | Unsupported architecture |
| 112 | Invalid menu selection |
| 115 | Download failed |
| 119 | No suitable storage found |
| 150 | Service failed to start |
| 232 | Must run on the Proxmox VE host |
| 233 | Application is not installed |
| 237 | Docker is not available |
| 238 | Unsupported operating system |
| 250 | No release found upstream |
| 251 | Archive extraction failed |
| 252 | No matching release asset |
| 254 | Cancelled by user |

Re-run with `--verbose` to see the full command output instead of the
spinner when something fails.
