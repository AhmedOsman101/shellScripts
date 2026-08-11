# ADR 005: init.sh Installs via Grep + Prompt

## Status

Accepted

## Context

`init.sh` needs to ensure the user's shell config sources the hook
(ADR 002). The source line is:

```bash
[[ -s "${SCRIPTS_DIR}/hooks/path.sh" ]] && source "${SCRIPTS_DIR}/hooks/path.sh"
```

Approaches considered:

1. **Append directly** — modify `.zshrc`/`.bashrc` automatically. Risk of
   duplicate lines on re-run, mixing generated code with user config.
2. **Print and ask** — output the line and instructions, let the user
   paste it. Predictable, non-destructive.
3. **Dedicated file** — write to `~/.config/scripts/rc.sh`, source that
   from shell config. Extra layer of indirection.

## Decision

`init.sh` greps the appropriate shell config for the source line:

- zsh: `${ZDOTDIR:-$HOME}/.zshrc` (defaulting to `$HOME`)
- bash: `$HOME/.bashrc`

If the line is present, do nothing. If absent, prompt the user using the
`yesNo` helper from `lib/helpers.sh`. If accepted, append the line. If
refused, print the line with instructions ("add this to your shell
config") and continue.

`init.sh` never silently modifies shell config files. Re-running
`init.sh` is idempotent — grep detects existing lines, no duplicates.

## Consequences

- Users see exactly what's being added to their config.
- Re-running `init.sh` is safe.
- Refusing the prompt doesn't block the rest of the install (verifying
  `SCRIPTS_DIR`, checking `fd`, etc. still runs).
- The `-s|--shell` flag (repeated) lets `init.sh` install into multiple
  shell configs in one run: `init.sh -s bash -s zsh`.
