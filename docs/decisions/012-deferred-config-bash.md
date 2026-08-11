# ADR 012: Deferred — config.bash Template

## Status

Deferred

## Context

A future enhancement was proposed: a `config.example.bash` template
shipped in `templates/`, copied to `$SCRIPTS_DIR/config.bash` on
`init.sh` run, gitignored, and sourced by the hook. This would let
users set hook-specific config (custom exclusion patterns, cache
invalidation tuning, etc.) in a file rather than env vars.

## Decision

Defer this enhancement. The env var approach (`SCRIPTS_HOOK_EXCLUDE`,
ADR 010) covers the immediate need for user-configurable exclusions. A
full config file adds machinery (template copying, gitignore
manipulation, sourcing logic in the hook) without a concrete user
benefit yet.

If a real need emerges (e.g., users want to set multiple config values,
or env vars become unwieldy), revisit this decision and create a new
ADR.

## Consequences

- `init.sh` checks for `$SCRIPTS_DIR/config.bash` and creates it if not present.
- The hook has sources the config.
- The deferred status is recorded so future maintainers know this was considered and consciously postponed, not forgotten.
