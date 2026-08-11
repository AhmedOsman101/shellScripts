# ADR 009: Help Output Format

## Status

Accepted

## Context

`init.sh -h|--help` needs to document the env vars users can override and the available flags.
The format should be scannable, like `pi --help`:

```
Environment Variables:
  ANTHROPIC_AUTH_TOKEN             - Anthropic bearer auth token
  ANTHROPIC_API_KEY                - Anthropic Claude API key
  ...
```

## Decision

The help output lists each env var on its own line with a fixed-width
name column, followed by a description. If a default exists, it shows
`(default: ...)` inline.

Documented variables:

- `SCRIPTS_DIR` — source repo path. (default: `~/scripts`)
- `SCRIPTS_HOOK_EXCLUDE` — space-separated exclusion patterns.
  (default: `.git .venv venv node_modules`)

No exclusion internals, no cache file path, no hook file path — those are implementation details.

## Consequences

- Scannable in under 10 lines.
- Adding a new env var later is one line in the help output.
