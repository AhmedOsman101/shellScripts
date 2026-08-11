# ADR 011: fdfind→fd Symlink (Retained with Prompt)

## Status

Accepted

## Context

On Debian-based distros, the `fd` package is named `fdfind` to avoid a
name collision with another package. Scripts in this repo depend on
`fd` (the hook uses it for scanning, `init.sh` uses it for verification).

## Decision

If `fdfind` is available but `fd` is not, `init.sh` prompts the user
before creating a symlink from `fdfind` to `/usr/bin/fd`:

```bash
if command -v fdfind &>/dev/null && ! command -v fd &>/dev/null; then
  yesNo "...." # prompt user, then:
  sudo ln -sv "$(command -v fdfind)" /usr/bin/fd
fi
```

The prompt uses the same user-confirmation pattern as the shell config
installation (ADR 005). The user can refuse; in that case `init.sh`
prints instructions for creating the symlink manually.

## Consequences

- Modifying `/usr/bin/` requires `sudo` — the only `sudo` use remaining
  in `init.sh`.
- The prompt ensures the user knows their system is being modified.
- On non-Debian distros where `fd` is the actual package name, this
  code path is skipped.
- Refusing the prompt doesn't block the rest of `init.sh` — the
  subsequent `command -v fd` check will error out cleanly if `fd` is
  truly missing.
