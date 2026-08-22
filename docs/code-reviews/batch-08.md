# Batch Review: 08 of 22

**Scripts in this batch:** ts-starter (220), get-distro (31), fd-by-depth (31), collapseTilde (32)
**Batch composition:** large+fillers — pairing incidental, cap 4, budget 314. ts-starter is the large tool; get-distro, fd-by-depth, collapseTilde are small unrelated fillers packed to fill the line budget, not a name-family or directory group. No shared pattern to infer.
**Reviewer:** subagent-08
**Date:** 2026-08-21

---

## House Style Reference (do not flag these as bugs)

Before reviewing, confirm you've internalized these repo conventions. Restate them here in one line each to prove the context loaded correctly:

- Dependency declaration format (`# - binary | binary2 (pkg-override)`) and how `checkDep` resolves it: one line per dep as `# - exe | alt (pkg)`, split on `|`, `Trim`, `awk '{print $1}'`, `command -v` each alt in order — any found means satisfied, else echo `pkgName` (parens override) or first `exeName` for install.
- Logging convention: `log-*` wrapper scripts are primary, camelCase `log*` functions in `lib/helpers.sh` are fallback: `log.sh` dispatches LEVEL→color via LEVEL_COLORS/LEVEL_OUTPUT + `colorOnlyPrefix`; `lib/helpers.sh` `logDebug/logSuccess/...` are in-process fallback, not dead code.
- `trap 'exit 1' SIGUSR1` + `kill -SIGUSR1 "${PPID}"` propagation chain purpose: every script traps SIGUSR1 to exit 1; only `log-error` kills PPID (guarded by `! isInteractiveShell && ! noKill`) to bubble fatal errors without caller checking exit codes.
- `cmdarg.sh` argument-parsing pattern used across scripts: `source "$(include "lib/cmdarg.sh")"` → `cmdarg_info` → pre-declare `[]/{}` vars → `cmdarg "x:"/"x?"` etc. → `cmdarg_parse "$@"` → read `cmdarg_cfg[]`/`argv[]`/`argc`; booleans are literal `true`/`false`, `-h/--help` reserved, `CMDARG_ERROR_BEHAVIOR=return`.
- `get-desc` / `get-deps` signature-block parsing rules: both parse `# --- DESCRIPTION/DEPENDENCIES ---` → `# --- END SIGNATURE ---`; `get-desc` sed loop to next marker, `get-deps` `sed -n '/DEPENDENCIES/,/END/{/# - /p}'`; missing block allowed, prints `x-none`, not a bug.
- `init.sh` / `hooks/path.sh` symlink and PATH-registration workflow: `init.sh` verifies `SCRIPTS_DIR`, ensures `fd` (or symlink `fdfind→fd`), idempotently appends `source hooks/path.sh` to bashrc/zshrc; `hooks/path.sh` is sourced at shell start, caches `fd --strip-cwd-prefix -t x` to `/tmp/path-hook.cache`, adds each exe dir to PATH once.
- Reference pattern from `clangc` (what "correct" looks like in this repo): `set -eo pipefail` + `trap` + `source cmdarg` + `source compile` + `source check-deps` + `checkDeps "$0"` → `cmdarg_info "$(get-desc "$0")"` → `declare -a compiler_args` → `cmdarg` booleans/optionals/arrays → `cmdarg_parse "$@"` → read `cmdarg_cfg`, validate `((argc <1)) && log-error`, arrays with namerefs to `compile_and_run`.

---

## Script Reviews

### `ts-starter`

**Path:** `/home/othman/scripts/ts-starter`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Starter kit for typescript projects with formatter, editorconfig, and pre-commit hooks — bootstrap typescript projects quickly, installs biome, husky, and editorconfig
**Declared dependencies:** `pnpm | bun | npm | deno | yarn`, `gum`, `wget | curl`, `jq`, `sponge (moreutils)`
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **What happens:** Positionals tested via raw `$1` instead of `argc`/`argv`, then rebuilt via `argv[*]` — diverges from cmdarg contract (`cmdarg_parse "$@"` leaves caller `$@` unchanged; `argv` holds positionals). Works when no flags, but fragile when flags are used.
- **Where:**
```bash
if [[ -n $1 ]]; then
  cmd="${argv[*]}"
else
  cmd="$(gum input --placeholder="Enter your starter command...")"
fi
```
- **Why it's wrong:** Mixes two namespaces; `[[ -n $1 ]]` tests caller `$1` (could be `-b`), not whether a positional remains. `argv[*]` reconstruction via `[*]` joins with IFS space and re-parsed by `bash -c` later, losing original quoting.
- **Fix:**
```bash
if ((argc > 0)); then
  cmd="${argv[*]}"
else
  cmd="$(gum input --placeholder="Enter your starter command...")"
fi
# consider: printf -v cmd '%q ' "${argv[@]}" for shell-quoted reconstruction, or keep as array and avoid bash -c
```

