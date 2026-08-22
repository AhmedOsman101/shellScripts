# Batch Review: 01 of TBD (pilot batch)

**Scripts in this batch:** `log-debug`, `log-info`, `log-success`, `log-warning`, `log-error`, `log.sh`, `load-fonts`, `ls-colors` (8 scripts)
**Batch composition:** name-family (`log-*` family + dispatcher `log.sh`) plus 2 unrelated fillers (`load-fonts`, `ls-colors`) to fill line budget — not a pure directory group, the 6 log-related scripts share a real pattern, the last 2 are grab-bag fillers.
**Reviewer:** subagent-01
**Date:** 2026-08-21

---

## House Style Reference (do not flag these as bugs)

Before reviewing, confirm you've internalized these repo conventions. Restate them here in one line each to prove the context loaded correctly:

- Dependency declaration format (`# - binary | binary2 (pkg-override)`) and how `checkDep` resolves it: deps live between `# --- DEPENDENCIES --- #` and `# --- END SIGNATURE --- #` as `# - exe | alt (pkg)`; `checkDep` splits on `|` then `Trim`s, takes first word per alternative and `command -v` checks each in order — if any found returns 0 satisfied, else echoes `pkg` from `(parens)` or bare exe for `installDep`.
- Logging convention: `log-*` wrapper scripts are primary, camelCase `log*` functions in `lib/helpers.sh` are fallback: standalone `log-debug`/`log-info`/`log-warning`/`log-error`/`log-success` + dispatcher `log.sh` are the canonical CLI entry points (they call `colorOnlyPrefix` via `LEVEL_COLORS`); `lib/helpers.sh` camelCase `logDebug`/`logSuccess`/etc. and `lib/loggers.sh` `printRed`/`printGreen` are in-process fallback, not dead code.
- `trap 'exit 1' SIGUSR1` + `kill -SIGUSR1 "${PPID}"` propagation chain purpose: every script traps SIGUSR1 to `exit 1`; only `log-error` sends `kill -SIGUSR1 "${PPID}"` (guarded by `! isInteractiveShell && ! noKill`) to kill its parent without explicit exit-code checks, with `|| true` and `wait` suppression.
- `cmdarg.sh` argument-parsing pattern used across scripts: `source "$(include "lib/cmdarg.sh")"` then `cmdarg_info "header" "$(get-desc "$0")"`; pre-declare `declare -a arr`/`declare -A hash` for `[]`/`{}` types; `cmdarg "v"` boolean defaults `"false"`/literal `true`, `"m:"` required string, `"o?"` optional string, `"a?[]"`/`"H?{}"` arrays/hashes; then `cmdarg_parse "$@"` and read `cmdarg_cfg`/`argv`/`argc`; `-h`/`--help` reserved.
- `get-desc` / `get-deps` signature-block parsing rules: both parse `# --- DESCRIPTION --- #` … `# --- DEPENDENCIES --- #` … `# --- END SIGNATURE --- #` via `sed`; missing DESCRIPTION or DEPENDENCIES block is allowed (prints `x-none` / empty), `get-desc` terminates on either DEPENDENCIES or END SIGNATURE, `get-deps` via `replace.sh` + `grep -v " --- "`.
- `init.sh` / `hooks/path.sh` symlink and PATH-registration workflow: `init.sh` verifies `SCRIPTS_DIR` (`~/scripts`), ensures `fd` (prompt symlink `fdfind->fd`), checks `hooks/path.sh`, idempotently appends `[[ -s "${SCRIPTS_DIR}/hooks/path.sh" ]] && source ...` to `~/.bashrc`/`.zshrc`; `hooks/path.sh` (sourced at shell startup) caches `fd --strip-cwd-prefix=always --no-ignore-vcs -t x . --exclude ...` to `/tmp/path-hook.cache`, rescans only when `find ... -newer cache`, adds each executable's dir once to `PATH` via `:...:` guard, then unsets temps.
- Reference pattern from `clangc` (what "correct" looks like in this repo): `set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `source "$(include "lib/cmdarg.sh")"` + `source "$(include "lib/compile.sh")"` + `source "$(include "check-deps")"` + `checkDeps "$0"` in order; `cmdarg_info`/`declare -a compiler_args`/`cmdarg "c"`/`"o?"`/`"a?[]"`/`"q"`/`cmdarg_parse "$@"`; literal `cmdarg_cfg` reads, `((argc <1)) && log-error`, array-safe `compile_and_run` with namerefs.

---

## Script Reviews

### `log-debug`

**Path:** `/home/othman/scripts/log-debug`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Prints debug messages in magenta with a '[DEBUG] ' prefix; reads from stdin or arguments
**Declared dependencies:** none (empty block)
**Verdict:** `Clean`

#### Critical bugs

None found.

#### Design issues

None found.

#### Minor / style

None found. — `if [[ "$1" =~ ^-n$ ]]; then shift || true` matches `log.sh` dispatcher contract; `|| true` correctly suppresses `shift` failure under `set -e`.

#### Confirmed correct (potential false positives)

- `source "$(include "lib/helpers.sh")"` + `source "$(include "check-deps")"` + `checkDeps "$0"` indirection via `include` + `realpath -m` is intentional house-style path resolution, not fragile.
- Delegating to `log.sh "DEBUG"` instead of calling `logDebug` directly is the canonical primary logging interface; camelCase fallback in `lib/helpers.sh` is not dead code.
- `set -eo pipefail` + `trap 'exit 1' SIGUSR1` present — correct even though this leaf script never sends SIGUSR1 itself (only `log-error` does).

---

### `log-info`

**Path:** `/home/othman/scripts/log-info`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Prints info messages in purple with a '[SUCCESS] ' prefix; reads from stdin or arguments
**Declared dependencies:** none (empty block)
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **What happens:** script omits `set -eo pipefail` and `trap 'exit 1' SIGUSR1` that every other `log-*` wrapper includes; failures in `log.sh` or `input` will not abort and SIGUSR1 from a child `log-error` would not be trapped if this script were the parent.
- **Where:**

```bash
source "$(include "lib/helpers.sh")"
source "$(include "check-deps")"

