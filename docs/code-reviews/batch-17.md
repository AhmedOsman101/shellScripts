# Batch Review: 17 of 22

**Scripts in this batch:** mkscript, rofi/rofi-music, basedir, viewlines, loop, tempedit, mvp, update-biome, rmwhich
**Batch composition:** [small-grab] grab-bag — 9 scripts, 616 lines, under 12 cap, max mkscript 127. Mix of mkscript, rofi, basedir, viewlines — no single family, header note grab-bag.
**Reviewer:** subagent-17
**Date:** 2026-08-21

---

## House Style Reference (do not flag these as bugs)

Before reviewing, confirm you've internalized these repo conventions. Restate them here in one line each to prove the context loaded correctly:

- Dependency declaration format (`# - binary | binary2 (pkg-override)`) and how `checkDep` resolves it: Lines `# - exe | alt (pkg)` between `DEPENDENCIES`/`END SIGNATURE`; `checkDep` splits on `|`, `Trim`s, takes first word, `command -v` each alternative in order → 0 if any found, else echoes parenthesized pkg override or first exe for `installDep`/`getPackageManager`.
- Logging convention: `log-*` wrapper scripts are primary, camelCase `log*` functions in `lib/helpers.sh` are fallback: `log.sh` dispatches `LEVEL→colorFunc` via `LEVEL_COLORS`/`LEVEL_OUTPUT` + `colorOnlyPrefix`; `lib/helpers.sh` `logDebug/logInfo/logSuccess/logWarning/logError` are in-process fallbacks, not dead code.
- `trap 'exit 1' SIGUSR1` + `kill -SIGUSR1 "${PPID}"` propagation chain purpose: Every script sets `set -eo pipefail` + `trap 'exit 1' SIGUSR1`; only `log-error` does `kill -SIGUSR1 "${PPID}"` (guarded by `! isInteractiveShell && ! noKill`) to kill the trapping parent without exit-code checks.
- `cmdarg.sh` argument-parsing pattern used across scripts: `source "$(include "lib/cmdarg.sh")"` → `cmdarg_info "header" "$(get-desc "$0")"` → pre-`declare -a/-A` for `[]/{}` → `cmdarg "c" "key" "desc"` (`:` required, `?` optional, `[]` array, `{}` hash, bare=boolean→`true`/`false` literal) → `cmdarg_parse "$@"` → read `cmdarg_cfg['key']`/`argv`/`argc`; `-h/--help` reserved.
- `get-desc` / `get-deps` signature-block parsing rules: `sed -n '/# --- DESCRIPTION --- #/,/# --- DEPENDENCIES --- #/,/# --- END SIGNATURE --- #/{/\# - /p;}'` + `s|# - ||`; missing `DESCRIPTION` or `DEPENDENCIES` block is allowed (prints empty or `x-none`), not a bug.
- `init.sh` / `hooks/path.sh` symlink and PATH-registration workflow: `init.sh` verifies `SCRIPTS_DIR` (default `~/scripts`), `fd`/`fdfind` symlink, hooks/path.sh, idempotently appends `[[ -s "${SCRIPTS_DIR}/hooks/path.sh" ]] && source ...` to `.bashrc`/`.zshrc`; `hooks/path.sh` is sourced at shell startup, `fd --strip-cwd-prefix` caches executables to `/tmp/path-hook.cache`, rescans only when `find -newer` finds newer dirs, adds each exe's dir to `PATH` once.
- Reference pattern from `clangc` (what "correct" looks like in this repo): `set -eo pipefail` + `trap` + `source cmdarg.sh` + `source compile.sh` + `source check-deps` + `checkDeps "$0"` → `cmdarg_info` → `declare -a compiler_args` → `cmdarg "c"`/`"o?"`/`"a?[]"`/`"q"` → `cmdarg_parse "$@"` → literal `cmdarg_cfg` reads → `((argc<1)) && log-error` → arrays + `compile_and_run` via namerefs.

---

## Script Reviews

### `mkscript`

**Path:** `/home/othman/scripts/mkscript`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Automatically creates bash scripts with optional flags for temporary or named files, and copies the script name to the clipboard if temporary
**Declared dependencies:** gum
**Verdict:** `Critical bug`

#### Critical bugs

- **What happens:** `SCRIPTS_DIR` is undefined when creating non-temp script via positional flow, so `file="${SCRIPTS_DIR}/${name}"` expands to `"/<name>"` and attempts to write to filesystem root (permission denied or wrong location).
- **Where:**
```bash
  file="${SCRIPTS_DIR}/${name}"
```
`mkscript:79` inside `elif "${no_flags}"; then` (also reused at `mkscript:89` via `file="${PWD}/${name}"` is correct, but the `SCRIPTS_DIR` path is the repo-default branch).

