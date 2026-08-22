# Batch Review: 22 of 22

**Scripts in this batch:** `spinner.sh`, `repeat-it`, `replace.sh`, `kill-process`, `mk-gitignore`, `ocr`, `get-desc`, `which-cpp`, `is-git-repo`, `killwait` (10 scripts, 653 lines)
**Batch composition:** [small-grab] grab-bag — no single directory or name-family dominates; mix of spinner, repeat-it, kill-process, ocr forming a heterogeneous grab-bag under the 12-file cap.
**Reviewer:** subagent-22
**Date:** 2026-08-21

---

## House Style Reference (do not flag these as bugs)

Before reviewing, confirm you've internalized these repo conventions. Restate them here in one line each to prove the context loaded correctly:

- Dependency declaration format (`# - binary | binary2 (pkg-override)`) and how `checkDep` resolves it: deps live between `# --- DEPENDENCIES --- #` and `# --- END SIGNATURE --- #` as `# - exe | alt (pkg)`; `checkDep` splits on `|` then `Trim`s, takes first word per alternative and `command -v` checks each in order — if any found returns 0 satisfied, else echoes pkg from `(parens)` or bare exe for `installDep`.
- Logging convention: `log-*` wrapper scripts are primary, camelCase `log*` functions in `lib/helpers.sh` are fallback: standalone `log-debug`/`log-info`/`log-warning`/`log-error`/`log-success` + dispatcher `log.sh` are the canonical CLI entry points (they call `colorOnlyPrefix` via `LEVEL_COLORS`); `lib/helpers.sh` camelCase `logDebug`/`logSuccess` etc. and `lib/loggers.sh` `printRed`/`printGreen` are in-process fallback, not dead code.
- `trap 'exit 1' SIGUSR1` + `kill -SIGUSR1 "${PPID}"` propagation chain purpose: every script traps SIGUSR1 to `exit 1`; only `log-error` sends `kill -SIGUSR1 "${PPID}"` (guarded by `! isInteractiveShell && ! noKill`) to kill its parent without explicit exit-code checks, with `|| true` and `wait` suppression.
- `cmdarg.sh` argument-parsing pattern used across scripts: `source "$(include "lib/cmdarg.sh")"` then `cmdarg_info "header" "$(get-desc "$0")"`; pre-declare `declare -a arr`/`declare -A hash` for `[]`/`{}` types; `cmdarg "v"` boolean defaults `"false"`/literal `true`, `"m:"` required string, `"o?"` optional string, `"a?[]"`/`"H?{}"` arrays/hashes; then `cmdarg_parse "$@"` and read `cmdarg_cfg`/`argv`/`argc`; `-h`/`--help` reserved.
- `get-desc` / `get-deps` signature-block parsing rules: both parse `# --- DESCRIPTION --- #` … `# --- DEPENDENCIES --- #` … `# --- END SIGNATURE --- #` via `sed`; missing DESCRIPTION or DEPENDENCIES block is allowed (prints `x-none` / empty), `get-desc` terminates on either DEPENDENCIES or END SIGNATURE, `get-deps` via `replace.sh` + `grep -v " --- "`.
- `init.sh` / `hooks/path.sh` symlink and PATH-registration workflow: `init.sh` verifies `SCRIPTS_DIR` (`~/scripts`), ensures `fd` (prompt symlink `fdfind->fd`), checks `hooks/path.sh`, idempotently appends `[[ -s "${SCRIPTS_DIR}/hooks/path.sh" ]] && source ...` to `~/.bashrc`/`.zshrc`; `hooks/path.sh` (sourced at shell startup) caches `fd --strip-cwd-prefix=always --no-ignore-vcs -t x . --exclude ...` to `/tmp/path-hook.cache`, rescans only when `find ... -newer cache`, adds each executable's dir once to `PATH` via `:...:` guard, then unsets temps.
- Reference pattern from `clangc` (what "correct" looks like in this repo): `set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `source "$(include "lib/cmdarg.sh")"` + `source "$(include "lib/compile.sh")"` + `source "$(include "check-deps")"` + `checkDeps "$0"` in order; `cmdarg_info`/`declare -a compiler_args`/`cmdarg "c"`/`"o?"`/`"a?[]"`/`"q"`/`cmdarg_parse "$@"`; literal `cmdarg_cfg` reads, `((argc <1)) && log-error`, array-safe `compile_and_run` with namerefs.

---

## Script Reviews

### `spinner.sh`

**Path:** `/home/othman/scripts/spinner.sh`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Displays a customizable colored spinner with a message, restoring the terminal state on exit or interruption.
**Declared dependencies:** none (empty block)
**Verdict:** `Minor issues`

#### Critical bugs

None found. — `trap 'cleanup SIGUSR1' SIGUSR1` overwriting `trap 'exit 1' SIGUSR1` (line 59) causes `log-error`'s SIGUSR1 propagation to exit 0 after cursor restore instead of exit 1, but `spinner.sh` only calls `log-error` for invalid color before the main loop; the cursor-restore behavior is intentional and parent error masking is narrow — downgraded to Design issue.

#### Design issues

- **What happens:** SIGUSR1 handler is overwritten to `cleanup` which always `exit 0`, swallowing fatal error propagation from any `log-error` child.

- **Where:**

```bash
trap 'exit 1' SIGUSR1
...
trap 'cleanup SIGUSR1' SIGUSR1
```

- **Why it's wrong:** house-style invariant is `trap 'exit 1' SIGUSR1` for propagation; `cleanup` does `printf '\e[?25h'` then `exit 0` even for SIGUSR1. If `colorCode="$(mapColor "${color}")" || log-error "Invalid color '${color}'"` fires, `log-error` sends SIGUSR1 to spinner, spinner restores cursor and exits 0 — parent sees success. Narrow scope (only invalid-color path) but violates propagation contract.
- **Fix:**

```bash
cleanup() {
  local sig=$1
  printf '\r\e[2K\e[?25h'
  if [[ "${sig}" != TERM ]]; then
    printf '\e[%dm%s %s%s\e[0m' "${colorCode}" "${currentSpinner}" "${msg%$'\n'}" "${padding}"
  fi
  # preserve error code for SIGUSR1
  [[ "${sig}" == SIGUSR1 ]] && exit 1 || exit 0
}
trap 'cleanup SIGUSR1' SIGUSR1
```

- **What happens:** `padding` is only set when `((pad > 0))`, otherwise retains stale value from previous wider terminal iteration; narrow resize leaves trailing spaces.

- **Where:**

```bash
pad=$((COLUMNS - msgLength))
((pad > 0)) && printf -v padding "%*s" "${pad}" ' '
```

- **Why it's wrong:** when `COLUMNS < msgLength`, `padding` not cleared, line erase via `\e[2K` mitigates but variable reuse is fragile.
- **Fix:**

```bash
if ((pad > 0)); then printf -v padding "%*s" "${pad}" ' '; else padding=""; fi
```

#### Minor / style

- `cmdarg` definitions before `cmdarg_info` (lines 30-32 reverse order):

```bash
checkDeps "$0"
cmdarg "c?" "color" ...
cmdarg "t?" "theme" ...
cmdarg_info "header" "$(get-desc "$0")"
```

Functional ( `cmdarg_info` only sets `CMDARG_INFO` ) but drifts from `clangc` reference order `cmdarg_info` → `declare -a` → `cmdarg` → `cmdarg_parse`. No runtime impact — consistency note.

- `msg=${argv[*]:-Loading...}` then `[[ -z ${msg} ]] && log-error "Message is required"` is dead code — default ensures non-empty. Remove check or document that empty `argv` should default not error.
- `shopt checkwinsize &>/dev/null; (:)` hack to trigger `COLUMNS` update is obscure but correct; `&>/dev/null` suppresses non-interactive warning correctly.

#### Confirmed correct (potential false positives)

- `source "$(include "lib/cmdarg.sh")"` + `source "$(include "lib/helpers.sh")"` + `source "$(include "check-deps")"` + `checkDeps "$0"` indirection via `include` + `realpath -m` is intentional house-style path resolution, not fragile.
- Empty DEPENDENCIES block is allowed (`get-deps` returns `x-none`, `checkDeps` returns 0) — not missing deps.
- `set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `mapColor` + `log-error` color validation matches house logging + helper conventions; `mapColor` → `3N` → `\e[3Nm` is correct via `lib/helpers.sh:243-261`.
- `sp` arrays and `msgLength=$((${#msg} + ${#sp[0]} + 1))` visual-width approximation is intentional (unicode spinner glyphs); not a bug.
- `printf '\e[?25l'` / `\e[?25h` cursor hide/show with `cleanup` on `INT`/`TERM`/`SIGUSR1` is correct terminal-restore contract; `clangc` reference does not apply here — spinner is intentionally infinite `while :; do ... sleep 0.1`.

---

### `repeat-it`

**Path:** `/home/othman/scripts/repeat-it`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Repeat a command until it succeeds
**Declared dependencies:** `gum`
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **What happens:** `cmd="${argv[*]}"` flattens positional args with `IFS` first char, losing original quoting; `bash -c "${cmd}"` re-parses, so `repeat-it echo "a  b"` works but `repeat-it printf '%q\n' "a  b"` may mis-handle.
- **Where:**

```bash
cmd="${argv[*]}"
...
if bash -c "${cmd}"; then
```

- **Why it's wrong:** `argv[@]` carries boundaries, `argv[*]` does not; complex commands with quotes/pipes need exact string. Existing usage (`gum write` input or `argv[*]` join) is intentional for simple retry commands, but document limitation.
- **Fix:** either keep as-is and document “join” behavior, or preserve via `cmd="${argv[*]}"` → `printf -v cmd '%q ' "${argv[@]}"` and `bash -c "$cmd"`; minimal fix is doc note. No code change required for current batch — flag as known ceiling.

- **What happens:** retry counter off-by-one in success message — first success after 2 failures reports 3.
- **Where:**

```bash
counter=1
while true; do
  if bash -c "${cmd}"; then
    if ((counter > 1)); then log-success "Done after ${counter} retries 🚀!"; fi
    break
  fi
  ...
  "${preserve}" || clear
  ((counter++))
done
```

- **Why it's wrong:** counter increments after failure; after N failures then success, counter = N+1. `((counter-1))` is real retry count.
- **Fix:**

```bash
log-success "Done after $((counter-1)) retries 🚀!"
# or start counter=0 and increment before check
```

Low severity — message only.

- **What happens:** `isPositive "${delay}"` allows `0` or `0.0`; `gum spin -- sleep "${delay}"` with 0 causes tight retry loop (no delay).
- **Where:**

```bash
delay="${cmdarg_cfg['delay']}" # default "5"
isPositive "${delay}" || log-error "Delay must be a positive number"
```

- **Why it's wrong:** `isPositive` regex accepts `0`; zero delay defeats back-off purpose; `tries` similarly allows `0` via `isPositiveInt` but `[[ "${counter}" == "${tries}" ]]` never matches `0` (counter starts 1) → infinite retries despite `tries=0`.
- **Fix:** validate `(( $(echo "${delay} > 0" | bc -l) ))` or `[[ "${delay}" != 0* ]]` and `((tries > 0))`; or use `isPositive` + extra `[[ "${delay}" != 0 ]]` check.

#### Minor / style

- Boolean-as-command with quotes: `"${notify}" && trap 'printf "\a"' EXIT` and `"${preserve}" || clear` — quoted `"true"`/`"false"` still executes as builtin but `if ${cmdarg_cfg['verbose']}; then` without quotes is canonical per brief §5. Remove quotes for consistency: `${notify} && trap ...`; `${preserve} || clear`.
- String equality for numeric `tries`: `[[ "${counter}" == "${tries}" ]]` works but `((counter == tries))` is arithmetic-correct. Keep string or switch to `((counter == tries))` — not a bug under `set -e`.
- `gum spin --title "Retrying '${cmd}' in ${delay}s..."` single-quotes inside double-quotes — if `cmd` contains `'`, title breaks. Use `shellQuote`/`humanQuote` or `printf %q`. Cosmetic — title only.
- `checkDep` `gum` satisfied if `gum` in PATH — correct per `checkDep` pipe-less single dep; not stale.

#### Confirmed correct (potential false positives)

- `source "$(include "lib/helpers.sh")"` + `source "$(include "lib/cmdarg.sh")"` + `source "$(include "check-deps")"` + `checkDeps "$0"` order (helpers before cmdarg) is valid — `clangc` order is reference, not strict; both sources idempotent.
- `cmdarg "n" "notify"` / `"p" "preserve"` booleans default `"false"` → literal `true` when present, used as `if ${var}; then` is correct per `cmdarg.sh:86-87` and `clangc` pattern — not string `"true"` comparison bug.
- `cmdarg "d?" "delay" ... "5"` and `cmdarg "t?" "tries" ... ""` optional strings with default `""` for tries is allowed; `cmdarg_check_empty` treats `""` as empty and required-check only applies to `CMDARG_REQUIRED` (`:` flag), so empty default is correct optional pattern.
- `set -eo pipefail` + `trap 'exit 1' SIGUSR1` present; `log-error` propagation via SIGUSR1 matches house brief §4 — not missing trap.
- `gum write --placeholder "enter a command to repeat..."` fallback when `cmd` empty is intentional interactive path; `[[ -z "${cmd}" ]] && log-error "No command entered."` is correct empty-check after gum.

---

### `replace.sh`

**Path:** `/home/othman/scripts/replace.sh`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): String replacement with optional file inputs and backups
**Declared dependencies:** `sed`
**Verdict:** `Needs fixes`