- **What happens:** `addScripts`/`addTasks` assume `package.json`/`deno.json` exists and is valid JSON; `jq ... | sponge` under `set -eo pipefail` aborts with opaque `jq` error if file missing or malformed.
- **Where:**
```bash
jq '.scripts += {
  "lint": "unset BIOME_CONFIG_PATH; biome lint .",
...
}' package.json | sponge package.json
```
- **Why it's wrong:** Bootstrap `bash -c "${cmd}"` may fail to create the file (or user aborted), then script crashes mid-way with no actionable message.
- **Fix:**
```bash
[[ -f package.json ]] || log-error "package.json not found after bootstrap: ${cmd}"
jq '.scripts += {...}' package.json | sponge package.json || log-error "Failed to patch package.json"
```
Same guard for `addTasks`.

- **What happens:** `bash -c "${cmd}"` re-parses a joined string; errors from `wget`/`curl` hidden by `2>/dev/null`, and `is-git-repo --safe` is invoked 6 times instead of caching result.
- **Where:**
```bash
bash -c "${cmd}" || log-error "Bootstrap command failed: ${cmd}"
# and fetch():
if ! wget -T 30 -t 5 -q -O "${dest}" "${url}" 2>/dev/null; then
```
- **Why it's wrong:** Not a correctness bug — intentional to hide curl noise — but loses root-cause diagnostics; repeated git checks are wasteful.
- **Fix:** Keep `2>/dev/null` if desired, but consider logging URL on failure (already does) and caching `isGitRepo` in a variable.

#### Minor / style

- `[[ -n $1 ]]` unquoted; prefer `[[ -n ${1:-} ]]` or `((argc))`. `cmd="${argv[*]}"` correctly quoted for join but comment should note intent.
- `rm '.husky/pre-commit' &>/dev/null || true` uses single quotes for filename — fine, but consistent style is `rm -f .husky/pre-commit &>/dev/null || true`.
- Repeated `safeFetchRaw`/`safeFetchGist` wrappers are almost identical — could factor to one, but duplication is small enough to keep.

#### Confirmed correct (potential false positives)

- `source "$(include "lib/helpers.sh")"` / `lib/diff-handler.sh` / `lib/cmdarg.sh` / `check-deps` indirection via `include` with `realpath -m` — house style, not fragile.
- `set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `checkDeps "$0"` + `cmdarg_info "$(get-desc "$0")"` ordering matches `clangc` reference.
- `cmdarg "b?" "biome-version" "Biome version to install" "${BIOME_VERSION:-2.3.0}"` — optional string with default via env fallback, correct per `cmdarg` `?` semantics; key `biome-version` with hyphen maps to `cmdarg_cfg['biome-version']` and `--biome-version` (allowed by `--[a-zA-Z0-9_\-]+`).
- Dependency line `pnpm | bun | npm | deno | yarn` and `wget | curl`, `sponge (moreutils)`, `fd | fdfind (fd-find)`-style alternatives — pipe is OR, parens is pkg override, per `checkDep` semantics; `checkDeps` correctly short-circuits when any alt is found.
- `log-error` / `log-warning` / `log-info` as external commands (not `logError` camelCase) — primary interface per logging two-layer design.
- `handleExistingFile` from `lib/diff-handler.sh` with `gum choose` fallback to `select` — intentional per that library.
- `case "${pkgMgr}"` extracting via `echo "${cmd}" | awk '{print $1}'` — tolerates `pnpm`/`npm`/etc. extracted string then `command -v` check.

---

### `get-distro`

**Path:** `/home/othman/scripts/get-distro`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Prints the distro's pretty name from `/etc/os-release`.
**Declared dependencies:** none (empty `# --- DEPENDENCIES --- #` block → `x-none`)
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **What happens:** Sources `/etc/os-release` without existence check; if file missing, `source` fails and `set -e` exits with no context.
- **Where:**
```bash
source "/etc/os-release"
echo "${PRETTY_NAME}"
```
- **Why it's wrong:** House style in `lib/helpers.sh:getPackageManager` guards with `[[ -f '/etc/os-release' ]] || logError ...`; `get-distro` skips that guard. Containers/minimal images may lack the file.
- **Fix:**
```bash
[[ -f /etc/os-release ]] || log-error "/etc/os-release not found"
source "/etc/os-release"
echo "${PRETTY_NAME:-${NAME:-${ID:-unknown}}}"
```

- **What happens:** Echoes `${PRETTY_NAME}` with no fallback if variable unset (malformed os-release).
- **Where:**
```bash
echo "${PRETTY_NAME}"
```
- **Why it's wrong:** Prints blank line instead of useful identifier.
- **Fix:** As above, fallback chain `PRETTY_NAME → NAME → ID`.

