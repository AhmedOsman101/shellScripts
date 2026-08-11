# ADR 006: Shell Support — bash and zsh

## Status

Accepted

## Context

The hook script (ADR 002) and `init.sh` (ADR 005) both interact with
shell config files. Which shells to support affects the implementation
surface and the scope of testing.

## Decision

Support **bash** and **zsh** in this iteration. Both share enough syntax
for the hook (`export PATH=...`, `[[ ... ]]`, `source ...`) that one
file works for both. Fish support is explicitly reserved for another session.

The `-s|--shell` flag (repeated) accepts `bash` and/or `zsh`. When not
passed, `init.sh` detects from `$SHELL` (basename).

## Consequences

- Covers ~95% of Linux/macOS shell users.
- No fish-specific syntax to maintain (fish uses `set -gx PATH ...` instead of `export PATH=...`).
- If fish support is added later, it's a hook variant (`./hooks/path.fish`) and an extra case
  in the `-s` flag — not a redesign.
- The hook script itself is shell-agnostic enough that a future fish
  port would only need some syntax tweaks.