#### Critical bugs

- **What happens:** `-b`/`--backup` flag is silently ignored when script is run non-interactively (e.g., from `cron`, `ssh`, or piped), so user-requested backups are not created and files are overwritten without recovery.

- **Where:**

```bash
for file in "${files[@]}"; do
  [[ ! -r "${file}" ]] && log-error "File '${file}' is not readable"

  if isInteractiveShell; then
    # Create backup and perform replacement
    if "${backup}"; then
      cp -f "${file}" "${file}.bak" 2>/dev/null || log-error "Backup failed for ${file}"
    fi
  fi

  sed -i "s|${searchEscaped}|${replaceEscaped}|g" "${file}" 2>/dev/null || {
```

- **Why it's wrong:** `isInteractiveShell` checks `[[ -t 0 ]] && [[ -t 1 ]] && ps -o stat= -p "${PPID}" | grep -q 's'`; non-interactive shells fail this, so entire backup block is skipped even though `${backup}` is `true`. Contract should be `if "${backup}"; then cp ...` regardless of TTY. Guard was likely copied from `check-deps` interactive prompt pattern, not backup semantics.
- **Fix:**

```bash
  if "${backup}"; then
    cp -f "${file}" "${file}.bak" 2>/dev/null || log-error "Backup failed for ${file}"
  fi
```