checkDeps "$0"
# ---  Main script logic --- #
if [[ "$1" =~ ^-n$ ]]; then
```

- **Why it's wrong:** diverges from invariant described in `house-style-brief.md` §4 (`Every script starts with set -eo pipefail and trap 'exit 1' SIGUSR1`) and from `clangc` reference pattern; `log-debug`/`log-success`/`log-warning`/`log-error` all include it.
- **Fix:**

```bash
set -eo pipefail
trap 'exit 1' SIGUSR1

source "$(include "lib/helpers.sh")"
source "$(include "check-deps")"
```

#### Minor / style

- Description block says `'[SUCCESS] '` purple prefix but script correctly dispatches `log.sh "INFO"` which prints `[INFO]` in purple via `printPurple` — doc typo, runtime is correct. Fix description to `'[INFO] '`.

#### Confirmed correct (potential false positives)

- Same `include` indirection and `log.sh` delegation as `log-debug` — not a bug.
- Empty DEPENDENCIES block is allowed (`get-deps` returns `x-none`, `checkDeps` returns 0) — not missing deps.

---

### `log-success`

**Path:** `/home/othman/scripts/log-success`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Prints success messages in green with a '[SUCCESS] ' prefix; reads from stdin or arguments
**Declared dependencies:** none (empty block)
**Verdict:** `Clean`

#### Critical bugs

None found.

#### Design issues

None found.

#### Minor / style

None found.

#### Confirmed correct (potential false positives)

- `set -eo pipefail` + `trap 'exit 1' SIGUSR1` present, correctly paired with `log-error` kill chain (this script never sends SIGUSR1 itself, trap is for when it is the parent).
- `log.sh "SUCCESS" -n "$(input "$@")"` / `log.sh "SUCCESS" "$(input "$@")"` correctly maps to `LEVEL_COLORS[SUCCESS]=printGreen` and `LEVEL_OUTPUT[SUCCESS]=1` (stdout) in `log.sh:29-34`.

---

### `log-warning`

**Path:** `/home/othman/scripts/log-warning`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Prints warning messages in yellow with a '[WARNING] ' prefix; reads from stdin or arguments
**Declared dependencies:** `tput`
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **What happens:** declares `# - tput` but neither this script nor `log.sh`/`lib/helpers.sh`/`lib/loggers.sh` ever calls `tput`; logging uses `printer`/`stylePrint` with hardcoded `\e[...m` ANSI escapes and `supportsColor` (`NO_COLOR`/`CI`/TTY/`TERM`), not `tput`.
- **Where:**