- **Why it's wrong:** `include` is executed as `source "$(include "lib/cmdarg.sh")"` — the `include` script sets `SCRIPTS_DIR` inside a subshell `$(...)` and never exports it. `mkscript` never sources `lib/helpers.sh` or `init.sh` and never does `: "${SCRIPTS_DIR:=${HOME}/scripts}"`. So `SCRIPTS_DIR` is empty unless the user's environment already exported it (the `hooks/path.sh` guard even does `[[ -n "${SCRIPTS_DIR}" ]] || return 0`). `clangc` and others avoid this variable; `mkscript` is the only batch script that relies on it.
- **Fix:**
```bash
: "${SCRIPTS_DIR:=${HOME}/scripts}"
# or source "$(include "lib/helpers.sh")" which plus init ensures, or use "${HOME}/scripts" fallback
file="${SCRIPTS_DIR}/${name}"
```

- **What happens:** Dead branch — `elif [[ -z "${filename}" ]]` is unreachable, so the `-f` without-value flow never executes and the PWD branch for “no file flag” is shadowed.
- **Where:**
```bash
elif [[ -z "${filename}" ]]; then
  name="$(gum input --placeholder "Enter Script's name: ")" || log-error "Failed to capture the script name"
  file="${PWD}/${name}"
```
`mkscript:87-89`

- **Why it's wrong:** Preceding logic does `{ ${isTemp} || [[ -n "${filename}" ]]; } || no_flags='true'` where `isTemp` is literal `true`/`false` executed as a command. If `filename` is empty and `isTemp` is `false`, the compound fails and `no_flags='true'`; the next `elif "${no_flags}"` catches it before the `elif [[ -z "${filename}" ]]` test. If `isTemp` is `true`, the first `if` already matched. So the third branch can never be true.
- **Fix:** Collapse the third and fourth branches or fix the predicate: keep only `elif [[ -n "${filename}" ]]; then` vs `else` for the interactive PWD case, or test `no_flags` as string `[[ "${no_flags}" == true ]]`.

- **What happens:** `validateAndCreateFile` calls `touch` before `mkdir -p "$(dirname "${file}")"`, so creating a nested script like `foo/bar` fails with `touch: no such file or directory` even though the next line would have created the parent.
- **Where:**
```bash
  validateAndCreateFile "${file}"

  mkdir -p "$(dirname "${file}")" 2>/dev/null
```
`mkscript:81-83` (repeated at `91-93` and `109-111`)

- **Why it's wrong:** System `touch` (not the `lib/helpers.sh` helper which does `mkdir -p` internally) requires parent dirs to exist. Order should be mkdir then touch, or source helpers.sh to get the `touch()` wrapper.
- **Fix:**
```bash
  mkdir -p "$(dirname "${file}")"
  validateAndCreateFile "${file}"
```

#### Design issues

- **Undeclared dependencies:** Uses `clipcopy` and `make-signature` as commands but only declares `gum`. `checkDeps "$0"` will never install `clipcopy`/`make-signature` (internal scripts) and misses them in `get-deps` extraction. Declare or handle missing.
  ```bash
  # --- DEPENDENCIES --- #
  # - gum
  # - clipcopy
  # - make-signature
  ```
- **Silenced mkdir errors:** `mkdir -p "$(dirname "${file}")" 2>/dev/null` hides permission or invalid-path errors; the subsequent `touch` error is the only signal.
- **Inconsistent heredoc vs signature:** Temp path writes minimal `scriptContent` header, while repo-installed path uses `make-signature "${name}" "" "" >"${file}"` — the two codepaths produce different scaffolds without documented reason.

#### Minor / style

- Typo in success message:
```bash
"${quiet}" || log-success "Script '$(basename "${file}")' created succefully!"
# → successfully
```
- `no_flags='false'` as string then `if "${isTemp}"` / `"${quiet}" ||` boolean-as-command is correct per house style, but mixing `[[ -n "${filename}" ]]` and `"${isTemp}"` styles in one compound is hard to read.
- `validateAndCreateFile` uses `[[ -f "${file}" ]] && log-error` — correctly relies on `log-error` killing parent via SIGUSR1, but function has no `local` for `name`/`file` shadowing.

#### Confirmed correct (potential false positives)

- `set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `source "$(include "lib/cmdarg.sh")"` + `source "$(include "check-deps")"` + `checkDeps "$0"` + `cmdarg_info`/`cmdarg_parse "$@"` follows `clangc` reference — do not flag.
- `isTemp="${cmdarg_cfg['temp']}"` + `if "${isTemp}"; then` / `"${quiet}" || log-success` boolean pattern is intentional (`true`/`false` literals executed as commands) per `cmdarg.sh` contract.
- `cmdarg "f?" "file"` optional string with `""` default and `cmdarg "t"` boolean are correct flag types per house brief §5.
- `include` indirection via `realpath -m` is intentional, not fragile.

---

### `rofi/rofi-music`

**Path:** `/home/othman/scripts/rofi/rofi-music`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): _none — no signature block; rofi dmenu frontend for `spotifyctl` (prompt/mesg from `spotifyctl status`, four options Play/Pause/Stop/Previous/Next, theme via `music.rasi`)_
**Declared dependencies:** none (no `# --- DEPENDENCIES --- #` block → `get-deps` yields `x-none`)
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **No house-style header / strict mode:** Missing `set -eo pipefail`, `trap 'exit 1' SIGUSR1`, `source "$(include ...)"`, `checkDeps`, and `cmdarg` — diverges from every other repo script. Failures in `spotifyctl` or `rg` are silent.
  ```bash
  # missing at top:
  set -eo pipefail
  trap 'exit 1' SIGUSR1
  ```

