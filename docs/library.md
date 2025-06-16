# Library reference

Everything under `lib/` is sourced by `lib/bootstrap.sh`, either from disk
or from the raw GitHub URL in `PXH_REPO`. Functions are grouped by file.

## colors.sh

Colour escape variables (`YW`, `BL`, `RD`, `GN`, `BOLD`, `CL`) plus the
`TAB`, `CM`, `CROSS`, `INFO` and `HOURGLASS` prefixes used by the message
helpers.

## output.sh

| Function | Purpose |
| --- | --- |
| `msg_info "text"` | Starts a spinner (or prints a line when not a TTY / verbose) |
| `msg_ok "text"` | Stops the spinner and prints a green check line |
| `msg_warn "text"` | Yellow notice on stderr |
| `msg_error "text"` | Red error on stderr |
| `msg_note "text"` | Plain blue informational line |
| `header_info` | Clears the screen and prints the addon title |
| `stop_spinner` | Kills a running spinner; safe to call twice |

## runtime.sh

| Function | Purpose |
| --- | --- |
| `silent cmd...` | Runs a command with output appended to `PXH_LOG` |
| `$STD cmd...` | Expands to `silent` unless `VERBOSE=yes` |
| `enable_error_handling` | `set -Eeuo pipefail` with the shared ERR trap |
| `root_check` | Exit 104 unless running as root |
| `is_alpine`, `on_pve_host` | Environment predicates |
| `require_pve_host`, `require_debian_like`, `confirm_not_pve_host` | Guards used in `prepare` |
| `arch_resolve [amd64_val] [arm64_val]` | Prints the architecture in the naming scheme you pass |
| `detect_codename` | Debian or Ubuntu codename from `/etc/os-release` |
| `random_alnum [len]` | Random alphanumeric string, default 32 chars |

## network.sh

| Function | Purpose |
| --- | --- |
| `get_local_ip` | Sets and exports `LOCAL_IP` |
| `check_internet` | Exit 6 when github.com does not resolve |
| `curl_download out url` | Download with three retries and stall detection |

## packages.sh

| Function | Purpose |
| --- | --- |
| `ensure_packages pkg...` | Install only the packages that are missing |
| `install_packages pkg...` | Install unconditionally |
| `remove_packages pkg...` | Purge packages |
| `pkg_is_installed pkg` | dpkg or apk aware check |
| `setup_deb822_repo name gpg_url repo_url suite [component] [arch]` | Adds a signed apt source and refreshes the index |

## prompts.sh

| Function | Purpose |
| --- | --- |
| `confirm "question"` | y/N prompt, honours `PXH_ASSUME_YES` |
| `ask "question" [default]` | Free text with default |
| `ask_required "question"` | Loops until non-empty |
| `ask_secret "question"` | Hidden input |

## github.sh

| Function | Purpose |
| --- | --- |
| `fetch_gh_release app repo mode [version] [target] [pattern]` | Downloads a release; mode is `tarball`, `binary`, `prebuild` or `singlefile` |
| `gh_release_available app repo [pinned]` | Returns 0 when a newer release exists; sets `RELEASE_TAG` and `RELEASE_VERSION` |
| `gh_latest_tag repo` | Prints the latest tag name |
| `gh_installed_version app` | Reads `~/.<app>` |

Set `CLEAN_INSTALL=1` before `fetch_gh_release` to wipe the target first.
Set `GITHUB_TOKEN` to raise the API rate limit.

## docker.sh

| Function | Purpose |
| --- | --- |
| `require_docker` | Exit 237 unless Docker and Compose are present |
| `ensure_docker` | Offer to install Docker when missing |
| `compose_up dir`, `compose_pull dir`, `compose_down dir` | Compose shortcuts |
| `compose_update dir` | Pull then up, with messages |

## services.sh

| Function | Purpose |
| --- | --- |
| `install_systemd_service name "unit text"` | Writes the unit and reloads |
| `install_openrc_service name "script body"` | Writes an OpenRC script |
| `enable_service`, `start_service`, `stop_service`, `restart_service`, `remove_service` | Init-system agnostic |
| `service_is_active name` | Status check |
| `ensure_update_script [slug]` | Writes `/usr/local/bin/update_<slug>` |
| `remove_update_script [slug]` | Deletes it |
| `persist_usr_local_bin` | Makes sure `/usr/local/bin` is on PATH for login shells |
| `ensure_state_dir` | Creates `/usr/local/proxmox-helper` |

## users.sh

`create_system_user name [home] [group]`, `remove_system_user name [group]`
and `owned_dirs owner dir...` for service accounts.

## backup.sh

`create_backup path...` copies paths into `/opt/<slug>.backup` and
`restore_backup` puts them back and removes the store. Both read
`BACKUP_DIR` if you need a different location.

## toolchains.sh

`setup_nodejs` (`NODE_VERSION`, `NODE_MODULE`), `setup_uv`
(`PYTHON_VERSION`), `setup_go` (`GO_VERSION`) and `setup_postgresql`
(`PG_VERSION`).

## postgres.sh

`pg_create_database db user password`, `pg_drop_database db user`,
`pg_database_exists db`, `pg_role_exists user`.

## pve.sh

Host-only helpers: `select_container "prompt"`, `ensure_container_running
ctid`, `container_distro ctid`, `allow_tun_device ctid`, `add_container_tag
ctid tag`, `next_free_vmid`, `select_storage container|template`.

## addon.sh

`run_addon "$@"` drives the install/update/uninstall lifecycle from the
functions an addon defines. `run_tool "$@"` is the simpler entry point for
host tools that just have a `main`.
