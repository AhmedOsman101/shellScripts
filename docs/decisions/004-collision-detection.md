# ADR 004: Collision Detection in Hook

## Status

Superseded

## Context

When two scripts share a basename across different subdirectories (e.g.,
`python/foo.sh` and `bash/foo.sh`), both parent directories land on
`PATH`. Which `foo.sh` runs depends on `PATH` order — and since `find`
walks the tree in an order that may not match user expectations, the
"winner" can change without the user noticing.

The original decision was to detect these collisions in the hook script
and print a warning.

## Supersession

The original decision is reversed. Collision detection in the hook is
not needed because:

1. **Creation tools prevent collisions upstream.** `mkscript` (line 56)
   and `mkpython` (lines 43, 45) both check for existing scripts at
   creation time and error out if a basename already exists. Any script
   added through normal workflow cannot introduce a collision.

2. **The `bin/` directory is manually managed.** It contains hand-placed
   scripts (`clean-url`, `commit-sage`, etc.) without creation-tool
   protection. A collision there is a user error, not something the hook
   should guard against.

3. **The 3am-debugging concern doesn't materialize.** If `mkscript` blocks
   the collision at creation time, there's no collision for the hook to
   warn about later.

## Consequences

- The hook script is simpler — no collision detection logic, no stderr
  warnings at shell startup.
- Users who manually create scripts in `bin/` (bypassing `mkscript`) own
  the consequences of collisions themselves.
- If a future workflow change reintroduces the risk (e.g., bulk imports,
  new subdirectories without creation-tool integration), revisit this
  decision.