- **Theme path breaks when invoked via PATH:** `RASI="$(dirname "$0")/music.rasi"` resolves relative to `CWD` when `$0` is bare `rofi-music` (as installed by `hooks/path.sh` which adds exe dirs to `PATH`). Then `music.rasi` is not found and `rofi -theme "${RASI}"` falls back silently.
  ```bash
  RASI="$(dirname "$0")/music.rasi"
  # fix:
  RASI="$(dirname -- "$(realpath -m "$0")")/music.rasi"
  # or: "$(dirname -- "${BASH_SOURCE[0]}")/music.rasi"
  ```

- **Undeclared / distro-specific deps:** Uses `rofi`, `spotifyctl`, `rg` (ripgrep) but declares none. `checkDeps` would never offer to install them; `rg 'USE_ICON' "${RASI}"` fails if `rg` missing (alternative `grep` would suffice).
  ```bash
  layout=$(rg 'USE_ICON' "${RASI}" | cut -d'=' -f2)
  # should be: grep / rg | grep -F, and declare deps
  ```

- **No guards for missing theme / offline state:** `rg` on missing `RASI` prints error to stderr; `layout` becomes empty, `spotifyctl current` failure leaves `status` empty, prompt becomes empty string. No `command -v rofi`/`spotifyctl` checks.

#### Minor / style

- Hardcoded `PATH="${PATH}:${HOME}/.local/bin/scripts"` — should rely on `hooks/path.sh` instead of appending a non-standard path.
- Inconsistent quoting: `if [[ ${status} == "playing" ]]; then` unquoted `$status` vs `if [[ "${layout}" == 'NO' ]]` quoted; `case ${chosen} in` unquoted expansion.
- `echo -e "${option_1}\n..."` relies on `echo -e` portability; `printf '%s\n' "${option_1}" ...` is safer.
- Unicode icons require Nerd Font; no fallback comment.

#### Confirmed correct (potential false positives)

- Absence of `DESCRIPTION`/`DEPENDENCIES` blocks is allowed per house brief §6 — `get-desc`/`get-deps` correctly return empty / `x-none`; do not flag as missing header bug for this rofi helper (though adding a header would be consistent).
- `PATH` mutation at top is intentional for rofi scripts that are not part of the normal `hooks/path.sh` scan (nested under `rofi/` which may be excluded) — note divergence but not a logic error.
- `layout=$(rg ... | cut -d'=' -f2)` without `Trim` is fine; `cut` output may contain spaces but comparison `== 'NO'` is strict.

---

### `basedir`

**Path:** `/home/othman/scripts/basedir`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): _empty — no DESCRIPTION text (allowed); script trims `$PWD` or given path for prompt use, with `-l` to print basename only_
**Declared dependencies:** none
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **Variable shadows builtin:** `pwd="${argv[0]:-${PWD}}"` names a variable `pwd` which masks the `pwd` builtin. Works but confusing; `dir`/`path` would avoid shadowing.
- **`part` leaks to global:** Inside `trimPath`, `part="${parts[i]}"` lacks `local`, so after the function returns `part` remains in global scope.
  ```bash
  for ((i = 0; i < n; i++)); do
    local part="${parts[i]}"
  ```

#### Minor / style

- Root-path edge: `trimPath "/"` splits via `IFS='/'` into empty parts, loop skips empties, `result` stays `""` and prints blank line instead of `/`. Similarly `"~/"` prints `~` not `~/`. Harmless for prompt use but incorrect for `/`.
  ```bash
  # inside trimPath after loop:
  [[ -z "${result}" ]] && result="/"
  ```
- Quoting inconsistency: `cmdarg_cfg[last]` without quotes vs `cmdarg_cfg['verbose']` elsewhere — both work for associative arrays but style diverges from `clangc` reference (`'last'`).
- `local IFS='/'` is function-local but `parts` splitting via `<<<"${path}"` with leading `~` yields `~` as first element; the `if ((i == 0)) && [[ "${part}" == "~" ]]` check correctly handles it, but hidden-folder handling `if [[ "${part}" == .* ]]` keeps only `".x"` — intentional, not a bug.
- `((${#pwd} > 20))` threshold 20 is magic; comment would help.

#### Confirmed correct (potential false positives)

