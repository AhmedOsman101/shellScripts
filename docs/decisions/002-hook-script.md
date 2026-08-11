# ADR 002: PATH Discovery via Hook Script

## Status

Accepted

## Context

With the repo as source of truth (ADR 001), scripts live in subdirectories
(`python/`, `c/`, `bash/`, etc.) but need to be runnable by basename from
anywhere. Simply adding `$SCRIPTS_DIR` to `PATH` only makes
`python/foo.sh` callable as `python/foo.sh`, not `foo.sh`.

The user already had inline zsh logic in `~/.config/zsh/variables.sh` that
scans for executable files and adds their parent directories to `PATH`.

## Decision

Extract the PATH discovery logic into a standalone hook script at
`$SCRIPTS_DIR/hooks/path.sh`. The user's shell config sources it
conditionally:

```bash
[[ -s "${SCRIPTS_DIR}/hooks/path.sh" ]] && source "${SCRIPTS_DIR}/hooks/path.sh"
```

If the repo is deleted or `SCRIPTS_DIR` points elsewhere, the source line
silently does nothing — no error, no bloat.

The hook lives inside the repo (versioned, reviewed, updated alongside
everything else) and is created/maintained there, not by `init.sh`.

## Consequences

- `init.sh`'s job is reduced to: verify the setup, ensure the shell config
  has the source line, and prompt the user if it doesn't.
- The hook is reused across all shells (bash, zsh) with no per-shell
  variants.
- Moving the repo to a new location only requires updating `SCRIPTS_DIR`
  — the source line path is relative to that variable.
- The conditional source means there's no error spam if the repo is gone.
