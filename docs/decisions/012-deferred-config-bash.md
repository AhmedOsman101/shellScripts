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

## Implementation Sketch (When Revived)

When this enhancement is eventually implemented, the expected shape is:

- A `templates/config.example.bash` ships with the repo.
- `init.sh` checks for `$SCRIPTS_DIR/config.bash` and creates it (from
  the template) if not present.
- The hook sources `$SCRIPTS_DIR/config.bash` at startup.

## Consequences

- `init.sh` stays simple — no template copying, no `.gitignore`
  manipulation, no config-file creation logic in this iteration.
- The hook has no extra sourcing step beyond what ADR 003 specifies.
- Users with simple needs use `SCRIPTS_HOOK_EXCLUDE` (ADR 010) directly
  via env var.
- The deferred status and the implementation sketch are both recorded
  so future maintainers know this was considered, consciously
  postponed, and have a starting point when it's time to revive it.