- `set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `source "$(include "lib/cmdarg.sh")"` + `source "$(include "lib/helpers.sh")"` + `source "$(include "check-deps")"` + `checkDeps "$0"` + `cmdarg_info`/`cmdarg_parse "$@"` follows `clangc` exactly — do not flag.
- `lastOnly="${cmdarg_cfg[last]}"` + `if "${lastOnly}"; then` boolean-as-command is canonical per `cmdarg.sh` (defaults `false`, set to literal `true`).
- Empty `# --- DESCRIPTION --- #` block is explicitly allowed per house brief §6; `get-desc` tolerates it and `cmdarg_info "header" "$(get-desc "$0")"` correctly gets empty header.
- `pwd="${pwd/#"${HOME}"/\~}"` tilde substitution is intentional prompt shortening, not a bug.
- `local IFS='/'` + `read -ra parts <<<"${path}"` for path splitting is standard pure-bash per AGENTS.md reference table, not an external-command issue.

---

### `viewlines`

**Path:** `/home/othman/scripts/viewlines`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): View a specific line or range of lines from a text file. `viewlines filename 15` -> line 15, `10 20` -> 10-20, `10 -` -> 10 to EOF
**Declared dependencies:** awk
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **Line-number validation allows floats and zero:** `isPositive "${start}"` (and same for `end`) uses `isPositiveFloat` regex `^([0-9]*\.[0-9]+|[0-9]+)$` which accepts `0`, `1.5`, `00`, `01`. `awk "NR == 1.5"` then prints nothing (silent failure) and `((start > lines))` with `0` would not error but line 0 does not exist. Should be `isPositiveInt` plus `(( start >= 1 ))`.
  ```bash
  isPositiveInt "${start}" || log-error "Start must be a positive integer"
  (( start >= 1 )) || log-error "Start must be >= 1"
  ```
- **Leading-zero octal trap in arithmetic:** `((start > lines))` / `((end > lines))` / `((start <= end))` evaluate numbers as bash arithmetic; `08` or `09` triggers `value too great for base`. User running `viewlines file 08` gets bash error, not `log-error`. Use `10#` prefix: `(( 10#${start} > 10#${lines} ))`.
- **No `-f` check:** `[[ -e "${file}" ]]` passes for directories; `awk` on a directory prints `Is a directory` to stderr. Prefer `[[ -f "${file}" ]]`.
- **Awk injection via double quotes:** `awk "NR == ${start} {print; exit}"` interpolates validated number into double-quoted script. Safe today because `isPositive` restricts to digits/dot, but more robust is `awk -v s="${start}" 'NR==s{print; exit}'`.

#### Minor / style

- Counts lines via `lines="$(awk 'END{print NR}' "${file}")"` — second full scan of file; could reuse but fine for small files.
- `isPositive` lives in `helpers.sh` where `0` is considered positive (comment `zero is considered positive`) — the script inherits that quirk; doc should note threshold.
- `grep -v " --- "` in get-desc/get-deps already filters, not relevant here.

#### Confirmed correct (potential false positives)

- `set -eo pipefail` + `trap` + `source cmdarg.sh/helpers/check-deps` + `checkDeps "$0"` + `cmdarg_info` + bare `cmdarg_parse "$@"` (no flags, only positionals) is correct per `clangc` — `declare -a` for positionals is not required when no `[]`/`{}` flags are defined.
- `((argc < 2 || argc > 3)) && cmdarg_usage; exit 2` — positional count validation is correct; `cmdarg` booleans default `false` not needed.
- `awk "NR >= ${start} && NR <= ${end}; NR == ${end} {exit}"` correctly exits early for large files; `NR >= start` without `exit` for `end == "-"` case also correct.
- Declared dependency `awk` matches `checkDep` splitting (single alternative, no pipe/parens needed).

---

### `loop`

**Path:** `/home/othman/scripts/loop`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Repeats a given command or block of code for n times
**Declared dependencies:** gum
**Verdict:** `Needs fixes`

#### Critical bugs

None found — loop continues on `bash -c` failure, which may be intentional; classify as design.

#### Design issues

- **Missing `set -eo pipefail`:** Header has only `trap 'exit 1' SIGUSR1'` without `set -eo pipefail`, diverging from house brief §4 and `clangc` reference. With `set -e` absent, failures in `isPositiveInt`/`log-error` SIGUSR1 chain still work, but `gum write` or `sleep` failures do not abort, and `bash -c "${cmd}"` failures are silently ignored (loop continues). Add `set -eo pipefail` to match repo convention.
- **Quoting loss in command capture:** `cmd="${argv[*]}"` joins positionals with `IFS` first char (space) and discards original quoting. `loop -n 2 ls -l "My File.txt"` becomes `bash -c "ls -l My File.txt"` → splits `My`/`File.txt`. Robust form is `cmd="${argv[*]}"` only if caller quotes, or use `shellJoinQuote` / `printf '%q '`:
  ```bash
  cmd="$(shellJoinQuote "${argv[@]}")"
  # or: printf -v cmd '%q ' "${argv[@]}"
  ```
  Note: interactive fallback via `gum write` already yields a single string, so the array-join path is the only affected one.
