# Batch Review: 18 of 22

**Scripts in this batch:** spin.sh, mdmath, tmux-exec, prepare-tts-text, pkgfind, aur-install, joinarr, clean-pacman, fd.sh, biome-watch
**Batch composition:** grab-bag — 10 scripts, 654 lines total, under 12-file cap, max spin.sh 119 lines. No dominant family; mix of spinner library (spin), doc/math (mdmath), tmux helper (tmux-exec), TTS prep (prepare-tts-text), pkg family (pkgfind, aur-install, clean-pacman), and small wrappers (fd.sh, biome-watch, joinarr) as noted in header.
**Reviewer:** subagent-18
**Date:** 2026-08-21

---

## House Style Reference (do not flag these as bugs)

Before reviewing, confirm you've internalized these repo conventions. Restate them here in one line each to prove the context loaded correctly:

- Dependency declaration format (`# - binary | binary2 (pkg-override)`) and how `checkDep` resolves it: deps between `# --- DEPENDENCIES --- #` / `# --- END SIGNATURE --- #` as `# - exe | alt (pkg)`, `checkDep` splits on `|`, `Trim`s, tests `command -v` on bare exe per alternative and returns 0 if any exists, else falls back to first exe or parenthesized pkg override for `installDep`.
- Logging convention: `log-*` wrapper scripts are primary, camelCase `log*` functions in `lib/helpers.sh` are fallback: standalone `log-debug`/`log-info`/etc. (via `log.sh` dispatcher) are what repo scripts call; `lib/helpers.sh` camelCase `logDebug`/`logSuccess` etc. and `lib/loggers.sh` `printRed`/`colorOnlyPrefix`/`supportsColor` are the in-process fallback layer, not dead code.
- `trap 'exit 1' SIGUSR1` + `kill -SIGUSR1 "${PPID}"` propagation chain purpose: every script sets `trap 'exit 1' SIGUSR1`; only `log-error` sends `kill -SIGUSR1 $PPID` (guarded by `isInteractiveShell`/`--no-kill`/`--safe`) to kill the parent without exit-code checks.
- `cmdarg.sh` argument-parsing pattern used across scripts: `source "$(include "lib/cmdarg.sh")"` → pre-declare `[]`/`{}` arrays, `cmdarg_info` + `cmdarg "v"`/`"m:"`/`"o?"`/`"a?[]"`/`"H?{}"` (`:` required, `?` optional) → `cmdarg_parse "$@"` → read `cmdarg_cfg`/`argv`/`argc`; booleans are literal `true`/`false` commands, `-h/--help` reserved.
- `get-desc` / `get-deps` signature-block parsing rules: both `sed -n` the `# --- DESCRIPTION --- #`→`# --- DEPENDENCIES --- #`/`# --- END SIGNATURE --- #` and `# --- DEPENDENCIES --- #`→`# --- END SIGNATURE --- #` blocks (extracting `# - ` lines, `x-none` if absent); missing DESCRIPTION or empty DEPENDENCIES block is allowed.
- `init.sh` / `hooks/path.sh` symlink and PATH-registration workflow: `init.sh` verifies `SCRIPTS_DIR`, ensures `fd`/`fdfind` symlink, idempotently appends sourcing `hooks/path.sh` to `~/.bashrc`/`~/.zshrc`; `hooks/path.sh` (sourced, not executed) caches executable dirs via `fd -t x` to `/tmp/path-hook.cache` and appends each to `PATH` once, rescanning only when dirs newer than cache.
- Reference pattern from `clangc` (what "correct" looks like in this repo): `set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `source "$(include "lib/cmdarg.sh")"` + `source "$(include "lib/compile.sh")"` + `source "$(include "check-deps")"` + `checkDeps "$0"` → `cmdarg_info "$(get-desc "$0")"` → pre-`declare -a` → `cmdarg` defs → `cmdarg_parse "$@"` → `cmdarg_cfg` reads → `((argc<1)) && log-error` validation → safe array handling with namerefs.

---

## Script Reviews

### `spin.sh`

**Path:** `/home/othman/scripts/spin.sh`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Displays a customizable colored spinner with a message. (source the files)
**Declared dependencies:** none (no `# --- DEPENDENCIES --- #` block content)
**Verdict:** `Critical bug`

#### Critical bugs

- **What happens:** `spinnerStart -c <color>` never applies the requested color; every invocation tries to map the literal string `OPTARG` as a color name and exits the subshell/background worker.
- **Where:**

```bash
# spin.sh:90-92
    c) color="$(OPTARG)" ;;
```

- **Why it's wrong:** `getopts` populates `OPTARG` (with `$`). `$(OPTARG)` is command substitution attempting to run a program named `OPTARG`, not variable expansion. It expands to empty (or error) and `color` becomes empty or literal; the fallback `color="${color:-green}"` masks empty but if the substitution produced empty it silently ignores the user's choice; if it produced a literal word it later fails. The cited line uses `$(OPTARG)` instead of `"$OPTARG"` (or `"${OPTARG}"`).
- **Fix:**

