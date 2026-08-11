# ADR 008: init.sh Flag Set

## Status

Accepted

## Context

`init.sh` needs user-facing flags for help and shell selection. The
question is how much surface area to expose.

## Decision

Two flags only:

- `-h|--help` — print usage, env var documentation (pi --help style),
  and exit.
- `-s|--shell <name>` — repeated array flag. Names which shell configs to
  install into. Accepted values: `bash`, `zsh`. When not passed,
  `init.sh` detects from `$SHELL` basename.

No `--dry-run`, no `--uninstall`, no `--force`. The interface is
deliberately minimal — the script is one logical operation (verify +
install), and the user is not expected to need more granularity.

## Consequences

- Simple to implement and document.
- The help output is the primary documentation surface (ADR 009).
- Adding `--uninstall` later is a backward-compatible addition if a
  real need emerges.
- The `-s` flag's array semantics (repeated) match `cmdarg`'s `[]` array
  pattern used elsewhere in the repo.
- Need to measure whether if we use `cmdarg` or not.