```bash
# --- DEPENDENCIES --- #
# - tput
# --- END SIGNATURE --- #
```

- **Why it's wrong:** stale dep causes `checkDep` to attempt `tput` package install check on every invocation; not a runtime failure but drifts from actual dependency set (should be none, like other `log-*` wrappers).
- **Fix:**

```bash
# --- DEPENDENCIES --- #
#
# --- END SIGNATURE --- #
```

(remove the `tput` line; if truly needed, keep but add `tput` call).

#### Minor / style

None found.

#### Confirmed correct (potential false positives)

- `set -eo pipefail` + `trap` + `include` + `checkDeps` shape matches `clangc` reference — not boilerplate to remove.
- Delegation to `log.sh "WARNING"` (yellow, fd 2 via `LEVEL_OUTPUT[WARNING]=2`) is correct primary interface; not a duplicate of `logWarning` in helpers.

---

### `log-error`

**Path:** `/home/othman/scripts/log-error`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Prints error messages in red with a '[ERROR] ' prefix to stderr, signals parent with SIGUSR1, and exits with failure
**Declared dependencies:** none (empty block)
**Verdict:** `Clean`

#### Critical bugs

None found.

#### Design issues

None found.

#### Minor / style

None found. — flag parsing `while ((0 < $#)); do case "$1" in --no-kill|--no-error|--safe|-n) ...` correctly breaks on first non-flag via `*) break ;;`; `input "$@"` after flag stripping is correct.

#### Confirmed correct (potential false positives)

- `kill -SIGUSR1 "${PPID}" &>/dev/null || true; wait "${PPID}" &>/dev/null || true` guarded by `! { isInteractiveShell || "${noKill:-false}"; }` is the intentional propagation chain from `house-style-brief.md` §4, not leftover debug; `wait` on PPID always fails but is suppressed — deliberate.
- `--no-kill`/`--no-error`/`--safe` (`--safe` = both) and `-n` handling exactly matches brief's description of `log-error`'s exclusive kill behavior; other `log-*` scripts correctly omit this kill logic.
- `trap 'exit 1' SIGUSR1` is required even though this script is the sender — trap is for when it is itself waited on.

---

### `log.sh`

**Path:** `/home/othman/scripts/log.sh`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Unified logger for CLI apps, Supports stdin or arguments
**Declared dependencies:** none (empty block)
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **What happens:** unknown `LEVEL` (e.g. typo `log.sh "INF0"`) silently falls back to `printPurple`/`fd 1` via `${LEVEL_COLORS[${LEVEL}]:-printPurple}` and `${LEVEL_OUTPUT[${LEVEL}]:-1}` and prints `[INF0]` — error hidden.
- **Where:**

```bash
COLOR_FUNC="${LEVEL_COLORS[${LEVEL}]:-printPurple}"
OUTPUT_FD="${LEVEL_OUTPUT[${LEVEL}]:-1}"
```

- **Why it's wrong:** dispatcher never validates LEVEL against known keys `DEBUG|INFO|SUCCESS|WARNING|ERROR`; contract violation is silent, not loud.
- **Fix:** optional — add explicit validate: `[[ -v LEVEL_COLORS[${LEVEL}] ]] || { log.sh "ERROR" "unknown level ${LEVEL}" 2>&1; exit 1; }` or keep silent fallback but document it. Low severity; keep as design note, not critical.

#### Minor / style

- `isNewLine` is used via `${isNewLine:-true}` without prior declaration; works but relies on parameter expansion default. Could `declare isNewLine=true` before parse for clarity. Not a bug under `set -e` (no `set -u`).

#### Confirmed correct (potential false positives)

- `set -eo pipefail` + `trap` + `source "$(include "lib/helpers.sh")"` + `checkDeps` order matches `clangc` reference.
- `LEVEL="${1:-INFO}"; shift || true` with `|| true` suppresses `shift` failure on zero args under `set -e` — intentional.
- `if [[ "$1" =~ ^-n$ ]]; then isNewLine=false; shift` + `colorOnlyPrefix [-n] "${COLOR_FUNC}" "${LEVEL}" "${message}" "${OUTPUT_FD}"` correctly implements the `-n` (no newline) contract used by wrappers; `colorOnlyPrefix` handling of `-n` and `fd` is canonical.