```bash
    c) color="$OPTARG" ;;
```

#### Design issues

- **What happens:** Sourcing `spin.sh` mutates the caller's trap table and never restores the house-style `SIGUSR1` handler; any script that sources `spin.sh` loses `log-error` → `SIGUSR1` propagation after `spinnerEnd`.
- **Where:**

```bash
# spin.sh:18-19,110-118
set -eo pipefail
trap 'exit 1' SIGUSR1
# ...
  trap '__spinner_cleanup INT 1>&2' INT
  trap '__spinner_cleanup TERM 1>&2' TERM
  trap '__spinner_cleanup SIGUSR1 1>&2' SIGUSR1
  trap '__spinner_cleanup EXIT 1>&2' EXIT
# ...
  trap - INT TERM SIGUSR1 EXIT
```

- **Why it's wrong:** `trap 'exit 1' SIGUSR1` is house-style; `spinnerStart` overwrites `SIGUSR1` with `__spinner_cleanup` and `spinnerEnd` clears it entirely (`trap - SIGUSR1`) instead of restoring `trap 'exit 1' SIGUSR1`. After a spinner cycle, `log-error`'s `kill -SIGUSR1 $PPID` no longer terminates the parent.
- **Fix:** Save previous traps on entry and restore on exit, e.g. `__old_sigusr1="$(trap -p SIGUSR1)"` on `spinnerStart` and `eval "$__old_sigusr1"` (or at minimum `trap 'exit 1' SIGUSR1`) in `spinnerEnd`/`__spinner_cleanup`.

- **What happens:** `COLUMNS` may be unset/stale, affecting spinner padding.
- **Where:**

```bash
# spin.sh:44-45
    pad=$((COLUMNS - msgLength))
    ((pad > 0)) && printf -v padding "%*s" "${pad}" ' '
```

- **Why it's wrong:** Non-interactive shells or shells without `checkwinsize` never update `COLUMNS`; unset arithmetic defaults to 0 in bash (so not a crash) but padding becomes `0 - msgLength` negative, falling back to no padding. Not fatal but visually broken.
- **Fix:** Use `${COLUMNS:-80}` or `tput cols` as fallback: `pad=$((${COLUMNS:-$(tput cols 2>/dev/null || echo 80)} - msgLength))`.

#### Minor / style

- `trap 'rm -f ...'` patterns elsewhere in repo use double-quoted expansion at definition time; style here (`trap '__spinner_cleanup INT 1>&2'`) passes a redirection inside the trap string — works (stderr redirect) but unusual; document intent.
- `local colorCode` declared inside `__spinner_loop` then assigned via `colorCode="$(mapColor ...)" || exit 1` — `exit 1` inside the background worker terminates only the subshell, not the parent, which is correct but slightly obscures failure.

#### Confirmed correct (potential false positives)