- **`bash -c` without error propagation:** `bash -c "${cmd}"` failure does not stop loop or propagate exit code; script always `exit 0`. If strict repetition is intended, check `|| log-warning` or break.
- **`delay` default `"0"` makes `[[ -n "${delay}" ]]` always true:** Loop does `[[ -n "${delay}" ]] && ((0 < count)) && sleep "${delay}"` — with default `0`, second+ iterations always `sleep 0` (no-op syscall). Harmless but wasteful; `[[ "${delay}" != "0" ]]` or `(( $(echo "${delay} > 0" | bc) ))` would be cleaner, or default `""` and test `-n`.

#### Minor / style

- Duplicated comment `# ---  Main script logic --- #` twice (lines 41 and 42).
- `clear="${cmdarg_cfg['clear']}"` + `"${clear}" && ((0 < count)) && clear` shadows the `clear` command with a variable named `clear` — works (variable holds `true`/`false` command name) but reads as `clear && ... && clear` (first `clear` is boolean, second is binary). Rename to `shouldClear`.
- `isPositiveInt`/`isPositive` validation messages say “positive number” but `0` is accepted as positive per helpers — message slightly misleading.

#### Confirmed correct (potential false positives)

- `trap 'exit 1' SIGUSR1` alone (without `set`) is not flagged as leftover debug per house brief §4 — `log-error` is the only sender, still correct.
- `cmdarg "c"` boolean, `cmdarg "d?" "delay" "0"` optional with default, `cmdarg "n:" "iterations"` required follow `cmdarg` flag contract (`?` optional, `:` required); `declare` of arrays not needed here (no `[]`).
- `if [[ -z "${cmd}" ]]; then cmd="$(gum write ...)"` fallback pattern is intentional for interactive use; undeclared `clear`/`sleep`/`bash` in deps is correct (coreutils / bash are not declared per AGENTS.md deps rules).
- `"${clear}" && ((0 < count)) && clear` boolean-as-command is canonical per `cmdarg.sh` §5.

---

### `tempedit`

**Path:** `/home/othman/scripts/tempedit`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Creates a temporary file to edit with the given extension
**Declared dependencies:** nano
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **`cmdarg` declaration before `cmdarg_info`:** `cmdarg "p" "preserve"` is called before `cmdarg_info "header" "$(get-desc "$0")"` — reverse of house brief §5 / `clangc` order (info → declare → parse). Works because `cmdarg` does not require info, but diverges from documented pattern and `cmdarg_usage` will have empty header if `cmdarg` is called first in some versions.
  ```bash
  cmdarg_info "header" "$(get-desc "$0")"
  cmdarg "p" "preserve" "Keep the file..."
  cmdarg_parse "$@"
  ```
- **Undeclared `clipcopy` dependency:** `clipcopy "${file}"` when `--preserve` is used is not in `DEPENDENCIES`; `checkDeps` will not verify/install it, runtime fails if missing.
- **`EDITOR` with arguments not supported:** `command -v "${EDITOR}"` fails for `EDITOR="code --wait"` or `EDITOR="nvim -p"` even though editor binary exists. Should extract first word: `editorBin="${EDITOR%% *}"` then `command -v "${editorBin}"`.
- **`trap` overwrites `EXIT` only for non-preserve:** `trap 'rm -f "$file"' EXIT` sets EXIT trap correctly, but file path contains extension from user input; if `mktemp` fails, `$file` is empty and trap becomes `rm -f ""` (harmless but noisy). `mktemp` failure with `set -e` already exits, so not critical.

#### Minor / style

- `extension="${argv[0]:-md}"` with `[[ "${extension}" == */* ]]` blocks path traversal via slash but allows `extension="foo; echo hi"` → `mktemp -t "tempedit-XXXXX.foo; echo hi"` creates literal semicolon file, not RCE, but name is weird. Sanitizing to `^[a-zA-Z0-9]+$` would be tighter.
- `if ${preserve}; then` boolean-as-command is correct; `preserve` defaults `false`.
- `EDITOR="${EDITOR:-nano}"` fallback is correct, but declared dep `nano` is then required even when user overrides `EDITOR` to `vim` — over-dependency.

#### Confirmed correct (potential false positives)