---

### `load-fonts`

**Path:** `/home/othman/scripts/load-fonts`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Moves TTF and OTF fonts from ~/fonts to system font directories and refreshes the font cache
**Declared dependencies:** `fd | fdfind (fd-find)` , `gum`
**Verdict:** `Needs fixes`

#### Critical bugs

- **What happens:** when `~/fonts` contains multiple subdirectories each with fonts, only the first directory is moved; remaining directories are silently skipped and final `log-success "Fonts reloaded succefully!"` still prints success.
- **Where:**

```bash
mapfile -t ttfDirs < <(fd.sh . -e ttf "${dir}" -x dirname {} | no-dups -a)
if ((${#ttfDirs} > 0)); then
  sudo mv "${ttfDirs[@]}" -t "${ttfDir}" && log-info "Moved ${ttfDirs[*]}"
  continue # to avoid searching again
fi

mapfile -t otfDirs < <(fd.sh . -e otf "${dir}" -x dirname {} | no-dups -a)
```

- **Why it's wrong:** `no-dups -a` (`no-dups:47-48`) runs `tr ' ' '\n' | awk '!seen[$0]++' | paste -sd " "` which joins newline-separated dirnames with spaces into a single line; `mapfile -t` then reads that single line as one array element (`"dir1 dir2"`). `"${ttfDirs[@]}"` expands to one word containing a space, not two separate paths, so `mv -t` receives an invalid single path and fails. Without `-a`, `no-dups` keeps newline separation and `mapfile` correctly produces one element per dir. Reproducible: `printf "a/b\nc/d\n" | tr ' ' '\n' | awk '!seen[$0]++' | paste -sd " "` -> `a/b c/d` -> `mapfile` len 1 vs `awk '!seen[$0]++'` -> `mapfile` len 2.
- **Fix:** drop `-a` so `mapfile` gets newline-separated entries:

```bash
mapfile -t ttfDirs < <(fd.sh . -e ttf "${dir}" -x dirname {} | no-dups)
# and similarly:
mapfile -t otfDirs < <(fd.sh . -e otf "${dir}" -x dirname {} | no-dups)
```

Alternatively keep `-a` but read via `read -ra`/`eval`, but removing `-a` is the minimal fix.

#### Design issues

- **What happens:** `continue` after successful `ttfDirs` move skips OTF check in same dir; a directory containing both `*.ttf` and `*.otf` will have its OTF files ignored.
- **Where:**

```bash
if ((${#ttfDirs} > 0)); then
  sudo mv "${ttfDirs[@]}" -t "${ttfDir}" && log-info "Moved ${ttfDirs[*]}"
  continue # to avoid searching again
fi
```

- **Why it's wrong:** undocumented assumption that a dir contains only one font type; mixed dirs lose OTF files silently. Either document the assumption or remove `continue` and always check both.
- **Fix:** remove `continue` or gate on whether OTF also present; at minimum document behavior in DESCRIPTION.

- **What happens:** `fd.sh` hardcodes `/usr/bin/fd` (`fd.sh:21-22`) while DEPENDENCIES declares `fd | fdfind (fd-find)` fallback; on Debian systems where binary is `fdfind` and `init.sh` symlink was declined, `fd.sh` fails even though `checkDep` would have considered `fdfind` sufficient.
- **Where:** `fd.sh:21: '/usr/bin/fd'` vs `load-fonts:17: # - fd | fdfind (fd-find)`
- **Why it's wrong:** pipe fallback in deps is correct per brief §2, but `fd.sh` wrapper doesn't honor it — distro-specific fragility. House-style says `fd|fdfind` pipe is not a bug in the declaration, but the wrapper's hardcoded path is a design gap.
- **Fix:** in `fd.sh`, resolve `fd` via `command -v fd || command -v fdfind` instead of hardcoded `/usr/bin/fd`, or document that `init.sh` must create symlink.

#### Minor / style