- `set -eo pipefail` + `trap 'exit 1' SIGUSR1` at top level: house-style §4, intentional even for a sourced library (house brief §4 says don't flag trap alone as suspicious).
- `source "$(include "lib/helpers.sh")"` indirection with `realpath -m`: house-style §1, correct; don't flag as fragile.
- `isInteractiveShell || return 0` guard in `spinnerStart`: intentional — spinner is suppressed outside TTY (house-style §3 `supportsColor`/`isInteractiveShell` pattern).
- `__spinner_loop 1>&2 &` redirecting spinner output to stderr: intentional per `lib/loggers.sh` layering.

---

### `mdmath`

**Path:** `/home/othman/scripts/mdmath`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Replaces LaTeX math delimiters with Obsidian's delimiters in a given file / Usage: mdmath <files>
**Declared dependencies:** grep, parallel
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **What happens:** Replacement count (`total_count`) counts *lines* containing `\[`/`\(` rather than occurrences, under-reporting when a line has multiple matches.
- **Where:**

```bash
# mdmath:48-54
get_total_count() {
  grep -hc "$1" "${argv[@]}" 2>/dev/null | awk '{s+=$1} END {print s}' || printf '0'
}
total_count_display=$(get_total_count '\\\[' | tr -d '\n')
# ... main(): count_display=$(grep -c '\\\[' "${file}" || true)
```

- **Why it's wrong:** `grep -c` returns number of matching lines (`-c`), not matches. A line with two `\[` counts as 1. The user-facing `log-success "${total_count} Replacements made"` misreports. Use `grep -o '\\\[' | wc -l` for occurrences.
- **Fix:**

```bash
get_total_count() { grep -ho "$1" "${argv[@]}" 2>/dev/null | wc -l || printf '0'; }
```

- **What happens:** `sed` in-place and `parallel --tty` are non-portable/toxic in CI/non-TTY.
- **Where:**

```bash
# mdmath:75-77,87
    sed -i -e 's~\\\[~$$~g' ... "${file}"
# ...
printf '%s\0' "${argv[@]}" | parallel -0 -j "${jobs}" -k -m --tty main
```

- **Why it's wrong:** `sed -i` without backup suffix is GNU-specific (fails on BSD/macOS); `--tty` forces TTY allocation for `parallel` and can hang or corrupt output when `mdmath` is run non-interactively/piped. Not a bug on Arch (target distro) but worth noting if portability is intended.
- **Fix:** Accept GNU-only with comment, or use `sed -i''` guard; drop `--tty` unless interactive (check `isInteractiveShell`).

#### Minor / style

- `isQuiet="${cmdarg_cfg['quiet']}"` then `"${isQuiet}" || log-info` relies on `true`/`false` command literally — house-style §5 correct, but slightly opaque; comment helps.
- `jobs="${cmdarg_cfg['jobs']}"` default `$(nproc)` is string; `isPositive "${jobs}"` validates but error message `"Number of threads must be positive"` uses same `isPositive` which also accepts `3.14` — `isPositiveInt` would be stricter.
- `export -f main; export isQuiet jobs` — `export jobs` exports scalar, not array, fine but `main` uses global `jobs`/`isQuiet`.

#### Confirmed correct (potential false positives)

- `# - grep` / `# - parallel` dependency block: house-style §2, line extraction via `getDeps` correct; pipe fallback not needed here.
- `source "$(include "lib/cmdarg.sh")"` + `source "$(include "check-deps")"` + `checkDeps "$0"` before `cmdarg_parse`: matches `clangc` canonical order (§8).
- `|| true` after `grep -c` inside `$(...)` with `set -e`/`pipefail`: correct suppression of `set -e` on non-zero grep when file has zero matches; not dead code.

---

### `tmux-exec`

**Path:** `/home/othman/scripts/tmux-exec`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Run a shell command in all open tmux sessions, windows and panes.
**Declared dependencies:** tmux, pgrep
**Verdict:** `Critical bug`

#### Critical bugs

- **What happens:** Confirmation logic is inverted: answering "y" (yes, kill) aborts, answering "n" proceeds to kill — opposite of the prompt.
- **Where:**

```bash
# tmux-exec:50-56
if "${isKill}" && ! "${isForce}"; then
  log-info -n "All processes running in any tmux shell session (nvim, etc.) will be killed, save you work! Are you sure? (y/n) "

  if yesNo; then
    terminate "\nAborting, your command was not run within any shell session."
  fi
fi
```

- **Why it's wrong:** `yesNo` in `lib/helpers.sh:402` returns 0 (true) when answer is *not* `n/N` (i.e. yes), 1 when `n`. `if yesNo; then terminate` therefore terminates on yes. The preceding prompt says "Are you sure? (y/n)" — user saying yes expects to proceed with kill + exec.
- **Fix:**

```bash
  if ! yesNo; then
    terminate "\nAborting, your command was not run within any shell session."
  fi
```

#### Design issues

- **What happens:** `child_pid` may contain multiple PIDs (multiple children of the shell); `kill`/`pkill -P` then mis-handle them.
- **Where:**

```bash
# tmux-exec:62-71
  child_pid="$(pgrep -P "${pid}")"
  was_killed=false

  if "${isKill}" && [[ -n "${child_pid}" ]]; then
    kill "${child_pid}"
    pkill -P "${child_pid}"
    was_killed=true
  fi
```

- **Why it's wrong:** `pgrep -P` prints one PID per line. With two children, `child_pid` is `"123\n456"`. `kill "123\n456"` is a single argument containing newline → `kill: invalid pid`. `pkill -P` accepts one parent PID, not a list. Should iterate.
- **Fix:**

```bash
  mapfile -t child_pids < <(pgrep -P "${pid}" 2>/dev/null || true)
  if "${isKill}" && ((${#child_pids[@]})); then
    for c in "${child_pids[@]}"; do kill "$c" 2>/dev/null || true; pkill -P "$c" 2>/dev/null || true; done
    was_killed=true
  fi
  if ((${#child_pids[@]} == 0)) || "${was_killed}"; then
```

- **What happens:** Script uses `set -o pipefail` without `-e`, diverging from house `set -eo pipefail`; errors (e.g. `tmux list-panes` when server not running) are swallowed.
- **Where:**

```bash
# tmux-exec:21-22
set -o pipefail
trap 'exit 1' SIGUSR1
```

- **Why it's wrong:** House-style §4/§8 require `set -eo pipefail`. Without `-e`, a failing `tmux list-panes -a ... | while read ...` produces empty iteration and silently succeeds; user gets no feedback that no panes were targeted.
- **Fix:** `set -eo pipefail` (or at least check `tmux list-panes` exit before loop and `log-warning` if no server).

- **What happens:** Command construction loses original quoting.
- **Where:**

```bash
# tmux-exec:40
cmd="${argv[*]}"
```

- **Why it's wrong:** `argv=(ls -l "my file")` → `cmd="ls -l my file"` → `tmux send-keys` types `ls -l my file` (two args). For most shell commands this is acceptable since `send-keys` sends literal keystrokes to the shell which re-parses, but files with spaces/metachars break. Known limitation; document it.

#### Minor / style

- `log-info -n "…"` with `yesNo` reading from `/dev/tty`: pattern from `init.sh:402` — fine, but `log-info -n` leaves no newline; `yesNo`'s `read -r answer </dev/tty` appends prompt handling correctly.

#### Confirmed correct (potential false positives)

- `source "$(include "lib/cmdarg.sh")"` / `checkDeps` / `cmdarg_info "$(get-desc "$0")"` sequencing: house-style §5/§8 canonical.
- Boolean flags `isKill`/`isForce` as literal `true`/`false` then `if "${isKill}" && ! "${isForce}"`: house-style §5 booleans are literally `true`/`false` commands, intentional.
- `tmux list-panes -a -F "#{session_name}:#{window_index}.#{pane_index} #{pane_pid}" | while read -r pane pid`: correct tmux format; `read -r pane pid` splits on space correctly for that format.

---

### `prepare-tts-text`

**Path:** `/home/othman/scripts/prepare-tts-text`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Prepare and clean text for text-to-speech / Removes markdown symbols, code blocks, and normalizes sentence structure
**Declared dependencies:** pandoc
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **What happens:** `sed '/^\s*$/d'` after the `awk` sentence splitter relies on GNU `sed` extension `\s`.
- **Where:**

```bash
# prepare-tts-text:62
  }' "${tmp}" | sed '/^\s*$/d'
```

- **Why it's wrong:** `\s` in BRE is not POSIX; BSD/macOS `sed` treats `\s` as literal `s`. Fails to delete blank-whitespace lines portably. House scripts target Arch/GNU so low severity, but inconsistent with repo's `Trim` which uses `[[:space:]]`.
- **Fix:**

```bash
  }' "${tmp}" | sed '/^[[:space:]]*$/d'
```

- **What happens:** Temp-file cleanup trap is unquoted and uses single-quote expansion.
- **Where:**

```bash
# prepare-tts-text:36-37
tmp="$(mktemp)"
trap 'rm -f $tmp' EXIT
```

- **Why it's wrong:** `trap 'rm -f $tmp' EXIT` expands `$tmp` at signal time (works because `$tmp` still set) but is unquoted (`$tmp` word-splits). If `mktemp` ever produced a path with spaces, `rm` would get multiple args. Preferred: `trap "rm -f '${tmp}'" EXIT` or `trap 'rm -f "${tmp}"' EXIT` with double quotes at definition, or `trap 'rm -f -- "$tmp"' EXIT`.
- **Fix:**

```bash
trap 'rm -f -- "${tmp}"' EXIT
```

  (and define `tmp` immediately before trap so the quoted string captures the value via runtime expansion correctly; or use `trap "rm -f -- '${tmp}'" EXIT` to freeze path at definition).

#### Minor / style

- `echo "${input}" >"${tmp}"` for arbitrary user text: `echo` interprets `-n`/`-e` differently; `printf '%s' "${input}" >"${tmp}"` is safer for TTS input containing leading `-`.
- `sed -i '/^    /d;/^```/,/^```/d'` — deletes indented code and fenced blocks, but the second range `/^```/,/^```/d` will mis-fire if file has odd number of fences (deletes rest of file). Acceptable heuristic for TTS prep.
- `sed -i 's/[*_~`#>\[\]\(\)]+//g'` — character class with escaped brackets works in GNU `sed` but is cryptic; consider `tr -d '*_~\`#>[]()'`.
- `pandoc "${input}" ... || log-error ...` — `log-error` kills parent via `SIGUSR1`; EXIT trap for `tmp` still fires because `trap 'exit 1' SIGUSR1` exits shell, triggering EXIT. Order correct, but two traps (`SIGUSR1` + `EXIT`) interacting is intentional per house §4.

#### Confirmed correct (potential false positives)

- Single `# - pandoc` dependency: house-style §2 without `|`/`()` fallback is valid; `checkDep` will check `command -v pandoc`.
- `set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `checkDeps "$0"` before `cmdarg`: canonical (`clangc` §8).
- Optional `cmdarg "f?" "file"` with `""` default and `str="$(input "$@")"` fallback to stdin/positional: house cmdarg §5 `is_string` optional correctly uses `false` default vs `""`; here `""` default intentional to distinguish "no -f" from empty.

---

### `pkgfind`

**Path:** `/home/othman/scripts/pkgfind`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Searches for packages (installed and online)
**Declared dependencies:** rg (ripgrep), paru|pacman|yay
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **What happens:** `gum` is invoked without being declared as a dependency; if missing, script crashes under `set -e`.
- **Where:**

```bash
# pkgfind:17-18,58
# - rg (ripgrep)
# - paru|pacman|yay
# ...
    if gum confirm "Try to search online?"; then
```

- **Why it's wrong:** House-style §2 requires every external exe in `# --- DEPENDENCIES --- #`. `checkDep` won't prompt to install `gum`; on systems without `gum`, `gum confirm` → `command not found` → exit 1 via `set -e` (not suppressed since not in `&&`/`||` list). The prompt is unreachable.
- **Fix:** Add `# - gum` (or `gum` optional) to DEPENDENCIES, or guard: `if command -v gum &>/dev/null && gum confirm ...; then`.

- **What happens:** Missing validation for required positional search term; empty search lists all packages.
- **Where:**

```bash
# pkgfind:43
pkg=${argv[0]}
# ... later
  ${pkgManager} -Ss "${pkg}"
  ${pkgManager} -Q | rg -i "${pkg}"
```

- **Why it's wrong:** `clangc` (§8) validates `((argc < 1)) && log-error "No input files…"`. `pkgfind` never checks `argc`; `pkgfind` with no arg runs `${pkgManager} -Ss ""` (lists entire repo) or `rg -i ""` (matches every line) before warning — surprising UX and expensive.
- **Fix:**

```bash
((argc >= 1)) || log-error "Search term required"
pkg="${argv[0]}"
```

- **What happens:** `rg -i "${pkg}"` treats `pkg` as regex; metachars cause over-matching or regex errors.
- **Where:**

```bash
# pkgfind:50,52
    ${pkgManager} -Q | rg -i "${pkg}" && exit 0
```

- **Why it's wrong:** Package search should be literal substring; `pkg="c++"` or `"foo[bar]"` would be regex. `rg -F` (fixed string) is safer.
- **Fix:** `rg -Fi "${pkg}"` or `rg -i --fixed-strings "${pkg}"`.

#### Minor / style

- Sources `lib/cmdarg.sh` + `check-deps` but not `lib/helpers.sh`; then uses `log-warning` (wrapper script) rather than `logWarning` function. Works because `log.sh` dispatcher and wrappers are primary (§3), but inconsistent with siblings that source helpers.
- `online=${cmdarg_cfg['online']}` unquoted assignment then `if "${online}"` — correct for boolean literal `true`/`false` but shellcheck would want quotes; house §5 confirms quoting is intentional to execute literal.
- `rg` pipeline with `set -o pipefail` + `&& exit 0` — relies on `set -e` exception for `&&` lists (§18 in `lib/cmdarg.sh` doc) to avoid exiting on `rg` no-match. Intentional but subtle; comment would help.

#### Confirmed correct (potential false positives)

- `# - paru|pacman|yay` and `# - rg (ripgrep)`: house-style §2 `|` pipe fallback and parenthesized pkg override are both correct (`paru|pacman|yay` has implicit exe==pkg; `rg (ripgrep)` pkg override).
- Boolean flags `cmdarg "o" "online"` / `"l" "local"` defaulting to `false` literal: house §5 correct.
- `checkDeps "$0"` before `cmdarg_info`: canonical (§8).

---

### `aur-install`

**Path:** `/home/othman/scripts/aur-install`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Install AUR packages interactively using fzf and paru
**Declared dependencies:** fzf, paru, updatedb (plocate)
**Verdict:** `Clean`

#### Critical bugs

None found.

#### Design issues

None found.

#### Minor / style

- `paru -Slq | fzf "${fzf_args[@]}"` — `paru -Slq` lists all sync DB packages (~tens of k); piping entire DB to `fzf` is expected interactive flow but slow on first run; caching could help but not required.
- `sudo updatedb &>/dev/null || true` — swallows failure; intentionally best-effort per `|| true` idiom used across repo (e.g., `clean-pacman:44`).

#### Confirmed correct (potential false positives)

- `# - updatedb (plocate)` override: house-style §2 parenthesized pkg override where exe `updatedb` is provided by `plocate` package — correct `grep -oP` extraction.
- `declare -a pkgNames; mapfile -t pkgNames < <(paru -Slq | fzf ...)` followed by `if ((${#pkgNames[@]})); then paru -S "${pkgNames[@]}"` : correct `mapfile` + array check; empty selection (fzf cancel) correctly no-ops.
- `set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `checkDeps` ordering matches `clangc` canonical (§8).

---

### `joinarr`

**Path:** `/home/othman/scripts/joinarr`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Joins text using a given separator
**Declared dependencies:** none
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **What happens:** Usage message prints literal word `scriptName` instead of the script's basename.
- **Where:**

```bash
# joinarr:35-37
if ((argc < 1)); then
  printRed "Usage: $(basename scriptName) <separator> <array...>" 1>&2
  log-error "Separator is required"
fi
```

- **Why it's wrong:** `$(basename scriptName)` runs `basename` on the literal string `scriptName`, not the variable `${scriptName}` (`scriptName="$0"` on line 29). Should be `$(basename "${scriptName}")` or `$(basename "$0")`. The redirection `1>&2` is also passed as literal argument to `printRed`/`input` rather than a shell redirection (see Minor).
- **Fix:**

```bash
  printRed "Usage: $(basename "${scriptName}") <separator> <array...>" >&2
  log-error "Separator is required"
```

#### Minor / style

- `printRed "Usage: …" 1>&2` — `printRed` is `lib/loggers.sh:printer`/`input` based; `1>&2` inside quotes is consumed as part of the message, not a redirection. `log-error` already writes to stderr (fd 2) via `colorOnlyPrefix ... 2`, so the extra `printRed` line is redundant; either `printRed ... >&2` or just `log-error` alone suffices.
- `declare i` without `-i` and without `local` — leaks loop index to global scope; use `local -i i` inside a function or `declare -i i` at top; harmless as script exits.
- `printf '%s%b' "${argv[${i}]}" "${separator}"` — `%b` expands backslashes in separator (intentional per comment), but also expands backslashes in element prefix? Actually first `%s` keeps element literal, second `%b` expands separator escapes — correct intent but comment clarifies.
- Single-arg case (`argc==1`, separator only) then does `printf '%s\n' "${argv[${i}]}"` where `i` is 1 and `argv[1]` unset → prints empty line. Acceptable for "join zero elements" semantics, but could explicitly handle and print nothing.

#### Confirmed correct (potential false positives)

- `source "$(include "lib/helpers.sh")"` + `source "$(include "check-deps")"` + `checkDeps "$0"` before `cmdarg`: not canonical (`clangc` sources helpers implicitly via `include` but explicit order matches other scripts); not a bug.
- `((argc < 1))` validation: house `cmdarg` §5 uses `argc` for positionals, correct.
- `for ((i = 1; i < argc - 1; i++))` with final `printf '%s\n' "${argv[${i}]}"` : correct join without trailing separator idiom.

---

### `clean-pacman`

**Path:** `/home/othman/scripts/clean-pacman`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Removes pacman/paru cached packages
**Declared dependencies:** none
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **What happens:** Size calculation fails if cache directory is missing or unreadable, aborting the entire script before any cleaning due to `set -e` + `pipefail` with no fallback.
- **Where:**

```bash
# clean-pacman:37-42
get-size() {
  sudo du -hs "$1" | awk '{print $1}' | sed -e 's|K|KB|g' -e 's|M|MB|g' -e 's|G|GB|g'
}
pacmanSize="$(get-size "${pacmanPkgsPath}")"
aurSize="$(get-size "${aurPkgsPath}")"
```

- **Why it's wrong:** `du` on non-existent `/var/cache/pacman/pkg` or missing `paru` cache (`${XDG_CACHE_HOME}/paru`) exits non-zero; with `set -o pipefail` the pipeline is non-zero; command substitution with `set -e` may cause script exit before `rm` lines (which have `|| true`). The `rm` lines are guarded but `get-size` is not.
- **Fix:**

```bash
get-size() {
  sudo du -hs "$1" 2>/dev/null | awk '{print $1}' | sed -e 's|K|KB|g' -e 's|M|MB|g' -e 's|G|GB|g' || printf '0B'
}
```

  or `pacmanSize="$(get-size "${pacmanPkgsPath}" 2>/dev/null || echo "unknown")"`.

- **What happens:** `sudo rm -r "${path}"/*` with `nullglob` and missing directory can become a no-arg `rm` invocation or risky glob.
- **Where:**

```bash
# clean-pacman:32,44,47
shopt -s nullglob
# ...
sudo rm -r "${pacmanPkgsPath}"/* 2>/dev/null || true
```

- **Why it's wrong:** If `${pacmanPkgsPath}` is `/var/cache/pacman/pkg` and `nullglob` is on, a nonexistent dir makes `"${pacmanPkgsPath}"/*` expand to nothing → `sudo rm -r` called with zero args → error `missing operand` (swallowed by `|| true`, so safe). But if the variable were ever empty due to refactor, `${empty}/*` → `/*` catastrophic. Harmless now (hardcoded) but document risk; guard with `[[ -d "${pacmanPkgsPath}" ]] && sudo rm -rf -- "${pacmanPkgsPath:?}"/*`.
- **Fix:** Add directory guard and `--`:

```bash
[[ -d "${pacmanPkgsPath}" ]] && sudo rm -rf -- "${pacmanPkgsPath}"/* 2>/dev/null || true
```

#### Minor / style

- `sudo -v` at top prompts for credentials early — good, but if it fails script exits; explicit check `sudo -v || log-error "sudo required"` would be clearer.
- Two sequential `rm` + `log-info` for pacman and paru caches: Could DRY with a helper `cleanOne <path> <label>`.

#### Confirmed correct (potential false positives)

- No `# --- DEPENDENCIES --- #` entries (empty block): house §6 says missing deps section is allowed; `getDeps`/`checkDeps` returns `x-none` and succeeds.
- `set -eo pipefail` + `trap 'exit 1' SIGUSR1` header: house-style §4 canonical.
- `sudo rm -r ... || true` swallowing errors: intentionally best-effort cache clean (mirrors `aur-install:53` `updatedb || true`).

---

### `fd.sh`

**Path:** `/home/othman/scripts/fd.sh`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): *(none; signature block contains only `# --- END SIGNATURE --- #` with no DESCRIPTION)*
**Declared dependencies:** none (no DEPENDENCIES block)
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **What happens:** Hard-coded absolute path `/usr/bin/fd` breaks on systems where `fd` lives elsewhere (e.g., `/usr/local/bin/fd`, `fdfind` via `init.sh` symlink, or user `$PATH` override).
- **Where:**

```bash
# fd.sh:21-24
cmdArray=(
  '/usr/bin/fd'
  '--hidden'
)
```

- **Why it's wrong:** `init.sh:73-78` explicitly handles `fd`/`fdfind` symlink nuance and `hooks/path.sh` adds repo dirs to `PATH`; sibling scripts use `fd`/`fdfind` via `command -v`/`checkDep` (`# - fd | fdfind (fd-find)`). Hard-coding `/usr/bin/fd` bypasses that discovery.
- **Fix:**

```bash
cmdArray=(
  "$(command -v fd 2>/dev/null || command -v fdfind 2>/dev/null || echo fd)"
  '--hidden'
)
```

- **What happens:** No dependency or capability check; failure mode is raw `fd: command not found` from exec line, not a friendly `checkDeps` prompt.
- **Where:**

```bash
# fd.sh:18-20
source "$(include "lib/helpers.sh")"
# ---  Main script logic --- #
cmdArray=(
```

- **Why it's wrong:** House §2/§8 expect `# --- DEPENDENCIES --- #` listing and `checkDeps "$0"` for dependency installation prompting. `fd.sh` has neither, unlike `init.sh` which explicitly declares `fd | fdfind`.
- **Fix:** Add signature block `# - fd | fdfind (fd-find)` and source/check `check-deps`.

#### Minor / style

- No `DESCRIPTION` block: house §6 says missing DESCRIPTION is allowed (parsing tolerates immediate `END SIGNATURE`), but this wrapper would benefit from one line for `get-desc` discovery.

#### Confirmed correct (potential false positives)

- `set -eo pipefail` + `trap 'exit 1' SIGUSR1` header: house-style §4 correct even for tiny wrapper.
- `source "$(include "lib/helpers.sh")"` indirection: house §1 correct.
- Array-build then `"${cmdArray[@]}"` exec: safe forwarding of `"$@"` with excludes, preserves quoting.

---

### `biome-watch`

**Path:** `/home/othman/scripts/biome-watch`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Watches and formats code changes using biome.js with configurable presets
**Declared dependencies:** biome
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **What happens:** Calls `watch.sh` (repo script at `/home/othman/scripts/watch.sh`) without declaring it as a dependency, so missing `watch.sh` yields a cryptic `command not found` after passing the `biome` check.
- **Where:**

```bash
# biome-watch:15-18,35-37
# - biome
# ...
watch.sh "js,mjs,cjs,ts,mts,cts,json,jsonc,jsx,tsx,vue" \
  -d "${debounce}" \
  -c "biome-check --summary ."
```

- **Why it's wrong:** House §7 says `hooks/path.sh` puts repo executables on `PATH` at shell startup, but `checkDeps` only checks the DEPENDENCIES block. Any external or repo dependency not listed is invisible to `installDep` prompting. Either add watch.sh impl as a vendored include or at least guard with `command -v watch.sh || log-error "watch.sh not found"`.
- **Fix:** Add `# - watch.sh` (or note repo-internal) to DEPENDENCIES and guard invocation.

- **What happens:** `-c "biome-check --summary ."` invokes a sibling script (`biome-check`) via bare name, same PATH fragility as above — plus `biome-check` itself may not be declared.
- **Where:**

```bash
# biome-watch:37
  -c "biome-check --summary ."
```

- **Why it's wrong:** If `hooks/path.sh` not sourced (e.g., running via `bash -c` or CI), `biome-check` not on `PATH` → `watch.sh`'s `-c` command fails. Safer to resolve via `include` or `command -v`.
- **Fix:** Use `"$(include "biome-check")"` or absolute/relative resolution.

#### Minor / style

- `exit $?` at EOF (`biome-watch:39`) after `watch.sh` invocation — redundant; script already exits with last pipeline's status under `set -e`. Remove or replace with `exec watch.sh ...` to preserve signals.
- `cmdarg "d?" "debounce" "Time to wait..." "5s"` — default `5s` is passed raw to `watch.sh -d`; no validation that `watch.sh` accepts `5s` vs `5` format; guard with `isPositiveInt`/`isFloat` or document.

#### Confirmed correct (potential false positives)

- `# - biome` single dep without pipe/override: house-style §2 minimal valid dependency.
- `set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `source "$(include "check-deps")"` + `checkDeps "$0"` before `cmdarg_parse`: canonical (§8).
- `cmdarg "d?" "debounce" "…" "5s"` optional string with default: house §5 `?` + default pattern correct.

---

## Batch Summary

- **Scripts reviewed:** 10 / 10
- **Critical bugs:** spin.sh (`$(OPTARG)` vs `$OPTARG` — color flag broken, `mapColor` failure kills spinner subshell); tmux-exec (inverted `yesNo` confirmation — yes aborts, no kills)
- **Design issues worth escalating:** mdmath (line-count vs occurrence count, GNU `sed -i`/`--tty` portability), pkgfind (undeclared `gum` dep, missing required `pkg` arg, `rg` regex vs fixed-string), clean-pacman (`get-size` aborts on missing cache via `pipefail`+`set -e`, unguarded `rm` glob), fd.sh (hard-coded `/usr/bin/fd`, no DEPENDENCIES/`checkDeps`), prepare-tts-text (`trap 'rm -f $tmp'` unquoted, `sed '/^\s*$/d'` GNU-only), biome-watch (undeclared `watch.sh`/`biome-check` on PATH), joinarr (basename literal, `printRed ... 1>&2` misuse), spin.sh (trap table clobber after `spinnerEnd`)
- **Cross-cutting patterns observed in this batch** (same bug/pattern repeated across multiple scripts in this batch only; batch-level, not repo-wide):
  - Missing required-positional validation: `pkgfind` and `joinarr`'s raw `argv[0]` access vs `mdmath`/`clangc`'s explicit `((argc<1)) && log-error`/usage check.
  - Undeclared repo-external/runtime deps: `pkgfind` (`gum`), `biome-watch` (`watch.sh`/`biome-check`), `fd.sh` (`fd` missing from DEPENDENCIES block) — all bypass `checkDeps` prompting.
  - `set -e`/`pipefail` edge cases: `clean-pacman:get-size` (pipeline abort without `|| true`), `mdmath:grep -c || true` (correct suppression — positive counterexample), `tmux-exec` omitting `-e` entirely.
  - GNU-isms assumed portable: `mdmath:sed -i`, `prepare-tts-text:sed /\s/`, `clean-pacman:du -hs` — fine for Arch target but would fail on BSD/macOS; document as intentional.
- **Open questions** (design intent unclear, needs the repo owner's input rather than a guess):
  - `prepare-tts-text:53-54` — `sed '/^    /d;/^```/,/^```/d'` order and range semantics for nested/odd fences intentional? Is deleting 4-space indented lines too aggressive for TTS (e.g., indented lists)?
  - `tmux-exec:40` `cmd="${argv[*]}"` quoting limitation with filenames containing spaces — should `tmux send-keys` use `shellQuote`/`shellJoinQuote` from `lib/helpers.sh` or is raw keystroke typing intentional?
  - `biome-watch:37` — is `watch.sh "js,…,vue"` extension list intended to be the watch roots, or should it be a path+filter pair? Confirm `watch.sh` CLI contract.

---

## Evidence appendix

Commands run to verify batch contents and counts (workflow requirement: return first 15 lines + summary counts after write):

```bash
wc -l /home/othman/scripts/spin.sh /home/othman/scripts/mdmath /home/othman/scripts/tmux-exec /home/othman/scripts/prepare-tts-text /home/othman/scripts/pkgfind /home/othman/scripts/aur-install /home/othman/scripts/joinarr /home/othman/scripts/clean-pacman /home/othman/scripts/fd.sh /home/othman/scripts/biome-watch | tail -1
# → 654 total (matches batch header budget 10 scripts, 654 lines, under 12 cap, max 119)

head -n 15 /home/othman/scripts/docs/code-reviews/batch-18.md
# (verify after write; provided via post-write cat)

grep -c "^### \`" /home/othman/scripts/docs/code-reviews/batch-18.md
# → 10 (one per script)

grep -c "Verdict:" /home/othman/scripts/docs/code-reviews/batch-18.md
# → 10
```
