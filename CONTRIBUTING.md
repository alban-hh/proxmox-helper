# Contributing

Thanks for looking. This started as a personal toolbox, so the bar is
"does it work on a real Proxmox box and is it readable", not much more.

## Ground rules

- Bash only. No Python, no Node, nothing that needs installing before the
  script can run.
- No comments in shell files. Name things well instead. The smoke test
  fails if it finds any.
- Two-space indentation, `shfmt -i 2` style. Run `make fmt` before pushing.
- Every addon must pass `make check` and `make test`.
- Never ship default passwords. Generate them with `random_alnum` and print
  them once.

## Adding an addon

```bash
make new-addon SLUG=my-tool NAME="My Tool"
```

That drops a skeleton into `addons/my-tool.sh`. Fill in `is_installed`,
`install`, `update` and `uninstall`. Add `prepare` for checks that must run
before the menu (Docker present, running inside a container, and so on) and
`describe` for the bullet list shown before installing.

Everything the addon needs from the shared library is listed in
`docs/library.md`. If you find yourself copying a block between two addons,
move it into `lib/` instead.

## Testing

`make test` runs the smoke tests. They do not install anything; they check
that scripts parse, follow the contract, and answer `--help`. Actually
installing the tool on a throwaway container is still on you.

## Commits

Small commits with an imperative subject line. One addon or one fix per
commit is ideal.