- Typo in final success message: `log-success "Fonts reloaded succefully!"` -> `successfully`.
- `sudo mv -i ./*.ttf "${ttfDir}" &>/dev/null || true` — with `nullglob` off, empty glob expands to literal `*.ttf`; `|| true` suppresses `set -e` exit but also hides real `mv` errors. Works as intended (move if exists) but consider `shopt -s nullglob` or `compgen -G "*.ttf"` guard for clarity. Not critical.
- `declare -a dirs ttfDirs otfDirs` after `cd` is fine; reusing `ttfDirs`/`otfDirs` with `mapfile` overwrites prior values, but `otfDirs` persists from prior loop iteration if `continue` taken — minor, add `otfDirs=()` reset if `continue` kept.

#### Confirmed correct (potential false positives)

- `# - fd | fdfind (fd-find)` pipe + parens is correct per `house-style-brief.md` §2 — not a syntax error; `checkDep` correctly handles fallback via `awk -F "|"`.
- `cd "${HOME}/fonts" || log-error "failed to find '${HOME}/fonts' directory, create it first."` correctly uses `log-error` kill chain; `checkDeps "$0"` before `cmdarg_parse` matches `clangc` reference.
- `gum spin --title "Caching fonts..." -- sudo fc-cache -r` is correct `gum` usage; `gum` decl in DEPENDENCIES is not stale.
- `fd.sh . -t d -d 1` + `--exclude` behavior via `fd.sh` wrapper is intentional PORTABILITY layer, not a redundant wrapper.

---

### `ls-colors`

**Path:** `/home/othman/scripts/ls-colors`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Parses exported color variables from a Zsh config and displays their names with the corresponding color
**Declared dependencies:** `rg (ripgrep)` , `awk` , `tr`
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **What happens:** sourcing relies on `check-deps` to transitively load `lib/helpers.sh` (which loads `lib/loggers.sh` for `printHex`); if `check-deps` ever stops sourcing helpers, `ls-colors` breaks. Direct `source "$(include "lib/helpers.sh")"` would match `clangc`/`log.sh` pattern.
- **Where:**

```bash
source "$(include "lib/cmdarg.sh")"
source "$(include "check-deps")"

checkDeps "$0"
cmdarg_info "header" "$(get-desc "$0")"
```

(missing `source "$(include "lib/helpers.sh")"`)

- **Why it's wrong:** fragile indirection; `log.sh` and `clangc` explicitly source helpers after `include`; `ls-colors` should too since it calls `printHex`.
- **Fix:**

```bash
source "$(include "lib/helpers.sh")"
source "$(include "lib/cmdarg.sh")"
source "$(include "check-deps")"
```

- **What happens:** `cut -d' ' -f2- "${ZDOTDIR}/variables.sh"` assumes each relevant line starts with `export ` (space present); lines like `U_RED="#ff0000"` without `export` yield empty via `-f2-`, silently dropping colors.
- **Where:**

```bash
if [[ -f "${ZDOTDIR}/variables.sh" ]]; then
  cut -d' ' -f2- "${ZDOTDIR}/variables.sh" | tr -d '"'
fi
```

- **Why it's wrong:** `variables.sh` format not guaranteed; dropping non-export lines loses colors without error.
- **Fix:** more robust: `grep -oE 'U_[A-Za-z0-9_]*=.*' "${ZDOTDIR}/variables.sh" | tr -d '"'` or `sed -n 's/.*$U_[^=]*=.*$/\1/p'`. Low severity if file always uses `export`.

#### Minor / style

- Dependencies list `awk`/`tr` which per `AGENTS.md` are considered coreutils/basic commands normally excluded; listing them is harmless but noisy. `cut`/`printenv` (also coreutils) are correctly omitted. Keep or drop `awk`/`tr` — not a bug.
- `findColors()` returns 0 unconditionally (`return 0`) even if both sources empty — fine, `mapfile` gets empty array and loop is no-op.

#### Confirmed correct (potential false positives)

- `source "$(include "lib/cmdarg.sh")"` + `cmdarg_info` + `cmdarg_parse "$@"` with zero declared flags is correct — `cmdarg` gracefully handles no options (only `-h`/`--help` reserved); not missing args.
- `# - rg (ripgrep)` with package override parens is correct `checkDep` syntax from brief §2; pipe not needed here but parens are valid.
- `{ ...; printenv; } | no-dups | rg --color=never '^U_'` correctly deduplicates before filtering; `no-dups` without `-a` keeps newline separation for `mapfile -t colors`, unlike `load-fonts`'s buggy `-a` usage — this one is correct.
- `printHex "${color}" "${varname} ${color}"` correctly calls `printHex` -> `hex_to_rgb` -> `printRGB` with `supportsColor` guard (`NO_COLOR`/`CI`/TTY/`TERM`).