- `set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `source "$(include "lib/cmdarg.sh")"` + `source "$(include "check-deps")"` + `checkDeps "$0"` is house-correct; missing `lib/helpers.sh` is not a bug because `log-info`/`log-error` are standalone scripts (`log.sh`) not helper functions — both layers intentional per house brief §3.
- `cmdarg "p" "preserve"` boolean without `?`/`:` is correct per `cmdarg.sh` (`CMDARG_FLAG_NOARG`).
- `[[ "${extension}" == */* ]]` slash check is sufficient path-separator guard; `include`'s `realpath -m` not needed here.
- `file="$(mktemp -t "tempedit-XXXXX.${extension}")"` is correct `mktemp` usage; `trap 'rm -f "$file"' EXIT` with single quotes defers expansion to trap time, correctly capturing `$file`.

---

### `mvp`

**Path:** `/home/othman/scripts/mvp`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Moves a file to a new location, creating the target directory if necessary
**Declared dependencies:** mkdir, mv
**Verdict:** `Needs fixes`

#### Critical bugs

None found — missing validation leads to confusing `mv` error, not silent data loss.

#### Design issues

- **Missing argc validation:** `old="${argv[0]}"` / `new="${argv[1]}"` without checking `((argc == 2))`. `mvp` with 0/1 arg runs `sudo mkdir -p "$(dirname "")"` (`.`), then `sudo mv "old" ""` / `sudo mv "" "new"` with cryptic error. Should be:
  ```bash
  (( argc == 2 )) || log-error "Usage: mvp [-f|-i] <source> <dest>"
  ```
  Similarly `old`/`new` existence not checked before `sudo mkdir`.
- **Always `sudo`:** `cmdArray=(sudo mv)` and `sudo mkdir -p` force privilege escalation even for user-owned `~/scripts/foo` moves, prompting for password unnecessarily and risking root-owned files in user dirs. Should try without sudo and fallback, or use `mkdir -p` / `mv` and let user `sudo mvp` if needed. Current design assumes dest is always privileged.
- **Silent `mkdir` errors:** `sudo mkdir -p "$(dirname "${new}")" 2>/dev/null` hides errors (invalid `new`, permission denied, `new` empty → `dirname ""` = `.`). Failures surface only as later `mv` errors.
- **Mutually exclusive flags handled silently:** `if [[ "${force}" == "true" ]]; then cmdArray+=(-f); elif [[ "${interactive}" == "true" ]]; then cmdArray+=(-i); fi` — if both `-f` and `-i` passed, `-i` is silently dropped. `log-warning` or `log-error` on conflict would be clearer.

#### Minor / style

- `force="${cmdarg_cfg["force"]}"` uses double quotes inside brackets vs `['force']` elsewhere — inconsistent but functional.
- `cmdArray+=( "${old}" "${new}")` without `--` — if `old` is `-foo`, `mv` treats as flag. Add `cmdArray+=(-- "${old}" "${new}")`.
- Declared deps `mkdir`/`mv` are coreutils (usually not declared per AGENTS.md), but not harmful; `sudo` is undeclared.

#### Confirmed correct (potential false positives)

- `set -eo pipefail` + `trap` + `source cmdarg.sh/check-deps` + `checkDeps` + `cmdarg_info`/`cmdarg "f"`/`"i"` booleans + `cmdarg_parse "$@"` matches `clangc` pattern; boolean comparison `[[ "${force}" == "true" ]]` is valid alternative to `if "${force}"; then`.
- `# --- DEPENDENCIES --- #` with `# - mkdir` / `# - mv` on separate lines is correct `checkDep` format (no pipe needed); `get-deps` extraction `sed -n '/DEPENDENCIES/,/END SIGNATURE/{/\# - /p;}'` picks both.
- `trap 'exit 1' SIGUSR1` without `include helpers` is not suspicious per house brief §4 (only `log-error` sends SIGUSR1).

---

### `update-biome`

**Path:** `/home/othman/scripts/update-biome`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Downloads the desired version of Biome and installs it on the user's system
**Declared dependencies:** wget
**Verdict:** `Needs fixes`

#### Critical bugs

None found — no silent data loss, but download integrity and path handling are fragile (see Design).

#### Design issues

- **Redundant regex / dead cache logic:** `regex="${version}\$"` + `if [[ ! -f "${tempPath}" || ! "${tempPath}" =~ ${regex} ]]; then wget ... fi` — `tempPath="/tmp/biome-download-${version}"` by construction always ends with `${version}`, so `[[ "${tempPath}" =~ ${regex} ]]` is always true. Second `||` clause never triggers; cache check collapses to `[[ ! -f "${tempPath}" ]]`. If intent was to skip re-download when version already cached, existence test alone suffices; regex is dead code. Also `version` is not regex-escaped (`.` matches any char).
  ```bash
  # simplify to:
  if [[ ! -f "${tempPath}" ]]; then wget -O "${tempPath}" "https://github.com/biomejs/biome/releases/download/%40biomejs%2Fbiome%40${version}/biome-linux-x64"; fi
  # or if checking existing binary version, query `biome --version`
  ```

- **No `version` sanitization (path traversal / URL injection):** `version="${argv[0]}"` is interpolated into `tempPath="/tmp/biome-download-${version}"` and URL `.../biome%40${version}/biome-linux-x64` without validation. `version="../../etc/passwd"` creates `/tmp/biome-download-../../etc/passwd` (resolves outside `/tmp`) and fetches arbitrary URL path. Should validate `[[ "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || log-error "Invalid version"`.

- **Predictable temp file / no integrity check:** `tempPath="/tmp/biome-download-${version}"` is world-predictable, no `mktemp`, no checksum/signature verification after `wget`. Partial download or MITM could install malicious binary via `sudo mv`. Check `wget` exit status, verify size/executable, or use `mktemp` + `sha256sum` if release provides checksums.
  ```bash
  tmp="$(mktemp -t biome-XXXXX)" && wget -O "${tmp}" "..." && chmod +x "${tmp}" && sudo mv "${tmp}" ...
  ```

- **`wget` failure not checked:** With `set -e`, `wget` failure aborts script but leaves no error message beyond wget's stderr; `chmod +x` would still run on stale file if `||` logic skipped download. Should `wget ... || log-error "Download failed"`.

- **`sudo mv` destination logic:** `if command -v biome &>/dev/null; then sudo mv -iv "${tempPath}" "$(command -v biome)"; else sudo mv -v "${tempPath}" '/usr/bin/biome'; fi` — `-i` only when overwriting existing, silent otherwise; no check that `command -v biome` is writable or that `/usr/bin/biome` is the correct fallback on all distros (e.g. `/usr/local/bin`).

#### Minor / style

- `regex="${version}\$"` — `\$` inside double quotes yields literal `$`, correct but obscure; `regex="${version}$"` (or `'\$'` ) is clearer.
- No `get-desc` header argument beyond `cmdarg_info "header" "$(get-desc "$0")"` with no flags defined — `cmdarg_parse "$@"` with only positional is okay but `argc` not checked before `version` use (though `[[ -z "${version}" ]]` covers).
- Declared dep only `wget` but uses `sudo`, `chmod`, `mv` — fine, but `sudo` arguably should be declared if repo chooses to declare privilege tools.

#### Confirmed correct (potential false positives)

- `set -eo pipefail` + `trap` + `source cmdarg/check-deps` + `checkDeps` + `cmdarg_info` + `cmdarg_parse` follows house style; empty flag set is allowed (positionals only).
- `# --- DEPENDENCIES --- #` with single `# - wget` line is correct `checkDep` format; `|`.
- `trap 'exit 1' SIGUSR1` + `log-error "No valid version was provided!"` correctly propagates via SIGUSR1, not a plain `exit 1` bug.
- URL encoding `%40biomejs%2Fbiome%40` for `@biomejs/biome@` is correct GitHub release URL, not a bug.

---

### `rmwhich`

**Path:** `/home/othman/scripts/rmwhich`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Deletes the source of a script, if it exists
**Declared dependencies:** none
**Verdict:** `Critical bug`

#### Critical bugs

- **What happens:** Deletes any executable found in `$PATH`, including system binaries, with no guard that the target belongs to `SCRIPTS_DIR` or is a user script. `rmwhich ls` resolves to `/usr/bin/ls` and `sudo rm -fv /usr/bin/ls` succeeds (with `-f` no confirmation), breaking the system.
- **Where:**
```bash
if path=$(command -v "${file}" 2>/dev/null); then
  if "${force}"; then
    sudo rm -fv "${path}"
  else
    sudo rm -i "${path}"
  fi
else
  log-error "Script ${file} doesn't exist!"
fi
```
`rmwhich:36-43`

- **Why it's wrong:** `command -v` searches full `PATH`, not just `SCRIPTS_DIR`. Description says “Deletes the source of a script” implying repo scripts, but implementation is unrestricted. With `sudo` and `-f` (force) it bypasses `rm -i` prompting entirely. No check like `[[ "${path}" == "${SCRIPTS_DIR}"* ]]` or `[[ -w "${path}" ]]` before escalating to sudo.
- **Fix:**
```bash
path=$(command -v "${file}" 2>/dev/null) || log-error "Script ${file} doesn't exist!"
# guard to repo:
[[ "${path}" == "${SCRIPTS_DIR:-$HOME/scripts}"* ]] || log-error "Refusing to delete ${path}: not inside SCRIPTS_DIR"
# avoid sudo when not needed:
if [[ -w "${path}" ]]; then rm -fv "${path}"; else sudo rm -fv "${path}"; fi
# or require --force to confirm outside SCRIPTS_DIR
```

#### Design issues

- **Always `sudo`:** `sudo rm -fv`/`-i` elevates even when file is user-owned (`~/scripts/mytool`) and writable without sudo, forcing password prompt and creating root-owned trash. Prefer `rm` and fallback to `sudo` only on permission denied.
- **Missing argc validation:** `file="${argv[0]}"` with only `[[ -z "${file}" ]]` check silently ignores extra positionals: `rmwhich foo bar` deletes only `foo`. Should do `((argc == 1)) || log-error "Exactly one argument required"`.
- **No `--` guard:** `sudo rm -fv "${path}"` without `--` fails if `path` starts with `-` (unlikely but defensive: `sudo rm -fv -- "${path}"`).

#### Minor / style

- `force="${cmdarg_cfg[force]}"` missing quotes around key: should be `['force']` for consistency with `clangc` (`"${cmdarg_cfg['force']}"`), though bash allows unquoted associative keys.
- `path` is global (no `local`); not a bug in a script but leaks.
- `log-error "Script ${file} doesn't exist!"` message says “Script” but `command -v` covers binaries, not just scripts — wording mismatch.

#### Confirmed correct (potential false positives)

- `set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `source "$(include "lib/cmdarg.sh")"` + `source "$(include "check-deps")"` + `checkDeps "$0"` + `cmdarg_info` + `cmdarg "f"` + `cmdarg_parse "$@"` is house-correct; `checkDeps` returning `x-none` for empty `DEPENDENCIES` block is intentional per house brief §2, not a missing-deps bug.
- `if "${force}"; then` boolean-as-command is canonical per `cmdarg.sh` §5, not a string-comparison bug.
- `trap 'exit 1' SIGUSR1` + `kill -SIGUSR1` chain via `log-error` is intentional propagation per §4; `rmwhich` correctly does not contain its own `kill`.
- Empty `# --- DEPENDENCIES --- #` block (immediately followed by `# --- END SIGNATURE --- #`) is allowed per house brief §6; do not flag as missing dependencies.

---

## Batch Summary

- **Scripts reviewed:** 9 / 9
- **Critical bugs:** mkscript — `SCRIPTS_DIR` empty → writes to `/`; dead `elif [[ -z "${filename}" ]]` branch unreachable; `touch` before `mkdir` fails for nested paths. rmwhich — unrestricted `sudo rm` via `command -v` deletes any PATH binary including system tools.
- **Design issues worth escalating:** loop — missing `set -eo pipefail`, `cmd="${argv[*]}"` quoting loss, `bash -c` ignores failures. mvp — missing `argc==2` check, always `sudo`, silent `mkdir` errors. update-biome — dead `[[ ... =~ ${regex} ]]` cache logic, unescaped version regex, no version sanitization/path-traversal guard, predictable `/tmp` file and no checksum/`wget` error handling.
- **Cross-cutting patterns observed in this batch** (same bug/pattern repeated across multiple scripts in this batch only; batch-level, not repo-wide):
  - `sudo` forced for user-owned operations (`mvp`, `rmwhich`) — prompts for password when not needed and allows privileged delete of system files.
  - `mkdir -p "$(dirname ...)" 2>/dev/null` silencing errors (`mkscript` ×3, `mvp`) — hides invalid-path/permission failures.
  - Missing/weak positional validation (`viewlines` allows `0`/floats, `mvp`/`rmwhich`/`update-biome` no `argc` guard, `loop` no `cmd` quoting) — arithmetic octal trap (`viewlines` `08`) and `argv[*]` quoting loss (`loop`).
  - Undeclared deps for internal helpers: `clipcopy`/`make-signature` (`mkscript`, `tempedit`), `rg`/`spotifyctl`/`rofi` (`rofi-music`), `sudo` privilege paths — `checkDeps` would never prompt.
  - `trap` without `set -eo pipefail` (`loop` only) vs full house header (`basedir`/`viewlines` correct) — inconsistency in strict mode.
  - Predictable `/tmp` paths without `mktemp` (`update-biome`) vs correct `mktemp` usage (`tempedit`, `mkscript` temp branch) — symlink-attack surface in one.
- **Open questions** (design intent unclear, needs the repo owner's input rather than a guess):
  - Should `rmwhich` be scoped to `${SCRIPTS_DIR}` only, or intentionally allow deleting any `PATH` binary? Current wording “source of a script” suggests repo-only, but implementation is unrestricted — confirm guard and whether `-f` should require extra confirmation outside `SCRIPTS_DIR`.
  - Should `mvp` and `rmwhich` keep unconditional `sudo`, or try unprivileged `mv`/`rm` first and `sudo` only on `EACCES`? Current always-sudo creates root-owned files in user dirs and forces password for `~/scripts` moves.
  - Should `rofi/rofi-music` adopt the full house header (`set -eo pipefail`/`trap`/`include`/`checkDeps`/`cmdarg`) or stay minimal as a rofi helper? Similarly, `RASI` path should be absolute via `realpath` when invoked via `PATH`.
  - For `mkscript`, is `${SCRIPTS_DIR}` intended to be mandatory env export, or should it fallback `: "${SCRIPTS_DIR:=${HOME}/scripts}"` like `init.sh`? Fixes the root-write critical.
  - For `update-biome`, is version format strictly `x.y.z` semver and should download be verified via checksum/signature, and should caching be by file existence or by `biome --version`?

---

## Evidence appendix

- `mkscript` dead branch and `SCRIPTS_DIR` usage verified at `mkscript:41` (`{ ${isTemp} || ... }`), `79`, `81-83`, `87`.
- `rofi-music` `RASI` and `rg` verified at `rofi/rofi-music:4`, `18`, `5`.
- `basedir` `pwd` shadowing and `local IFS` at `basedir:33-40`, `68-77`; `trimPath` empty-result for `/`.
- `viewlines` float/zero/octal at `viewlines:44,61-63`, `46-47`, `51,57,66`.
- `loop` missing `set` at `loop:20`, `cmd="${argv[*]}"` at `40`, `bash -c` at `62`.
- `tempedit` `cmdarg` order at `tempedit:27-29`, `clipcopy` at `42-43`, `EDITOR` check at `50-54`.
- `mvp` argc and `sudo` at `mvp:37-43`, `40`.
- `update-biome` regex/cache at `update-biome:35-39`, predictable tmp at `34`, `sudo mv` at `44-47`.
- `rmwhich` unrestricted `command -v` + `sudo rm` at `rmwhich:36-43`, `force` quoting at `31`.