#### Minor / style

- Missing quotes not an issue (`echo "${PRETTY_NAME}"` is quoted), but could use `printf '%s\n' "${PRETTY_NAME}"` to avoid interpreting leading `-`.

#### Confirmed correct (potential false positives)

- `set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `source "$(include "lib/cmdarg.sh")"` + `source "$(include "check-deps")"` + `checkDeps "$0"` + `cmdarg_info "$(get-desc "$0")"` + `cmdarg_parse "$@"` with no user flags — minimal `cmdarg` usage is allowed per house style; `checkDeps` returns 0 when `getDeps` prints `x-none`.
- Sourcing `/etc/os-release` and reading `PRETTY_NAME` is canonical for distro pretty name; not a style violation.
- Empty dependency block (immediately closed) is allowed — `get-deps` returns `x-none`.

---

### `fd-by-depth`

**Path:** `/home/othman/scripts/fd-by-depth`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Wrapper script for fd which sorts results by depth
**Declared dependencies:** `fd | fdfind (fd-find)`
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **What happens:** Runtime calls `fd.sh` wrapper but dependency declares `fd | fdfind`. `fd.sh` hardcodes `/usr/bin/fd` (no `fdfind` fallback), so `checkDeps` can pass (fdfind exists) while runtime still fails if `/usr/bin/fd` symlink was never created by `init.sh`.
- **Where:**
```bash
fd.sh "$@" |
  awk -F/ '{ print NF, $0 }' |
```
- **Why it's wrong:** Declared deps and runtime binary diverge; `init.sh` normally symlinks `fdfind→fd`, but a fresh machine without running `init.sh` hits the gap.
- **Fix:** Either align dep to `fd.sh` + `fd | fdfind`, or make `fd.sh` itself handle `fdfind` fallback, or call `fd` with fallback logic here: `if command -v fd &>/dev/null; then fd ...; else fdfind ...; fi`.

- **What happens:** Depth sort uses space as delimiter (`cut -d' ' -f2-`) which can mangle filenames with spaces/consecutive spaces.
- **Where:**
```bash
awk -F/ '{ print NF, $0 }' |
  sort -n |
  cut -d' ' -f2-
