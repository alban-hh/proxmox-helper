# Writing an addon

An addon is one Bash file in `addons/` named after its slug. Generate a
skeleton with `make new-addon SLUG=my-tool NAME="My Tool"` and fill in the
functions below.

## Required

| Function | Called when |
| --- | --- |
| `is_installed` | Before the menu, to decide which actions to offer |
| `install` | User picks install or passes `--install` |

## Optional

| Function | Called when |
| --- | --- |
| `prepare` | Right after the root check; put `require_docker`, `get_local_ip`, OS guards here |
| `describe` | Before the install prompt; print bullet lines starting with `${TAB}  - ` |
| `update` | User picks update or passes `--update` |
| `uninstall` | User picks uninstall or passes `--uninstall` |

Finish the file with `run_addon "$@"`. Tools that only make sense on the
Proxmox host define `main` and finish with `run_tool "$@"` instead.

## Conventions

- Set `APP` (display name) and `APP_SLUG` (must equal the file name).
- Keep paths in variables at the top: `INSTALL_PATH`, `CONFIG_PATH`,
  `SERVICE_NAME`, `DEFAULT_PORT`.
- Wrap noisy commands with `$STD` so the spinner stays clean.
- Bracket steps with `msg_info` and `msg_ok`.
- Use `fetch_gh_release` for anything published as a GitHub release and
  `gh_release_available` at the top of `update` so no-op updates exit early.
- Call `ensure_update_script` at the end of `install` when `update` exists,
  and `remove_update_script` in `uninstall`.
- Generate passwords with `random_alnum` and print them once with `msg_note`.
- Support Alpine when the tool does: check `is_alpine` and use
  `install_openrc_service` alongside `install_systemd_service`.

## Checklist before opening a PR

1. `make check`
2. `make test`
3. Run the script on a fresh container: install, run again and choose update,
   run again and choose uninstall.
4. Add a row to the right table in `README.md`.