Remove outer `isInteractiveShell` guard; if interactive confirmation for overwrite is desired, add separate prompt, not backup gating.

#### Design issues

- **What happens:** sed escaping insufficient — replacement of strings containing `&`, `|`, or `\` corrupts output or aborts.

- **Where:**

```bash
searchEscaped=$(printf '%s' "${search}" | sed 's|[[\\|.*^$/]|\\&|g')
replaceEscaped=$(printf '%s' "${replace}" | sed 's|[[\\|.*^$/]|\\&|g')
...
sed "s|${searchEscaped}|${replaceEscaped}|g"
sed -i "s|${searchEscaped}|${replaceEscaped}|g" "${file}"
```

- **Why it's wrong:** delimiter is `|`, so `|` and `\` and `&` must be escaped; search pattern `[[\\|.*^$/]` attempts to escape `|.*^$/\` inside bracket expression but includes `[[` typo and omits `&`; replace string must escape `&` (whole-match) and `\` and delimiter `|`, not `.*^$/`. For literal string replace, correct is `searchEscaped` via `sed 's/[|\\.*^$[]/\\&/g'` and `replaceEscaped` via `sed 's/[|\\&]/\\&/g'`. Current pattern double-escapes incorrectly and leaves `&` unescaped, so `replace.sh 'a' 'b&c' file` yields `b<a> c` (match inserted).
- **Fix:**

```bash
searchEscaped=$(printf '%s' "${search}" | sed 's/[|\\.*^$[]/\\&/g; s/]/\\&/g')
replaceEscaped=$(printf '%s' "${replace}" | sed 's/[|\\&]/\\&/g')
```

Or use `perl -pe` with `\Q`/`\E` for literal, but minimal sed fix above. Also quote `sed "s|${searchEscaped}|${replaceEscaped}|g"` correctly after escaping.

- **What happens:** `usage()` output embedded in `cmdarg_info "header" "$(get-desc "$0")$(usage)"` duplicates description and prints header without newline separation; also `usage` writes to stdout via `echo`, mixing with header string.
- **Where:**

```bash
usage() {
  printf '\n\n'
  echo "Usage: $(basename "$0") <search> <replace> [OPTIONS]"
  echo "    search:  string to find"
  echo "    replace: string to replace with"
}
cmdarg_info "header" "$(get-desc "$0")$(usage)"
```

- **Why it's wrong:** `get-desc` already extracts DESCRIPTION block; appending `$(usage)` at header construction time captures usage into header string. Works but `cmdarg_usage` will then print header + required/optional args + footer, so custom Usage appears inside header not as separate section. Not fatal but drifts from `clangc` where `cmdarg_info "header" "$(get-desc "$0")"` is bare; custom usage should override `cmdarg_usage` function (as `init.sh:44-58` does) not header injection.
- **Fix:** keep header bare and override usage function like `init.sh` if custom usage needed, or document that `$(usage)` injection is intentional. Low severity — keep or refactor.

#### Minor / style

- `if ((${#files[@]} == 0)); then sed "s|${searchEscaped}|${replaceEscaped}|g"; fi` correctly handles stdin → stdout when no files; subsequent `for file in "${files[@]}"; do` loop no-ops — correct, but add comment that stdin path intentionally falls through.
- `sed -i` without backup suffix uses GNU `sed` semantics (Linux); on macOS BSD `sed -i ''` required — acceptable for Arch/Debian-targeted repo, but document Linux-only.
- `[[ ! -r "${file}" ]] && log-error` inside loop aborts whole script on first unreadable file instead of `log-warning` + `continue`; if partial processing desired, switch to `log-warning` + `continue`.
- `cp -f "${file}" "${file}.bak"` overwrites existing `.bak` silently — document or use `cp -f --backup=numbered`.

#### Confirmed correct (potential false positives)

- `declare -a files; cmdarg "f?[]" "files" "Files to perform replace on"` pre-declaring array before `cmdarg` with `[]` suffix is required per `cmdarg.sh:53-59` — not redundant.
- `cmdarg "b" "backup" "Have a backup"` boolean defaults `"false"` → literal `true` when `-b` present, used as `if "${backup}"; then` is correct boolean-as-command per brief §5 — not string comparison bug.
- `if ((argc < 2)); then log-warning "Missing required arguments"; usage; exit 1; fi` manual positional validation after `cmdarg_parse` is correct because search/replace are positional, not `cmdarg` flags; `clangc` does same `((argc <1)) && log-error`.
- `sed` as sole dependency is correct; `checkDep` `sed` via `command -v sed` will succeed on any coreutils install — not stale.
- `source "$(include "lib/cmdarg.sh")"` + `source "$(include "lib/helpers.sh")"` + `source "$(include "check-deps")"` + `checkDeps "$0"` order matches `clangc` reference (helpers before cmdarg is acceptable variant) — not missing source.

---

### `kill-process`

**Path:** `/home/othman/scripts/kill-process`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Interactively search for running processes by name or pattern, show the matches, then kill them after confirmation. Sends SIGTERM first, then SIGKILL to any process that survives the grace period.
**Declared dependencies:** `gum`
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **What happens:** `pgrep -A` flag not universally available (procps-ng vs BSD/macOS) and previous batch changelog noted fixing `-A` portability, but `-A` remains.

- **Where:**

```bash
# pgrep excludes itself and -A drops its ancestors (the script's own process tree)
matches="$(pgrep -aflA -i "${query}" || true)"
```

- **Why it's wrong:** `pgrep -A` (exclude ancestors) is a procps-ng extension; on systems without it, `pgrep` exits 2 and `|| true` yields empty matches → `log-error "No matching processes found"` even though matches exist. The `-A` intent (avoid killing script's ancestors) is correct but not portable; alternative is `pgrep -af` + filter `$$`/`PPID` chain via `ps -o ppid`.
- **Fix:** drop `-A` and filter manually, or feature-detect:

```bash
if pgrep -A "" 2>/dev/null; then pgrepArgs=(-aflA); else pgrepArgs=(-afl); fi
matches="$(pgrep "${pgrepArgs[@]}" -i "${query}" || true)"
# then filter: echo "${matches}" | grep -vw "^$$\b" | grep -vw "^${PPID}\b"
```

Document Arch/Debian-only if portability not required.

- **What happens:** survivor check uses `if (("${#survivors[@]}")); then` which is `((` inside `( )` subshell with quoted array length — syntax works but is non-canonical and fragile under `set -u`.

- **Where:**

```bash
  if (("${#survivors[@]}")); then
    log-warning "Still alive after SIGTERM, sending SIGKILL: ${survivors[*]}"
    echo "${survivors[@]}" | xargs -r kill -9
  fi
```

- **Why it's wrong:** extra outer `( )` creates subshell; quoted `"${#survivors[@]}"` inside `(( ))` forces string-to-arithmetic conversion; canonical is `if ((${#survivors[@]})); then` or `if (( ${#survivors[@]} > 0 )); then`. Current form relies on bash forgiving `(( "2" ))` but fails with `set -u` if array unset (though `survivors=()` initialized).
- **Fix:**

```bash
  if ((${#survivors[@]})); then
```

Remove outer `( )` and quotes.

#### Minor / style

- `pids="$(awk '{print $1}' <<<"${matches}")"` newline-separated PIDs stored in string; later `for pid in ${pids}; do` word-splits on `IFS` (space/newline) without quotes — works but `while IFS= read -r pid` or `mapfile -t pids` is safer. Not critical as PIDs are numeric.
- `echo "${pids}" | xargs -r kill 2>/dev/null || true` and `echo "${survivors[@]}" | xargs -r kill -9` — `xargs -r` (GNU) correctly avoids `kill` with no args; `kill -9` as separate token is correct; `|| true` suppresses `set -e` exit on partial kill failure — intentional.
- `gum confirm "Kill these processes?"` — `gum confirm` exit 1 on denial correctly falls to `else terminate`; `terminate` (`helpers.sh:61-65`) prints `Program terminated!` and `exit 0` — correct non-error abort.
- `-i` case-insensitive `pgrep -i` correctly matches brief intent; documented.

#### Confirmed correct (potential false positives)

- `set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `source "$(include "lib/cmdarg.sh")"` + `source "$(include "lib/helpers.sh")"` + `source "$(include "check-deps")"` + `checkDeps "$0"` + `cmdarg_info`/`cmdarg_parse` with zero declared flags (only `argv[0]` query) matches `clangc`/house-style — not missing `cmdarg` declarations.
- `# - gum` dependency is correct per `checkDep` single-exe; `gum` is external TUI, not coreutils — not stale.
- `matches="$(pgrep ... || true)"` `|| true` suppresses `set -e` exit on no matches (pgrep exit 1) — intentional, correctly followed by `[[ -z "${matches}" ]] && log-error "No matching processes found"`.
- `log-info "Done"` after kill sequence correctly uses `log-info` (purple INFO to stdout) not `log-success` — house logging allows either; not a bug.

---

### `mk-gitignore`

**Path:** `/home/othman/scripts/mk-gitignore`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Generates a .gitignore file for the current project using various templates. Powered by https://www.gitignore.io
**Declared dependencies:** `curl`, `fzf`
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **What happens:** `curl -fsL` failure aborts script via `set -e` with no user-facing error for specific template; partial `.gitignore` remains.

- **Where:**

```bash
for item in "${selected[@]}"; do
  spinner.sh "Adding ${item} preset..." &
  SPINNER_PID=$!

  curl -fsL "https://www.gitignore.io/api/${item}" >>.gitignore

  killwait "${SPINNER_PID}"
done
```

and

```bash
  templates="$(curl -fsL "https://www.gitignore.io/api/list")"
```

- **Why it's wrong:** `curl -fsL` exits 22 on HTTP error (e.g., unknown template, rate-limit), `set -e` triggers trap `exit 1` without `log-error` context; `.gitignore` already appended with prior items, leaving partial state. No `|| log-error "Failed to fetch ${item}"` handling.
- **Fix:**

```bash
curl -fsL "https://www.gitignore.io/api/${item}" >>.gitignore || { killwait "${SPINNER_PID}"; log-error "Failed to fetch template '${item}' from gitignore.io"; }
```

And for list fetch:

```bash
templates="$(curl -fsL "https://www.gitignore.io/api/list")" || log-error "Failed to fetch template list from gitignore.io"
```

- **What happens:** `action` selection with `?)` pattern matches any single character, potentially intercepting `abort` alias.

- **Where:**

```bash
  case "${action}" in
  append) printf '\n' >>.gitignore ;;
  overwrite) printf '' >.gitignore ;;
  ?) terminate "Didn't find a valid choice" ;;
  abort | *) terminate ;;
  esac
```

- **Why it's wrong:** `?)` in `case` is wildcard for single char, not literal `?`; if `FZF_CMD` returns single-char string (e.g., user types `x` and fzf exits 0 with `--exit-0`), it matches `?)` before `*)`. Intent was catch-all for invalid; `*)` already does. Order makes `?)` redundant and confusing.
- **Fix:** remove `?)` line or change to `\?)` if literal `?` from fzf; keep only `abort | *) terminate ;;` and handle empty via `[[ -z "${action}" ]] && terminate`.

#### Minor / style

- `FZF_CMD=('fzf' '--highlight-line' '--cycle' '--exit-0')` then `"${FZF_CMD[@]}" --multi` — correct array expansion; `--highlight-line`/`--cycle` are cosmetic, `--exit-0` exits with 0 if no match — intentional for non-interactive.
- `spinner.sh "Fetching available templates..." & SPINNER_PID=$!` + `killwait "${SPINNER_PID}"` correctly uses repo's `spinner.sh` (infinite loop) + `killwait` (kill + wait + sleep 0.25) pattern; `spinner.sh` is not declared in DEPENDENCIES but is a repo script found via `hooks/path.sh` PATH hook — not a missing dep per house brief §7 (PATH-registration, not per-script concern).
- `mapfile -t selected < <(echo "${templates}" | tr ',' '\n' | "${FZF_CMD[@]}" --multi)` — `templates` is comma-separated from `curl`; `tr ',' '\n'` correctly splits; `fzf --multi` allows multiple selections; if user selects none, `selected` empty, subsequent `for item` no-ops — correct.
- `printf '\n' >>.gitignore` for append adds blank line separator; `printf '' >.gitignore` truncates for overwrite — correct.

#### Confirmed correct (potential false positives)

- `set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `source "$(include "lib/cmdarg.sh")"` + `source "$(include "lib/helpers.sh")"` + `source "$(include "check-deps")"` + `checkDeps "$0"` + `cmdarg_info`/`cmdarg_parse` with zero flags is correct minimal `cmdarg` usage (like `which-cpp`/`get-desc`) — not missing declarations.
- `# - curl` and `# - fzf` dependencies correctly declared as single exe each; `checkDep` single-alt path returns 0 if found — not pipe syntax error.
- `if [[ -s .gitignore ]]; then ... fi` guard correctly checks non-empty existing `.gitignore` before prompting append/overwrite — empty file correctly skips prompt and proceeds to append.
- `killwait` as external script (not sourced) called via PATH — correct per house `hooks/path.sh` discovery; not a missing `source`.

---

### `ocr`

**Path:** `/home/othman/scripts/ocr`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Extract text from an image using Tesseract
**Declared dependencies:** `tesseract`
**Verdict:** `Needs fixes`

#### Critical bugs

None found. — `strip-ext` undeclared and temp cleanup incomplete are Design issues (no data loss on main path, but functional gaps).

#### Design issues

- **What happens:** calls `strip-ext` command not declared in DEPENDENCIES and not sourced; fails with `command not found` if `strip-ext` not in PATH.

- **Where:**

```bash
if ${saveToFile}; then
  imgNameWithoutExt="$(strip-ext "${image}" png jpg jpeg webp svg gif)"

  tesseract "${image}" "${imgNameWithoutExt}" &>/dev/null ||
    log-error "Tesseract failed on '${image}'."

  log-success "Result saved as '${imgNameWithoutExt}.txt'"
```

- **Why it's wrong:** DEPENDENCIES lists only `tesseract`; `strip-ext` (helper script to strip known extensions, similar to `truncate` in repo) is an implicit dependency. `checkDep` will not prompt to install it, and `set -e` will abort with unhandled `strip-ext: command not found` if missing. Also argument style `strip-ext "${image}" png jpg ...` suggests `strip-ext` expects extensions as varargs, not dot-prefixed — need to verify `strip-ext` contract; if not found, entire `-s` path breaks while non-save path works.
- **Fix:** either add `# - strip-ext` to DEPENDENCIES block (preferred, since it's a repo script) or replace with pure bash: `imgNameWithoutExt="${image%.*}"` and handle case where no dot: `imgNameWithoutExt="${image%.*}"; [[ "${imgNameWithoutExt}" == "${image}" ]] && imgNameWithoutExt="${image}"`. Simplest drop `strip-ext` and use bash param expansion.

- **What happens:** temp file leak — `mktemp` creates empty file `${outputFile}`, tesseract writes `${outputFile}.txt`, trap only removes `${outputFile}` not `${outputFile}.txt`, and trap uses unquoted `$outputFile`.

- **Where:**

```bash
  outputFile="$(mktemp -t ocr-XXXXX)"
  trap 'rm -f $outputFile' EXIT

  if ! tesseract "${image}" "${outputFile}" &>/dev/null; then
    log-error "Tesseract failed on '${image}'."
  fi

  output=$(cat "${outputFile}.txt")
  [[ -z ${output} ]] && log-warning "No readable text found in image '${image}'"

  cat "${outputFile}.txt"
```

- **Why it's wrong:** `mktemp -t ocr-XXXXX` creates file `/tmp/ocr-AbCdE`; tesseract called as `tesseract image /tmp/ocr-AbCdE` creates `/tmp/ocr-AbCdE.txt`; `trap 'rm -f $outputFile' EXIT` expands at trap execution time (single quotes defer expansion) and without quotes word-splits, and only removes the empty file, leaving `.txt` leak. On early `log-error` exit, `.txt` also leaked.
- **Fix:**

```bash
  outputFile="$(mktemp -t ocr-XXXXX)"
  trap 'rm -f "$outputFile" "$outputFile.txt"' EXIT
```

Quote and remove both. Also consider `mktemp -u` alternative but `trap` with quoted `"$outputFile"` after assignment captures correctly if trap defined with double quotes: `trap "rm -f '${outputFile}' '${outputFile}.txt'" EXIT` or use `trap 'rm -f "${outputFile}" "${outputFile}.txt"' EXIT` with single quotes containing double-quoted expansions (evaluated at trap time via shell). Simplest: `trap 'rm -f "$outputFile" "$outputFile.txt"' EXIT` works if `outputFile` still in scope; or define trap after assignment with double quotes to capture value: `trap "rm -f '${outputFile}' '${outputFile}.txt'" EXIT`.

#### Minor / style

- Does not source `lib/helpers.sh` (only `lib/cmdarg.sh` + `check-deps`) but calls `log-error`/`log-success`/`log-warning` as wrapper scripts via PATH — correct per logging two-layer house style §3; fallback `lib/helpers.sh` not needed because primary `log-*` wrappers are canonical. Not a bug, but add `source "$(include "lib/helpers.sh")"` for consistency if `strip-ext` removal uses bash helpers.
- `if ${saveToFile}; then` boolean-as-command without quotes is correct per brief §5; `saveToFile=${cmdarg_cfg['save']}` assignment without quotes is okay as value is `true`/`false`.
- `[[ -f "${image}" ]] || log-error "file '${image}' was not found!"` correct existence check; `tesseract ... &>/dev/null || log-error` correctly suppresses tesseract stderr and surfaces via `log-error`.
- `output=$(cat "${outputFile}.txt")` then `cat "${outputFile}.txt"` double-reads file; could `echo "${output}"` but current is fine.

#### Confirmed correct (potential false positives)

- `set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `source "$(include "lib/cmdarg.sh")"` + `source "$(include "check-deps")"` + `checkDeps "$0"` + `cmdarg_info` + `cmdarg "s" "save"` + `cmdarg_parse "$@"` + `saveToFile=${cmdarg_cfg['save']}` + `image=${argv[0]}` matches `clangc` reference for boolean flag + single positional — not missing `declare -a` (not needed for single-value string/boolean).
- `# - tesseract` dependency declaration is correct single exe; `checkDep` will `command -v tesseract` and prompt `tesseract` package if missing — not pipe syntax error.
- `cmdarg "s" "save"` single-letter `"s"` not conflicting with `-h` reserved — correct per `cmdarg.sh:33-36` validation that `-h` is reserved.
- `[[ -f "${image}" ]]` check before tesseract is correct invariant; not redundant with tesseract's own error.

---

### `get-desc`

**Path:** `/home/othman/scripts/get-desc`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Extracts a script's description
**Declared dependencies:** none (empty block)
**Verdict:** `Clean`

#### Critical bugs

None found.

#### Design issues

None found.

#### Minor / style

None found. — `grep -v " --- " || printf ''` correctly suppresses `grep` exit 1 when no description lines (empty block) under `set -e`/`pipefail`; `printf ''` produces no output not `x-none` (unlike `get-deps`), intentional difference between the two extractors.

#### Confirmed correct (potential false positives)

- `set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `source "$(include "lib/cmdarg.sh")"` + `source "$(include "check-deps")"` + `checkDeps "$0"` + `cmdarg_info "header" "Extracts a script's description"` + `cmdarg_parse "$@"` with zero custom flags is the canonical minimal `cmdarg` usage described in brief §5 — not missing required `cmdarg` declarations; `-h`/`--help` still works via `CMDARG_GETOPTLIST="h"`.
- Empty DEPENDENCIES block is allowed per brief §6 — not missing deps; `checkDeps` correctly returns 0 via `getDeps` → `x-none`.
- `if ((argc != 1)); then log-error ... else if [[ -f "${argv[0]}" ]]; then file="${argv[0]}" else file="$(command -v "${argv[0]}")" fi; [[ ! -f "${file}" ]] && log-error` correctly handles both path and command-name input per `getDeps` helper in `lib/helpers.sh:67-84`.
- `sed -n '/# --- DESCRIPTION --- #/{:loop; n; /# --- DEPENDENCIES --- #/q; /# --- END SIGNATURE --- #/q; /\# /p; b loop}' | sed 's|# ||g' | grep -v " --- "` exactly matches house-style §6 `get-desc` spec — not a custom parser divergence.

---

### `which-cpp`

**Path:** `/home/othman/scripts/which-cpp`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Detects the first available C++ compiler and prints its version
**Declared dependencies:** `awk`
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **What happens:** if no compiler (`g++`, `clang++`, `c++`) is installed, `version` remains unset and `echo "${version}" | awk ...` outputs empty string with exit 0, instead of error.

- **Where:**

```bash
for compiler in g++ clang++ c++; do
  if command -v "${compiler}" &>/dev/null; then
    version="$("${compiler}" --version | head -n1)"
    break
  fi
done

echo "${version}" | awk '
{
  if ($1 == "g++") {
    printf "%s v%s", $1, $3
  } else if ($1 == "Free") {
    printf "g++ v%s", $4
  } else if ($1 == "clang") {
    printf "clang++ v%s", $3
  } else {
    printf "%s v%s", $1, $3
  }
}'
```

- **Why it's wrong:** loop may never assign `version`; `echo "" | awk ...` produces nothing, no `log-error`; caller cannot distinguish “no compiler” from success. Should `[[ -z "${version:-}" ]] && log-error "No C++ compiler found (g++|clang++|c++)"` before awk.
- **Fix:**

```bash
[[ -z "${version:-}" ]] && log-error "No C++ compiler found"
echo "${version}" | awk ...
```

- **What happens:** `awk` version parsing assumes `$3` is version token, breaks for Ubuntu `g++` line `g++ (Ubuntu 11.4.0-...) 11.4.0` where `$3` is `(Ubuntu`.

- **Where:** `if ($1 == "g++") { printf "%s v%s", $1, $3 }`

- **Why it's wrong:** `g++ --version` on Debian/Ubuntu prefixes with `g++ (Ubuntu 11.4.0-1ubuntu1~22.04.2) 11.4.0` — `$3` is `(Ubuntu`, not `11.4.0`. Similarly `Free` branch assumes `Free` as `$1` for some toolchain but fragile.
- **Fix:** parse last field or version regex:

```bash
echo "${version}" | awk '{ ver=$NF; if ($1=="Free") ver=$4; else if ($1=="g++" && $3 ~ /^\(/) ver=$NF; printf "%s v%s", ($1=="Free"?"g++":$1), ver }'
# or
echo "${version}" | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1
```

Low severity if output is cosmetic, but note fragility.

#### Minor / style

- `command -v "${compiler}" &>/dev/null` correctly checks existence without output; `break` after first found correctly implements priority `g++` > `clang++` > `c++`.
- `head -n1` correctly takes first line of `--version`.
- Missing explicit `version=""` initialization before loop — `set -u` not enabled, so not a bug, but initialize for clarity if `set -u` ever added.
- Dependencies list `awk` only; `head`/`grep` omitted per `AGENTS.md` coreutils exclusion — correct granularity.

#### Confirmed correct (potential false positives)

- `set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `source "$(include "lib/cmdarg.sh")"` + `source "$(include "check-deps")"` + `checkDeps "$0"` + `cmdarg_info`/`cmdarg_parse` with zero flags matches `get-desc` minimal pattern — not missing args.
- `# - awk` dependency is allowed even though `awk` is basic command per `AGENTS.md` — listing is not an error, just explicit; `checkDep awk` will succeed on any distro.
- `g++`, `clang++`, `c++` not declared as deps is correct — they are optional alternatives probed at runtime, not required package deps; `which-cpp`'s purpose is detection, not enforcement.
- `echo "${version}" | awk` pipe under `set -o pipefail` will propagate `awk` failure correctly; `|| true` not needed since awk always succeeds on empty input — not a hidden `set -e` bug.

---

### `is-git-repo`

**Path:** `/home/othman/scripts/is-git-repo`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Checks if the current directory is a Git repository and not inside a .git directory
**Declared dependencies:** `git`
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **What happens:** uses captured `git rev-parse` output (`"true"`/`"false"`) as executable command via `"${isGitRepo}" || "${action[@]}" ...` — obscure boolean-as-command trick that relies on `true`/`false` builtins and `set -e` interaction.

- **Where:**

```bash
isGitRepo="$(git rev-parse --is-inside-work-tree 2>/dev/null)" || "${action[@]}" "$(pwd) is not a git repository."

# check if the user is inside .git directory
"${isGitRepo}" || "${action[@]}" "Not in a work tree."
```

- **Why it's wrong:** works ( `true` builtin succeeds, `false` fails and triggers `||` ), but obscures intent and couples to `git`'s literal `"true"`/`"false"` strings; if `git` ever returns `"true\n"` with newline or extra output, `"${isGitRepo}"` becomes `true\n` command not found. Also `isGitRepo` variable name suggests boolean check, not output string; `if [[ "${isGitRepo}" == "true" ]]; then ...` is clearer. Current form also conflates “rev-parse failed” (first line `||`) with “inside work tree = false” (second line) — both trigger `log-error` but with different messages, okay.
- **Fix:** explicit:

```bash
isGitRepo="$(git rev-parse --is-inside-work-tree 2>/dev/null)" || "${action[@]}" "$(pwd) is not a git repository."
[[ "${isGitRepo}" == "true" ]] || "${action[@]}" "Not in a work tree."
```

No functional change, readability improvement.

#### Minor / style

- `cmdarg "s" "safe" "Wether to exit with non-zero code or to kill the parent process as well"` — typo `Wether` → `Whether`.
- `action=(log-error --no-kill)` vs `action=(log-error)` array assignment correctly captures flag with word-splitting protection; `"${action[@]}" "msg"` expansion is correct — not a quoting bug.
- `source` order `lib/helpers.sh` → `lib/cmdarg.sh` → `check-deps` variant is acceptable; helpers before cmdarg does not affect runtime (both idempotent).

#### Confirmed correct (potential false positives)

- `cmdarg "s" "safe"` boolean flag with `isSafe="${cmdarg_cfg['safe']}"` then `if "${isSafe}"; then action=(log-error --no-kill)` is correct boolean-as-command per brief §5 and `log-error`'s `--no-kill`/`--safe` flags per brief §4 — not missing validation.
- `--no-kill` flag correctly maps to `log-error`'s guarded `kill -SIGUSR1 "${PPID}"` with `! isInteractiveShell && ! noKill` — safe mode prevents parent kill, leaving only `exit 1` in child, matching DESCRIPTION's “whether to exit with non-zero code or to kill the parent”.
- `git` as sole dependency is correct; `checkDep git` via `command -v git` matches `checkDeps` flow — not missing `git` subcommand deps.
- `set -eo pipefail` + `trap 'exit 1' SIGUSR1` present; `git rev-parse ... 2>/dev/null || "${action[@]}"` correctly uses `||` to suppress `set -e` abort on git failure (non-repo), then explicitly handles error via `log-error` — intentional `set -e` + `||` pattern.

---

### `killwait`

**Path:** `/home/othman/scripts/killwait`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Kills and waits a proccess to finish
**Declared dependencies:** none (empty block)
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **What happens:** missing `set -eo pipefail` that every other script includes per `clangc` reference; failures not abort, but script is simple so low impact — inconsistency.

- **Where:**

```bash
# --- DESCRIPTION --- #
# Kills and waits a proccess to finish
# --- DEPENDENCIES --- #
#
# --- END SIGNATURE --- #
trap 'exit 1' SIGUSR1
# ---  Main script logic --- #
force=0
```

- **Why it's wrong:** house brief §4 says every script starts with `set -eo pipefail` and `trap 'exit 1' SIGUSR1`; `killwait` only has trap. `set -e` would cause early exit on `kill`/`wait` failure but those are already guarded with `|| true`, so not critical — but missing `set -e` diverges from invariant.
- **Fix:**

```bash
set -eo pipefail
trap 'exit 1' SIGUSR1
```

- **What happens:** force flag detection via `[[ "$1" =~ --force|-f ]]` is regex substring match, not exact flag.

- **Where:**

```bash
force=0
if [[ "$1" =~ --force|-f ]]; then
  shift
  force=1
fi

pid="$1"
```

- **Why it's wrong:** `[[ "foo-f-bar" =~ --force|-f ]]` matches `-f` substring, so `killwait foo-f-bar` incorrectly treats as force; also `killwait --forceful` matches `--force` substring. Should be exact: `[[ "$1" == "--force" || "$1" == "-f" ]]`. Also `shift` without `|| true` could fail under `set -e` if no args, but `set -e` not enabled so not triggering — still add guard.
- **Fix:**

```bash
if [[ "$1" == "--force" || "$1" == "-f" ]]; then
  shift || true
  force=1
fi
```

- **What happens:** no validation of `pid` — empty or non-numeric `pid` silently `kill ""` fails then `wait ""` fails, both `|| true`, finally `sleep 0.25 && exit 0` succeeds, caller (`mk-gitignore`) thinks spinner was killed even though pid was invalid.

- **Where:**

```bash
pid="$1"
...
kill "${pid}" 2>/dev/null || true
...
wait "${pid}" 2>/dev/null || true

sleep 0.25 && exit 0
```

- **Why it's wrong:** `killwait` is infrastructure for `mk-gitignore` spinner; invalid `SPINNER_PID` (e.g., spinner failed to start) should error loudly not `exit 0`. At least `[[ -n "${pid}" ]] && isPositiveInt "${pid}" || { log-warning "killwait: invalid pid '${pid}'"; exit 0; }` or similar.
- **Fix:** add validation before kill:

```bash
[[ -n "${pid}" ]] || exit 0
isPositiveInt "${pid}" || { log-warning "killwait: invalid pid '${pid}'"; exit 0; }
```

#### Minor / style

- Typo in DESCRIPTION: `proccess` → `process`.
- `kill -9` vs `kill` distinction with `force` flag is correct; `kill` default SIGTERM vs `kill -9` SIGKILL matches comment; `wait "${pid}" 2>/dev/null || true` correctly waits only if pid is child (spinner is child of `mk-gitignore`'s shell, so `wait` succeeds when called from same shell; when `killwait` is separate process, `wait` will fail because pid is not its child — but `|| true` suppresses, and `sleep 0.25` still gives spinner time to exit — works but `wait` in separate process is effectively no-op; correct pattern is `wait` in same shell, but current cross-process `wait` is harmless.
- `sleep 0.25 && exit 0` after `wait` ensures spinner's cursor restore completes before caller proceeds; correct timing guard, not arbitrary.
- No `source "$(include ...)"` or `checkDeps` — correct for zero-dependency tiny helper; not missing deps per brief §6 (empty block allowed).

#### Confirmed correct (potential false positives)

- `trap 'exit 1' SIGUSR1` present (even without `set -e`) correctly participates in house propagation chain if this helper is ever the parent of a `log-error` sender — not redundant.
- Empty DEPENDENCIES block is allowed — not stale; `checkDeps` would return 0 via `x-none`, but helper intentionally omits `checkDeps` for minimal overhead — acceptable for <40 line helper.
- `kill "${pid}" 2>/dev/null || true` and `wait ... || true` `|| true` suppression is correct under `set -e` (if enabled) to avoid abort on “no such process” — intentional.
- `force` default `0` and `((force))` arithmetic test is correct; not string comparison bug.

---

## Batch Summary

- **Scripts reviewed:** 10 / 10
- **Critical bugs:** `replace.sh` — backup gated by `isInteractiveShell` silently ignores `-b` in non-interactive runs (data-loss risk) — see replace.sh Critical bugs; no other script has data-loss-level critical (spinner SIGUSR1 overwrite downgraded to Design, see below).
- **Design issues worth escalating:** `spinner.sh` (SIGUSR1 trap overwritten to `exit 0` masking `log-error` propagation + stale `padding` on narrow resize), `ocr` (undeclared `strip-ext` dependency + tmp `.txt` leak via unquoted single-quote trap), `kill-process` (`pgrep -A` portability — procps-ng extension — and `if (("${#survivors[@]}"))` subshell-quoted arithmetic), `which-cpp` (silent empty output when no compiler + fragile `$3` version parsing for Ubuntu `g++`), `is-git-repo` (boolean-as-command `"${isGitRepo}" ||` trick obscures intent), `killwait` (missing `set -eo pipefail` + regex `=~ --force|-f` substring match + no pid validation), `mk-gitignore` (`curl -fsL` failure aborts via `set -e` leaving partial `.gitignore`, and `?)` case wildcard).
- **Cross-cutting patterns observed in this batch** (same bug/pattern repeated across multiple scripts in this batch only; batch-level, not repo-wide):
  - Boolean-as-command `if "${var}"; then` / `"${var}" &&` vs `if ${var}; then` : `repeat-it` (`"${notify}" &&`, `"${preserve}" ||`) and `is-git-repo` (`"${isSafe}"`, `"${isGitRepo}" ||`) quote the boolean literal `true`/`false`; works because `"true"` still executes `true` builtin, but drifts from canonical unquoted `${cmdarg_cfg['x']}` per `clangc` (`if ${cmdarg_cfg['verbose']}; then`). Batch-local style drift.
  - `gum` + `fzf`/`curl` interactive TUI dependencies appear in `repeat-it`, `kill-process`, `mk-gitignore` — all three use `gum spin`/`gum confirm`/`gum input` correctly via `checkDep gum`, but `mk-gitignore` omits `spinner.sh` from DEPENDENCIES (relies on `hooks/path.sh` PATH hook) while `repeat-it` correctly lists `gum` only; shows inconsistent repo-script dep declaration for internal helpers.
  - `spinner.sh` + `killwait` pairing is a batch-local infrastructure pattern: `mk-gitignore` launches `spinner.sh ... & SPINNER_PID=$!` + `killwait` to implement async spinner. `spinner.sh` is infinite loop with cursor hide/show, `killwait` does `kill + wait + sleep 0.25`; `killwait`'s separate-process `wait` is effectively no-op (pid is not its child) — the `sleep 0.25` is the real synchronization. Pattern works but fragile if spinner start fails (no pid validation).
  - Silent-fallback on missing resources: `which-cpp` returns empty when no compiler, `mk-gitignore` `curl` leaves partial `.gitignore`, `replace.sh` stdin path falls through without explicit `exit` — all three batch scripts prefer silent empty/partial over loud `log-error` on resource absence, unlike `ocr`/`is-git-repo` which do `log-error`.
- **Open questions** (design intent unclear, needs the repo owner's input rather than a guess):
  - Is `replace.sh` backup intended to work non-interactively? If `isInteractiveShell` guard was deliberate to avoid backup in CI, should `-b` still force backup regardless? Confirm desired contract.
  - Should `spinner.sh` preserve `log-error` propagation (`exit 1` on SIGUSR1) while still restoring cursor, or is intentional swallow (`exit 0`) desired for spinner's use as background job?
  - Is `strip-ext` in `ocr` a repo script (hence should be `# - strip-ext` dep) or was `imgNameWithoutExt="${image%.*}"` pure-bash intended and `strip-ext` is leftover?
  - Is `kill-process` expected to be portable beyond Arch/Debian (where `pgrep -A` exists) or is `procps-ng` with `-A` considered mandatory via `init.sh` deps?
  - Should `which-cpp` be loud (`log-error`) when no compiler found, or is empty output with exit 0 the intended “detection” contract for callers like `cppc`?
  - Should `killwait` validate `pid` and fail loudly, or is silent `exit 0` on invalid pid intentional for `mk-gitignore` resilience?

---

## Evidence Appendix (optional)

- House style brief: `/home/othman/scripts/docs/code-reviews/house-style-brief.md:1-69`
- Core files read: `include:1-26`, `lib/cmdarg.sh:1-462`, `lib/loggers.sh:1-341`, `lib/helpers.sh:1-420`, `check-deps:1-175`, `log.sh:1-66`, `get-desc:1-53`, `get-deps:1-39`, `init.sh:1-158`, `hooks/path.sh:1-86`, `clangc:1-67`
- Batch scripts read: `spinner.sh:1-95`, `repeat-it:1-94`, `replace.sh:1-81`, `kill-process:1-73`, `mk-gitignore:1-65`, `ocr:1-58`, `get-desc:1-53`, `which-cpp:1-48`, `is-git-repo:1-47`, `killwait:1-39`
- Template: `/home/othman/scripts/docs/templates/batch-review.md:1-85`
- Supporting patterns: `isInteractiveShell: lib/helpers.sh:228-230`, `isPositiveInt: lib/helpers.sh:217-218`, `mapColor: lib/helpers.sh:243-261`, `supportsColor: lib/helpers.sh:333-348`, `checkDep: check-deps:21-52`, `getDeps: lib/helpers.sh:67-84`