```
- **Why it's wrong:** `awk '{print NF, $0}'` emits `count<space>path`; `cut -d' '` splits on single space. Filenames containing spaces still reconstruct (`-f2-` joins with delimiter) but consecutive spaces produce empty fields and fragile reconstruction; tabs are safer.
- **Fix:**
```bash
awk -F/ '{ print NF "\t" $0 }' | sort -n | cut -f2-
```

#### Minor / style

- Shebang + `set -eo pipefail` + `trap` correct; no `cmdarg` needed for pure pass-through — omitting `cmdarg` is allowed for wrappers.
- Could add `--` handling note, but `fd.sh "$@"` already forwards correctly.

#### Confirmed correct (potential false positives)

- Dependency line `fd | fdfind (fd-find)` with `(fd-find)` pkg override — correct per `checkDep` (pkg override extraction via `grep -oP '\(\K[^)]*(?=\))'`).
- `source "$(include "check-deps")"` + `checkDeps "$0"` before main logic — matches `clangc` ordering (minus `cmdarg` which is optional for wrappers).
- `trap 'exit 1' SIGUSR1` alone (without `kill`) is intentional — only `log-error` kills PPID per propagation chain.
- Using `fd.sh` (repo helper that hides `.git`/`node_modules` etc.) as the fd entrypoint is intentional; not a missing binary.

---

### `collapseTilde`

**Path:** `/home/othman/scripts/collapseTilde`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Collapse a tilde ~ into the full path for HOME directory
**Declared dependencies:** `sed`
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **What happens:** `sed` substitution interpolates `${HOME}` unescaped as regex; if `HOME` contains regex metachars the pattern misfires. Also `HOME` empty yields `s|^|~|` prefixing `~` to every line.
- **Where:**
```bash
sed "s|^${HOME}|~|" < <(input "$@")
```
- **Why it's wrong:** `HOME` is user-controlled path; `/home/user.name` would treat `.` as wildcard. Should escape regex and guard empty.
- **Fix:**
```bash
[[ -n ${HOME:-} ]] || log-error "HOME is unset"
# escape regex metachars for sed (minimal: escape & and delimiter)
homeEscaped=$(printf '%s' "$HOME" | sed 's/[&/\|]/\\&/g; s/[.[\*^$]/\\&/g')
sed "s|^${homeEscaped}|~|" < <(input "$@")
# or avoid sed: input "$@" | while IFS= read -r line; do printf '%s\n' "${line/#$HOME/~}"; done
```

- **What happens:** Uses `input "$@"` (caller `$@`) instead of `argv` after `cmdarg_parse`; works coincidentally because wrapper has no flags, but diverges from cmdarg contract (`argv` holds positionals).
- **Where:**
```bash
cmdarg_parse "$@"
sed "s|^${HOME}|~|" < <(input "$@")
```
- **Why it's wrong:** If flags were ever added or caller passes `--` sentinel, `"$@"` still contains raw args while `argv` is the parsed remainder. Documented pattern is to read from `argv`/`argc`.
- **Fix:**
```bash
sed "s|^${HOME}|~|" < <(input "${argv[@]}")
# or handle stdin vs arg cleanly: if ((argc)); then printf '%s\n' "${argv[@]}"; else cat; fi | sed ...
```

- **What happens:** Description is inverted: says “Collapse a tilde ~ into the full path” but code does the opposite (replaces `$HOME` with `~`).
- **Where:**
```bash
# --- DESCRIPTION --- #
# Collapse a tilde ~ into the full path for HOME directory
```
- **Why it's wrong:** Misleads `get-desc` consumers and help text.
- **Fix:** Change to `Replace \$HOME prefix with ~ for display` or `Collapse \$HOME to ~`.

#### Minor / style

- `shellcheck disable=2001` present to allow `sed` instead of `${var/#$HOME/~}` — acceptable; pure bash `${line/#$HOME/~}` would avoid sed fork but `sed` is already declared dep, keep as is if preferred.
- `< <(input "$@")` process substitution is overkill vs `input "$@" | sed ...`; not wrong, just extra FD.

#### Confirmed correct (potential false positives)

- `source "$(include "lib/cmdarg.sh")"` + `source "$(include "lib/helpers.sh")"` + `source "$(include "check-deps")"` + `checkDeps "$0"` + `cmdarg_info "$(get-desc "$0")"` + `cmdarg_parse "$@"` with no user flags — minimal cmdarg boilerplate is allowed (mirrors `clangc` reference minus flag defines).
- `# - sed` dependency — coreutils not declared, `sed` declared correctly; `Trim`/`input` from helpers not declared as deps (helpers are repo-internal).
- `input "$@"` handling of stdin (`[[ $# -eq 0 || $1 == "-" ]] && cat`) is intentional per `lib/helpers.sh`; supports both `collapseTilde "$path"` and `echo "$path" | collapseTilde`.
- `set -eo pipefail` + `trap 'exit 1' SIGUSR1` is canonical.

---

## Batch Summary

- **Scripts reviewed:** 4 / 4
- **Critical bugs:** none — no crashes or silent data loss in this batch.
- **Design issues worth escalating:** `ts-starter` — `argc` vs `$1` guard + `package.json` pre-check before `jq|sponge`; `fd-by-depth` — `fd.sh` vs `fd|fdfind` runtime gap and fragile space-delimited depth sort (`cut -d' ' -f2-` → `cut -f2-` with tab).
- **Cross-cutting patterns observed in this batch** (same bug/pattern repeated across multiple scripts in this batch only; batch-level, not repo-wide): (1) small wrappers `get-distro`/`fd-by-depth`/`collapseTilde` all correctly use minimal `cmdarg`/`checkDeps` boilerplate and `trap` — consistent with repo; (2) `get-distro` and `collapseTilde` both interpolate environment paths (`/etc/os-release`, `$HOME`) without empty-guard fallback; (3) `fd-by-depth` and `collapseTilde` both use fragile text delimiters (space for depth sort, unescaped `$HOME` in sed regex) where a tab or bash parameter expansion would be more robust.
- **Open questions** (design intent unclear, needs the repo owner's input rather than a guess): `ts-starter` — should `addScripts` fail loudly if `package.json` missing, or auto-create minimal `{"scripts":{}}`? Should `handleDeno` prefer deno-native husky setup over temporary `npm init -y`? `collapseTilde` — should it expand `~`→`$HOME` (as description says) or collapse `$HOME`→`~` (as code does) — which direction is canonical for its callers (e.g., `init.sh` uses it to display `~`)?

---

## Evidence appendix

- `lib/helpers.sh:21-32` `input()` reads stdin when `$# -eq 0` — supports `collapseTilde` pipe usage.
- `lib/diff-handler.sh:105-143` `handleExistingFile` with `gum choose` → `select` fallback — used by `ts-starter:safeFetchRaw`.
- `fd.sh:21-43` hardcodes `/usr/bin/fd` with `--hidden` + excludes — called by `fd-by-depth:28`.
- `is-git-repo:35-43` `log-error --no-kill` vs `log-error` branching on `--safe` — `ts-starter` uses `--safe` correctly to avoid SIGUSR1 kill.
- `check-deps:21-51` `checkDep` splits on `|` and checks `command -v` each alt — validates `pnpm | bun | npm | deno | yarn` and `wget | curl`.

