# ADR 007: Documentation Structure — ADRs

## Status

Accepted

## Context

Design decisions made during the `init.sh` redesign need to be recorded
so future maintainers understand why things are the way they are. Three
organizational approaches were considered:

1. **One file per decision (ADR-style)** — each decision is a standalone
   artifact with context, decision, and consequences.
2. **One file per component** — all decisions for `init.sh` in one file,
   all decisions for the hook in another.
3. **Single design doc** — everything in one large file.

## Decision

Use ADR-style organization: one file per major decision in
`docs/decisions/`, numbered sequentially (`001-no-symlinks.md`,
`002-hook-script.md`, etc.). Each ADR has:

- **Status** — Accepted / Superseded / Deprecated
- **Context** — the problem being solved
- **Decision** — what was decided
- **Consequences** — what follows from the decision

## Consequences

- Decisions are individually addressable. A future "should we support
  fish?" discussion can reference ADR 006 directly.
- ADRs don't rot the way component docs do — a decision's reasoning is
  stable even if the implementation changes.
- Easy to add new ADRs as new decisions arise.
- Sequential numbering makes the design history browsable.
- When a decision is reversed, the old ADR gets marked Superseded and a
  new one supersedes it — the history is preserved.