---

## Batch Summary

- **Scripts reviewed:** 8 / 8
- **Critical bugs:** `load-fonts` — `no-dups -a` + `mapfile -t` single-element array bug causes silent `mv` failure when multiple subdirs contain fonts (see load-fonts Critical bugs); also `continue` skips OTF in mixed dirs.
- **Design issues worth escalating:** `log-info` missing `set -eo pipefail`/`trap 'exit 1' SIGUSR1` (invariant violation); `log-warning` stale `tput` dep; `ls-colors` fragile transitive `helpers` sourcing via `check-deps`; `load-fonts` hardcoded `/usr/bin/fd` in `fd.sh` breaks `fd|fdfind` fallback if symlink not created; `log.sh` silent fallback on unknown LEVEL.
- **Cross-cutting patterns observed in this batch** (same bug/pattern repeated across multiple scripts in this batch only; batch-level, not repo-wide):
  - `log-*` wrappers duplicate identical `-n` flag handling (`if [[ "$1" =~ ^-n$ ]]; then shift || true; log.sh LEVEL -n ...`) — consistent and intentional, but any future `-n` contract change must be updated in 5 places; consider consolidating via helper in `lib/helpers.sh` if batch grows.
  - Two scripts (`load-fonts` and `ls-colors`) use `fd.sh` + `no-dups` pipeline but with opposite `-a` usage — `load-fonts` misuses `-a` with `mapfile` (bug), `ls-colors` correctly omits `-a`; pattern confusion worth documenting in `no-dups` help.
  - `log-warning` and `ls-colors` both declare dependencies that are technically coreutils-adjacent (`tput` unused, `awk`/`tr` listed but normally excluded per `AGENTS.md`) — shows inconsistent dep-declaration granularity within batch.
- **Open questions** (design intent unclear, needs the repo owner's input rather than a guess):
  - Is `load-fonts`'s `continue` after TTF move (skipping OTF in same dir) intentional single-type-per-dir assumption, or should it move both types? Current DESCRIPTION doesn't state.
  - Should `fd.sh` honor `fdfind` fallback (via `command -v fd || command -v fdfind`) or is the `init.sh` symlink creation (`/usr/bin/fd -> $(command -v fdfind)`) considered mandatory, making fallback in `load-fonts` DEPENDENCIES purely for `checkDep` install prompt?
  - `ls-colors`'s `cut -d' ' -f2-` assumes `export U_...` prefix — is `variables.sh` guaranteed to export, or should parser handle bare `U_...=` lines?
  - Batch expects `log.sh` LEVEL validation — should unknown LEVEL be a loud error (fail) or silent purple fallback (current)? Current fallback is ergonomic for ad-hoc `log.sh "CUSTOM"` but hides typos.

---

## Evidence Appendix (optional)

- House style brief: `/home/othman/scripts/docs/code-reviews/house-style-brief.md:1-68`
- Core files read: `include:1-26`, `lib/cmdarg.sh:1-462`, `lib/loggers.sh:1-341`, `lib/helpers.sh:1-420`, `check-deps:1-175`, `log.sh:1-64`, `get-desc:1-53`, `get-deps:1-39`, `init.sh:1-158`, `hooks/path.sh:1-86`, `clangc:1-67`
- Batch scripts read: `log-debug:1-33`, `log-info:1-30`, `log-success:1-33`, `log-warning:1-33`, `log-error:1-67`, `log.sh:1-64`, `load-fonts:1-60`, `ls-colors:1-50`
- Supporting reads: `fd.sh:1-43`, `no-dups:1-82`, `replace.sh:1-81`
- Key reproducer for load-fonts bug: `printf "a/b\nc/d\n" | tr ' ' '\n' | awk '!seen[$0]++' | paste -sd " " | od -c` -> single line vs `awk '!seen[$0]++'` -> newline separation; `mapfile -t arr < <(paste...)` len 1 with space vs `mapfile` len 2 without `-a`.
