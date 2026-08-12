# ADR 010: Exclusion Patterns

## Status

Accepted

## Context

The hook script (ADR 002) scans for executable files. Some directories
should never be scanned (`.git`, virtualenvs, `node_modules`). Users
may also have project-specific exclusions.

## Decision

Hardcoded defaults in the hook:

- `.git`
- `.venv`
- `venv`
- `node_modules`
- `release.sh`

Plus an env var `SCRIPTS_HOOK_EXCLUDE` (space-separated) for user
additions. The defaults cannot be overridden — only extended.

The hook calls `fd -t x` directly (not `fd.sh`) so it owns the exclude
logic. At scan time, the hook merges defaults + `SCRIPTS_HOOK_EXCLUDE`
into `fd`'s `--exclude` flags.

## Consequences

- The five defaults are universally correct — no one wants `.git/`,
  virtualenvs, `node_modules`, or `release.sh` files on PATH.
- Users with project-specific needs (e.g., `build/`, `dist/`) can add
  them via the env var.
- The env var name is documented in the help output (ADR 009).
- If someone needs to *remove* a default exclusion, they can override
  the hook itself — the defaults are not configurable downward.
