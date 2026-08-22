# Batch Review: 14 of 22

**Scripts in this batch:** `get-package-manager` (142), `mdclean` (82), `mkpython` (74), `rofi/rofi-list` (66), `external/testfonts` (62), `net-speed` (54), `runpy` (49), `md2docx` (47), `net-interface` (42)
**Batch composition:** grab-bag filling line budget — 9 scripts, 618 lines, avg 69, no script >150 (under 12 cap), mix of `get-*`, `rofi/` and `external/` subdirs, `mdclean`, `mkpython`, and `net-*`; no deep shared pattern, pairing is incidental line-budget fill, not a name-family or large-tool-plus-fillers batch.
**Reviewer:** subagent-14
**Date:** 2026-08-21

---

## House Style Reference (do not flag these as bugs)

Before reviewing, confirm you've internalized these repo conventions. Restate them here in one line each to prove the context loaded correctly:

- Dependency declaration format (`# - binary | binary2 (pkg-override)`) and how `checkDep` resolves it: deps block `# - exe | alt (pkg)` splits on `|` then `Trim` then `awk '{print $1}'` and `command -v` each alt in order — if any alt found return 0 satisfied, else echo `pkgName` from `(...)` or first `exeName` for `installDep`→`getPackageManager`.
- Logging convention: `log-*` wrapper scripts are primary, camelCase `log*` functions in `lib/helpers.sh` are fallback: every script calls `log-error`/`log-success` as commands (dispatcher `log.sh` maps LEVEL→`colorOnlyPrefix`), helpers' `logError`/`logSuccess` etc. are in-process fallback, not dead code — `log-success` delegates to `logSuccess`.
- `trap 'exit 1' SIGUSR1` + `kill -SIGUSR1 "${PPID}"` propagation chain purpose: every script traps SIGUSR1 to `exit 1`; only `log-error` sends `kill -SIGUSR1 "${PPID}"` guarded by `! isInteractiveShell && ! noKill`, killing the parent that trapped without requiring exit-code checks.
- `cmdarg.sh` argument-parsing pattern used across scripts: `source "$(include "lib/cmdarg.sh")"` → `cmdarg_info "header" "$(get-desc "$0")"` → pre-declare `declare -a/-A` for `[]`/`{}` → `cmdarg "x" "key" "desc"` (`:` required, `?` optional, `[]` array, `{}` hash; `-h/--help` reserved; booleans default `false` → literal `true` command) → `cmdarg_parse "$@"` → read `cmdarg_cfg`/`argv`/`argc`.
- `get-desc` / `get-deps` signature-block parsing rules: both parse `# --- DESCRIPTION --- #` … `# --- DEPENDENCIES --- #` … `# --- END SIGNATURE --- #` blocks via `sed -n`; missing DESCRIPTION or DEPENDENCIES is allowed (prints `x-none`, `checkDeps` returns 0); `get-desc` tolerates either DEPENDENCIES or END SIGNATURE as terminator.
- `init.sh` / `hooks/path.sh` symlink and PATH-registration workflow: `init.sh` verifies `SCRIPTS_DIR` (`~/scripts`), ensures `fd` (prompt symlink `fdfind→fd`), verifies hook exists, then idempotently appends `[[ -s "${SCRIPTS_DIR}/hooks/path.sh" ]] && source ...` to `~/.bashrc`/`.zshrc`; `hooks/path.sh` (sourced at startup) caches `fd --strip-cwd-prefix -t x` discovery to `/tmp/path-hook.cache`, rescans only when dirs newer, adds each executable's dir to `PATH` once (`:”:$PATH:”` guard) and unsets temps — scripts never handle own PATH.
- Reference pattern from `clangc` (what "correct" looks like in this repo): `set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `source cmdarg` + `source compile` + `source check-deps` + `checkDeps "$0"` → `cmdarg_info` → pre-declare array → `cmdarg "c"`/`"o?"`/`"a?[]"`/`"q"` → `cmdarg_parse "$@"` → literal `cmdarg_cfg` reads → `((argc < 1)) && log-error` validation → array-safe delegation via namerefs.

---

## Script Reviews

### `get-package-manager`

**Path:** `/home/othman/scripts/get-package-manager`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Detects the Linux distribution and returns its package manager and install command
**Declared dependencies:** none (empty DEPENDENCIES block — allowed per house §6)
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **What happens:** logic diverges from canonical `lib/helpers.sh:getPackageManager` (source of truth for `installDep`/`checkDeps`) — fallback `ID_LIKE` handling is incomplete, so the same distro can resolve differently depending on whether `installDep` or the standalone script is called.

- **Where:**

```bash
# get-package-manager:101-138 (fallback branch)
  case "${ID_LIKE}" in
  *debian* | *ubuntu*)  # helpers.sh has *debian* | *ubuntu* | *mint*
  ...
  *arch*)               # helpers.sh has *arch* | *cachy*
```

- **Why it's wrong:** `helpers.sh:169` handles `*mint*` (Linux Mint derivatives) in the `ID_LIKE` debian fallback, and `*cachy*` (CachyOS) in the arch fallback with `paru`/`yay` detection; this standalone copy omits both, so Mint/Cachy derivatives via `ID_LIKE` incorrectly hit the `log-error "Unsupported distribution"` path when invoked directly, while `installDep` would succeed.

- **Fix:**

```bash
# add mint to debian fallback, cachy to arch fallback — or better delete this file and delegate:
echo "$(getPackageManager)"  # if duplicated logic must exist, keep single source:
# Alternatively sync the two case branches exactly with helpers.sh:169,187
  *debian* | *ubuntu* | *mint*)
  ...
  *arch* | *cachy*)
```

- **What happens:** stand-alone copy duplicates 120-line distro matrix already in `helpers.sh` — maintenance hazard, already drifted as above. No caller in repo uses `get-package-manager` as a library; `check-deps:126` calls `getPackageManager` from helpers.

- **Why it's design:** duplication without delegation; keep one source (helpers) and make this script a thin wrapper if it must exist.

#### Minor / style

- Empty `DEPENDENCIES` block is correct per brief §6, but `log-error` is used without an explicit `source "$(include "check-deps")"`/`include` guard — relies on `log-error` being on `PATH` via `hooks/path.sh`. Works when hook is sourced, fragile otherwise (same pattern as other leaf scripts; not flagged as bug, noted for consistency).
- `log-error "Unsupported distribution: ${PRETTY_NAME}" >&2` — `>&2` is redundant since `log-error`/`colorOnlyPrefix` already writes to FD 2 via `LEVEL_OUTPUT[ERROR]=2`, but harmless.

#### Confirmed correct (potential false positives)

- `source '/etc/os-release'` without `shellcheck disable` is intentional — file is trusted distro metadata; `getPackageManager` in `helpers.sh:91` does the same.
- `# - ` dependency syntax not flagged: this script has no external deps to declare; `cat`/`awk`/`printf` are coreutils excluded per `AGENTS.md` Dependency Declaration Format.
- `set -eo pipefail` + `trap 'exit 1' SIGUSR1` present (lines 20-21) even though this script never sends SIGUSR1 itself — correct per brief §4 (every script traps, only `log-error` kills).

---

### `mdclean`

**Path:** `/home/othman/scripts/mdclean`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Cleans Markdown files from common Unicode garbage symbols and fixes formatting.
**Declared dependencies:** `sponge (moreutils)`, `perl`, `parallel`
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **What happens:** helper `isPositive` is available only transitively via `check-deps` → `lib/helpers.sh`, not via a direct `source "$(include "lib/helpers.sh")"`; a future refactor of `check-deps` that stops sourcing helpers would silently break `mdclean:38`.

- **Where:**

```bash
# mdclean:25-26
source "$(include "lib/cmdarg.sh")"
source "$(include "check-deps")"
# isPositive used at line 38 without direct helpers import
isPositive "${jobs}" || log-error "Number of threads must be positive"
```

- **Why it's design:** fragile indirection — every other `cmdarg` script that needs helper predicates sources helpers explicitly or via the `clangc` pattern (`include cmdarg`, `include helpers`/`compile`, `include check-deps`). Works today but not by contract.

- **Fix:**

```bash
source "$(include "lib/helpers.sh")"
# or import helpers before check-deps, matching init.sh:35-36 order
```

- **What happens:** `parallel -m` (`--max-args` merging) combined with `main` iterating `for file in "$@"` means `parallel` may batch multiple files into one `main` invocation, while `-k` (keep order) buffers output until the longest job finishes — defeats parallelism for many small files and makes `log-warning`/`log-success` ordering surprising. Also `printf '%s\0' "${argv[@]}" | parallel -0 ... main` with `argc==0` feeds a single NUL → `main ""` → `log-warning "File '' was not found!"` loop, not a clean "no input" error.

- **Why it's design:** no `((argc == 0)) && log-error` guard like `clangc:44`; empty invocation should fail fast via `log-error` rather than spawning `parallel` with a spurious empty filename.

- **Fix:**

```bash
((argc == 0)) && log-error "No input files provided"
printf '%s\0' "${argv[@]}" | parallel -0 -j "${jobs}" -k --tty main
# drop -m, or keep -m only if main were rewritten to handle batches and logging per-batch
```

#### Minor / style

- Commented-out sed line 73 (`# -e ':a; /---[[:space:]]*$/ ...'`) is dead code; remove or document why retained (horizontal-rule-before-H2 fix is disabled but sed still has 10 active `-e` expressions).
- Dependency `parallel` is correct (GNU parallel), but `nproc` (used as default for `jobs`) is coreutils and correctly not declared — consistent with repo's "exclude coreutils" rule.
- `export isQuiet jobs` plus `export -f main` correctly propagates cmdarg boolean `isQuiet` (`false`/`true` literals) to `parallel` subshells; the `"${isQuiet}" || log-success` idiom is house-correct — do not flag as `false` command error.

#### Confirmed correct (potential false positives)

- `"${isQuiet}" || log-success "file '${file}' was cleaned successfully"` — `isQuiet` is a cmdarg boolean that is literally the commands `true`/`false` (brief §5); `if ${cmdarg_cfg['quiet']}; then ...` / `"${isQuiet}" || ...` is the canonical repo pattern, not an unquoted-variable bug.
- `tr -d '\f' <"${file}" | sponge "${file}"` and `perl -CSD -pe 's/[\x{202A}-\x{202E}\x{200F}\x{2066}-\x{2069}]//g' ... | sponge` — two-pass `sponge` rewriting is the intended `moreutils` pattern to avoid truncating `file` before reading; not a UUOC.
- `sed -E -i -e 's/​/ /g'` containing a literal zero-width space (U+200B) is intentional — `mdclean`'s purpose is to strip that exact garbage char (bullet normalization block lines 60-72).
- Zero `DESCRIPTION`/`DEPENDENCIES` content outside block is fine — block exists and deps are extracted correctly via `sed -n '/# --- DEPENDENCIES --- #/,/.../{/\# - /p;}'`.

---

### `mkpython`

**Path:** `/home/othman/scripts/mkpython`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Creates a Python project using `uv` with a corresponding shell script wrapper.
**Declared dependencies:** `fd | fdfind (fd-find)`, `uv`, `nano`
**Verdict:** `Critical bug`

#### Critical bugs

- **What happens:** invocation with no positional argument creates a bogus project `python/.py` / wrapper `~/scripts/.py` or with empty `nameNoExt` causes `fd-all ""` to match every `*.py` file, then `mkdir -p python/ && uv init --name ""` fails cryptically (or worse, `touch ~/scripts/` attempts to touch a directory); no validation that a project name was supplied.

- **Where:**

```bash
# mkpython:32-40
name="${argv[0]}"

# Check if it ends with the .py extension
[[ "${name}" =~ (\.py)$ ]] || name="${name}.py"

nameNoExt="$(strip-ext "${name}" py)"
fileExists="$(fd-all "${nameNoExt}" -e py "${dir}")"
scriptExists=$(fd-all "${nameNoExt}" -d 1 "${SCRIPTS_DIR}")
```

- **Why it's wrong:** `cmdarg` is invoked with no required positional definition (`cmdarg_parse "$@"` with zero `cmdarg` flags), so `argc` may be 0 and `argv[0]` empty; the script never checks `((argc < 1)) && log-error` like `clangc:44` does, so empty `name` propagates to `strip-ext "" → ""`, then `fd-all ""` (pattern `""`) matches everything, `fileExists` becomes a multi-line list (false positive "already exists"), and even if that check is bypassed, `projectDir="${dir}/"` + `uv init --name ""` fails with uv's own error instead of a clear `log-error "No project name provided"`.

- **Fix:**

```bash
((argc < 1)) && log-error "No project name provided"
name="${argv[0]}"
[[ "${name}" =~ (\.py)$ ]] || name="${name}.py"
nameNoExt="$(strip-ext "${name}" py)"
[[ -n "${nameNoExt}" && "${nameNoExt}" != ".py" ]] || log-error "Invalid project name: ${name}"
# also validate nameNoExt doesn't contain '/' and is a valid Python package name if desired
```

- **What happens:** `fd-all` result is captured as a plain string and tested with `[[ -n "${fileExists}" ]]`; if `nameNoExt` is a substring of multiple projects (e.g., `test` matches `mytest` and `test2`), `fileExists` will be a multi-line string containing all matches, still triggers the "already exists" error with a confusing multi-path message, or if `fd-all` output is empty but pattern was empty, it matches everything and always errors.

- **Where:**

```bash
# mkpython:39-45
fileExists="$(fd-all "${nameNoExt}" -e py "${dir}")"
scriptExists=$(fd-all "${nameNoExt}" -d 1 "${SCRIPTS_DIR}")

if [[ -n "${fileExists}" ]]; then
  log-error "File ${name} already exists at ${fileExists}"
```

- **Why it's wrong:** existence check should be an exact path test (`[[ -e "${dir}/${nameNoExt}" ]]` or `[[ -e "${SCRIPTS_DIR}/${nameNoExt}" ]]`) or an exact-name `fd` query (`fd --exact`/`^nameNoExt$`), not a substring search; substring matching causes false positives and multi-line `log-error` payload may be truncated by `log-error`'s SIGUSR1 kill before the user sees full list.

- **Fix:**

```bash
if [[ -e "${dir}/${nameNoExt}" ]]; then
  log-error "File ${name} already exists at ${dir}/${nameNoExt}"
elif [[ -e "${SCRIPTS_DIR}/${nameNoExt}" ]]; then
  log-error "Script ${nameNoExt} already exists at ${SCRIPTS_DIR}/${nameNoExt}"
fi
# or if fd must be used: fd-all -e py "^${nameNoExt}$" with --globexact semantics, and handle multi-line with mapfile
```

#### Design issues

- **What happens:** `cd "${projectDir}" || log-error ...` followed by `uv init` and `uv venv` assumes `SCRIPTS_DIR` is set; `SCRIPTS_DIR` is never defaulted in this script (`: "${SCRIPTS_DIR:=${HOME}/scripts}"` is missing), so in a fresh shell where `hooks/path.sh` hasn't been sourced, `dir="/python"` (empty prefix) and `scriptPath="/pdfx"` absolute-from-root, both wrong.

- **Where:** `mkpython:32,48-51`

- **Why it's design:** every other script that uses `SCRIPTS_DIR` either inherits it from `include`'s fallback or explicitly defaults it (see `init.sh:65`); relying on an unexported env var without fallback is fragile.

- **Fix:**

```bash
: "${SCRIPTS_DIR:=${HOME}/scripts}"
dir="${SCRIPTS_DIR}/python"
```

- **What happens:** `"${EDITOR:-nano}" "main.py"` opens an editor unconditionally (blocking) even when invoked non-interactively (e.g., from another script or CI); no `--no-edit` flag or `isInteractiveShell` guard.

- **Why it's design:** blocks automation; other scaffolders (`mkscript`) respect `EDITOR=cat` for agent use (see `AGENTS.md:79` `EDITOR=cat mkscript -q -f`), but `mkpython` hard-codes interactive edit.

#### Minor / style

- `strip-ext` and `fd-all` are internal scripts available via `hooks/path.sh` `PATH` injection — they are correctly not declared in `DEPENDENCIES` (only external packages are declared), so don't flag as missing deps.
- Typo `log-success "Script ... created succefully!"` — "succefully" → "successfully".
- `touch "${scriptPath}"` uses the `helpers.sh:263 touch` wrapper that creates parent dirs, but `scriptPath="${SCRIPTS_DIR}/${nameNoExt}"` parent dir is `SCRIPTS_DIR` itself (exists), so plain `command touch` would also work; not a bug, just indirection.

#### Confirmed correct (potential false positives)

- `set -eo pipefail` + `trap 'exit 1' SIGUSR1` present (lines 22-23) — correct per brief §4 even though this script doesn't kill itself.
- `checkDep` pipe syntax `fd | fdfind (fd-find)` correctly handled as alternatives with package override — not a syntax error (brief §2).
- `scriptContent()` heredoc with `cat <<'EOF'` quoting prevents expansion of `$0`/`$@` until the generated wrapper runs `runpy "$0" "$@"` — quoted `'EOF'` is intentional, not missing expansion.

---

### `rofi/rofi-list`

**Path:** `/home/othman/scripts/rofi/rofi-list`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): List all scripts in the scripts directory and copy the selected script to the clipboard
**Declared dependencies:** `rofi`, `fd`
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **What happens:** `scriptPaths` loop uses unquoted `for script in ${scriptPaths}` split on `IFS=$'\n'` to iterate basenames; if any script path contains spaces, it splits incorrectly, and `get-desc "${script}"` is called with a basename that may not resolve via `command -v` if `hooks/path.sh` hasn't populated `PATH` yet.

- **Where:**

```bash
# rofi/rofi-list:35-43
scriptPaths=$(fd.sh . -t f -t l -t x --full-path "${SCRIPTS_DIR}" | awk -F '/' '{print $NF}')
IFS=$'\n'
for script in ${scriptPaths}; do
  desc=$(get-desc "${script}")
```

- **Why it's design:** fragile iteration — `fd.sh` output is full paths, but immediately stripped to basenames via `awk`, losing directory disambiguation (two scripts with same basename in different subdirs collide), and basename-only `get-desc` relies on `PATH` hook; a `while IFS= read -r` over full paths would preserve uniqueness and avoid `IFS` juggling.

- **Fix:**

```bash
declare -a scripts
while IFS= read -r fullPath; do
  base="${fullPath##*/}"
  desc="$(get-desc "${fullPath}")"   # pass full path, not basename
  [[ -n "${desc}" ]] && desc=" - ${desc}"
  scripts+=("${base}${desc}")
done < <(fd.sh . -t f -t l -t x --full-path "${SCRIPTS_DIR}")
```

- **What happens:** `clipcopy` is invoked (`echo "${choice}" | clipcopy`) but not declared in `DEPENDENCIES` and not checked via `checkDeps`; on a system without `xclip`/`wl-copy` the pipeline fails silently (pipe exit status is `clipcopy`'s, but `set -o pipefail` will propagate, yet user sees no `installDep` prompt to install `xclip | wl-copy (wl-clipboard)` like other clipboard scripts do).

- **Where:**

```bash
# rofi/rofi-list:17-19 (deps)
# - rofi
# - fd
# ...
# rofi/rofi-list:61
  echo "${choice}" | clipcopy
```

- **Why it's design:** inconsistency with other clipboard consumers (clipcopy's own deps are `xclip | wl-copy (wl-clipboard) | copyq`); omitting it from the block means `checkDeps` won't offer to install it.

- **Fix:** Add to DEPENDENCIES block:

```bash
# - rofi
# - fd
# - clipcopy
# (or directly the alternatives clipcopy delegates to)
```

- **What happens:** `grep -v 'echo "${desc}"' | grep -v 'replace "" ""'` filters are literal strings that appear in `get-desc`/`replace.sh` fallback outputs when those helpers emit shell snippets on error; this hides real failures instead of surfacing them via `log-error`.

- **Why it's design:** error suppression via grep is brittle — if helper error messages change, filter misses; better to check `get-desc` exit status or filter empty `desc` before appending.

#### Minor / style

- `OLD_IFS=${IFS}` / `IFS=${OLD_IFS}` save/restore is correct but `IFS=$'\n'` between them affects the unquoted `${scriptPaths}` expansion; quoting style `[[ -n ${desc} ]]` and `[[ -n ${choice} ]]` omits quotes inside `[[ ]]` — works in bash `[[` (no word splitting) but inconsistent with repo's quoted `[[ -n "${var}" ]]` style elsewhere.
- `sort` without `LC_ALL=C` may produce locale-dependent ordering; minor for UI list.
- `// shellcheck disable=2016 # idk why these keep appearing` — comment acknowledges false positives from literal `'echo "${desc}"'` greps, but doesn't fix root cause.

#### Confirmed correct (potential false positives)

- `set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `source "$(include "lib/helpers.sh")"` + `source "$(include "check-deps")"` + `checkDeps "$0"` ordering — matches `clangc` reference pattern (§7), not a missing-include bug.
- `fd.sh` usage (`fd.sh . -t f -t l -t x --full-path "${SCRIPTS_DIR}"`) correctly delegates to the repo's `fd.sh` wrapper that adds `--hidden`/`--exclude .git` etc. before appending user args — not a raw `fd` call that bypasses excludes.
- `choice=$( ... | rofi -dmenu ...) || terminate` — `terminate` (`helpers.sh:61` → `logInfo …; exit 0`) is the intended graceful-cancel path when rofi exits non-zero (user pressed Esc), not an error suppression bug.

---

### `external/testfonts`

**Path:** `/home/othman/scripts/external/testfonts`
**Declared purpose** (from header comment): Extended fonts testing (with ligatures & Nerd Fonts) — `File: testfonts / Description: Extended fonts testing (with ligatures & Nerd Fonts)`
**Declared dependencies:** none (external/demo script, no signature block — allowed per brief §6)
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **What happens:** style list defaults from `$2` not `$1`, and `$1` is never referenced — invoking `testfonts bold` (single arg) still uses default `normal bold italic` instead of the requested `bold`; `testfonts "MyFont"` (font name) is silently ignored.

- **Where:**

```bash
# external/testfonts:30-31
STYLES="${2:-normal bold italic}"
# $1 never used; for style in ${STYLES} at line 44
```

- **Why it's design:** confusing CLI — if the script intended to accept an optional font argument as `$1` and style list as `$2`, it should document that (e.g., `font="${1:-}"`) and shift; as written, single-arg invocation is a no-op for style selection.

- **Fix:**

```bash
# if font arg is intended:
FONT="${1:-}"
STYLES="${2:-normal bold italic}"
# or if style is first arg:
STYLES="${1:-normal bold italic}"
```

#### Minor / style

- No `set -eo pipefail` / `trap` / `include` / `checkDeps` / `cmdarg` — acceptable for `external/` demo scripts (house style is not required for vendored/external helpers; see `external/colorblocks` precedent in batch-05), not a missing-house-style bug, but worth noting for consistency if this were ever promoted to top-level.
- `for style in ${STYLES}; do` unquoted is intentional word-splitting for the style list; quoting would prevent iteration — correct as written, not a SC2086 bug.
- `echo -e "\033[${code}m${TEXT}\033[0m"` uses `echo -e` which is non-portable; `printf '\033[%sm%s\033[0m\n' "${code}" "${TEXT}"` would be more robust, but in this bash-only repo `echo -e` works.

#### Confirmed correct (potential false positives)

- Missing `# --- DESCRIPTION --- #` / `# --- DEPENDENCIES --- #` signature block is allowed per brief §6 (scripts with no deps may omit the block or leave it empty; external demos often have a plain header comment instead).
- Hard-coded ANSI escape sequences (`\033[1;34m`, `\033[${code}m`) are not raw ANSI logging violations — this is a font-test demo that *must* emit ANSI to show styling; repo's `log-*`/`printRed` rule (§3) applies to CLI apps, not to visual test output.
- `NERD_SYMBOLS` containing private-use Unicode (`  …`) is intentional test data for Nerd Fonts, not garbage bytes.

---

### `net-speed`

**Path:** `/home/othman/scripts/net-speed`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Monitors and displays the network download and upload speeds in Kbps for the active network interface
**Declared dependencies:** `cat`, `awk`, `printf`
**Verdict:** `Needs fixes`

#### Critical bugs

None found.

#### Design issues

- **What happens:** if `net-interface` returns empty (no active route, offline, VPN down), `interface=""` and `cat /sys/class/net//statistics/rx_bytes` fails with `No such file or directory`; due to `set -e` the script exits immediately with a raw `cat` stderr, not a `log-error` with context, and the `while true` monitor never starts.

- **Where:**

```bash
# net-speed:32-35
interface="$(net-interface)"

downOld="$(cat /sys/class/net/"${interface}"/statistics/rx_bytes)"
upOld="$(cat /sys/class/net/"${interface}"/statistics/tx_bytes)"
```

- **Why it's wrong:** silent crash on offline — caller gets no diagnostic that interface detection failed, and the script's `DEPENDENCIES` don't mention `net-interface` (internal script) so `checkDeps` won't ensure it exists; `net-interface` itself exits 0 with empty output on failure (see `net-interface` review), so the failure is not propagated as a non-zero status that `set -e` could catch before `cat`.

- **Fix:**

```bash
interface="$(net-interface)"
[[ -n "${interface}" ]] || log-error "No active network interface found"
[[ -r "/sys/class/net/${interface}/statistics/rx_bytes" ]] || log-error "Interface '${interface}' has no rx_bytes"
downOld="$(<"/sys/class/net/${interface}/statistics/rx_bytes")"
upOld="$(<"/sys/class/net/${interface}/statistics/tx_bytes")"
# also declare internal dep: # - net-interface  (or handle via command -v check)
```

- **What happens:** declares `cat`, `awk`, `printf` as dependencies — all are coreutils/`gawk` basics that the `AGENTS.md` Dependency Declaration Format explicitly says to *exclude* (`Exclude coreutils and basic commands available on any distro (e.g., grep, sed, awk, cut, tr, cat, echo)`).

- **Where:** `net-speed:16-19` `# - cat` etc.

- **Why it's design:** clutters `checkDeps` with packages that are always present and will never be installed via `getPackageManager`; other `net-*` scripts (`net-interface`) correctly list only non-coreutils deps (`ip`, `awk` is even debatable there but `ip` is the real dep).

- **Fix:** Remove the three lines or replace with the actual external dep `net-interface` if dependency tracking of internal scripts is desired:

```bash
# --- DEPENDENCIES --- #
# - net-interface
# --- END SIGNATURE --- #
```

#### Minor / style

- `cat /sys/class/net/...` forks a process per read (4 times per loop iteration); pure bash `$(< "/sys/class/net/${interface}/statistics/rx_bytes")` avoids the fork and is the repo's preferred pattern for reading sysfs (see `helpers.sh` style).
- `eraseLine` is used without a direct `source "$(include "lib/helpers.sh")"` — relies on transitive import via `check-deps` (same fragility noted in `mdclean`).
- `printf " %d Kbps  %d Kbps\n"` uses Nerd Font glyphs (``/``) — correct for `net-speed`'s visual purpose, not a `log-*` color violation.

#### Confirmed correct (potential false positives)

- `set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `source cmdarg` + `checkDeps` → `cmdarg_info` → `cmdarg_parse` ordering matches brief §5 even though this script defines no `cmdarg` flags (zero-flag `cmdarg_parse "$@"` is allowed and `argv` correctly captures positionals — none expected).
- Hard-coded `/sys/class/net/.../statistics/rx_bytes` is not a non-portable path bug — it's the documented Linux sysfs network stats interface, intentional for this Linux-only monitor.
- Infinite `while true; do ... sleep 1; done` is intentional for a live monitor; no `exit` after loop is expected.

---

### `runpy`

**Path:** `/home/othman/scripts/runpy`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Run a Python script from `$SCRIPTS_DIR/python` directory with an optional venv
**Declared dependencies:** `uv`, `fd | fdfind (fd-find)`
**Verdict:** `Critical bug`

#### Critical bugs

- **What happens:** with no arguments, `strip-ext "$1"` receives empty string, `pattern` becomes `//main\.py$` (empty project component), `fd.sh "${pattern}" -p "${dir}"` then returns *every* `main.py` under `python/` (first match is arbitrary), `file` becomes a multi-line list (all projects), `dirname "${file}"` only takes first line's dirname for venv search, and `uv run "${file}" "$@"` is invoked with a newline-separated list as a single argument — fails with a confusing `uv` error instead of `log-error "No project name provided"`. Same empty-name bug as `mkpython`.

- **Where:**

```bash
# runpy:27-30
dir="${SCRIPTS_DIR}/python"

pattern="/$(strip-ext "$1" sh zsh fish bash)/main\.py\$"
file=$(fd.sh "${pattern}" -p "${dir}")

venv=$(fd.sh 'venv$' -t d -p "$(dirname "${file}")" --no-ignore)
```

- **Why it's wrong:** no `(( $# == 0 )) && log-error` guard before using `$1`; `strip-ext` on empty string returns empty via `basename`, so pattern is malformed and `fd.sh` degenerates to a full scan.

- **Fix:**

```bash
(($# == 0)) && log-error "No project name provided"
# or via cmdarg if this were migrated: ((argc < 1)) && log-error ...
pattern="/$(strip-ext "$1" sh zsh fish bash)/main\.py\$"
file="$(fd.sh "${pattern}" -p "${dir}" | head -n 1)"  # if multiple, pick first and warn
[[ -n "${file}" && -f "${file}" ]] || log-error "Project '$(strip-ext "$1" sh zsh fish bash)' not found under ${dir}"
```

- **What happens:** when multiple projects match the pattern (e.g., `py` vs `mypy` substring, or regex meta in project name), `file` contains multiple lines; subsequent `dirname "${file}"` and `uv run "${file}"` receive embedded newlines, so `venv` search directory is wrong and `uv run` fails or runs the wrong project. Also `strip-ext "$1" sh zsh fish bash` does not escape regex meta, so a project named `my.project` produces pattern `/my.project/main\.py$` where `.` matches any char.

- **Where:** same `pattern`/`file` block plus `venv=$(fd.sh 'venv$' -t d -p "$(dirname "${file}")" ...)` and `uv run "${file}"`

- **Why it's wrong:** `fd -p` treats pattern as a *regular expression*, not a fixed string; project names containing `.`, `+`, `*`, `(`, `)`, `[` etc. must be escaped, and results must be handled as an array (`mapfile -t`) with a disambiguation check, not a scalar that silently concatenates matches.

- **Fix:**

```bash
# escape regex metachars in project name
proj="$(strip-ext "$1" sh zsh fish bash | sed -e 's/[][\.*^$+?{}()|]/\\&/g')"
pattern="/${proj}/main\.py\$"
mapfile -t files < <(fd.sh "${pattern}" -p "${dir}")
(( ${#files[@]} == 0 )) && log-error "Project '${proj}' not found"
(( ${#files[@]} > 1 )) && log-warning "Multiple matches, using first: ${files[*]}"
file="${files[0]}"
```

#### Design issues

- **What happens:** `fd.sh 'venv$' -t d -p "$(dirname "${file}")" --no-ignore` searches for a directory ending in `venv`; `uv venv` by default creates `.venv` (dot-prefixed), which matches `venv$` via substring, but a project that also contains a subdirectory like `myvenv` or `venv-old` would be matched first (fd order undefined), activating the wrong environment.

- **Where:**

```bash
# runpy:32-33
venv=$(fd.sh 'venv$' -t d -p "$(dirname "${file}")" --no-ignore)
activateVenv="${venv}bin/activate"
```

- **Why it's design:** ambiguous venv detection — should search specifically for `.venv` or check `[[ -f "${venv}bin/activate" ]]` after, and handle the case where `file` is empty (`dirname ""` → `.`), which causes `fd.sh` to scan the current working directory recursively.

- **Fix:**

```bash
venv="$(fd.sh '^\.venv$' -t d -p "$(dirname "${file}")" --no-ignore | head -n 1)"
# or: venv="$(dirname "${file}")/.venv"; [[ -f "${venv}/bin/activate" ]] && ...
activateVenv="${venv%/}/bin/activate"  # handles trailing slash robustly
[[ -f "${activateVenv}" ]] || venv=""
```

- **What happens:** `SCRIPTS_DIR` is used without defaulting (`dir="${SCRIPTS_DIR}/python"`); in a non-interactive shell where `hooks/path.sh` hasn't been sourced, `dir="/python"` (root) and `fd.sh` scans the wrong tree.

- **Why it's design:** same `SCRIPTS_DIR` fragility as `mkpython` — should ` : "${SCRIPTS_DIR:=${HOME}/scripts}"`.

#### Minor / style

- `strip-ext` and `fd.sh` are internal `PATH` wrappers, correctly not listed in `DEPENDENCIES` (only `uv` and `fd | fdfind` are external; consistent with house §2).
- `activateVenv="${venv}bin/activate" # fd output adds a trailing /` comment is accurate for `fd`'s default output — but if `venv` is empty, `activateVenv="bin/activate"` becomes a relative path that's tested with `[[ -f "bin/activate" ]]` in the current `pwd`, not in `python/<proj>/`; minor but worth guarding with `[[ -n "${venv}" ]]` first.

#### Confirmed correct (potential false positives)

- `set -eo pipefail` + `trap 'exit 1' SIGUSR1` without sourcing `lib/cmdarg.sh` is intentional — this script does not use `cmdarg` parsing (it uses raw `$1`/`shift`), so not sourcing `cmdarg` is correct, not a missing-include bug.
- `shift` before `withVenv "$@"` correctly removes the project name from the argument list passed to the Python target — not an off-by-one.
- `source "${activateVenv}" || log-error ...` guarded sourcing is correct; `log-error`'s `kill -SIGUSR1 "${PPID}"` will terminate the `runpy` parent that trapped SIGUSR1, propagating the failure without manual error checks.

---

### `md2docx`

**Path:** `/home/othman/scripts/md2docx`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Converts a Markdown file to DOCX using pandoc, optionally applying a reference template from MRT, with success and error logging
**Declared dependencies:** `pandoc (pandoc-cli)`, `sed`
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **What happens:** script reads `file="${argv[0]}"` without first validating `argc`; with no arguments `file` is empty, `[[ -f "" ]]` fails, and user sees `log-error "File '' does not exist!"` rather than a clear usage error. Also `filename="${file%.*}"` on empty string yields empty, but the error path already exited via `log-error`'s SIGUSR1 kill, so the misleading message is the only diagnostic.

- **Where:**

```bash
# md2docx:30-47
file="${argv[0]}"

if [[ -f "${file}" ]]; then
  filename="${file%.*}"
  ...
else
  log-error "File '${file}' does not exist!"
fi
```

- **Why it's design:** every other `cmdarg` script with a required positional validates `((argc < 1)) && log-error "No input files were provided."` (`clangc:44`); missing guard here is inconsistent and produces a confusing empty-quoted filename in the error.

- **Fix:**

```bash
((argc < 1)) && log-error "No input file provided"
file="${argv[0]}"
[[ -f "${file}" ]] || log-error "File '${file}' does not exist!"
filename="${file%.*}"
# then pandoc logic without nesting
```

#### Minor / style

- Declares `sed` in `DEPENDENCIES` but never invokes `sed` directly; `pandoc` itself doesn't require an explicit `sed` dep. Per `AGENTS.md` "exclude coreutils" rule, `sed` (like `grep`/`awk`/`cat`) would normally be excluded, but here it's at least a real extra dep that's unused — either remove it or keep if `pandoc` filtering via `sed` is anticipated.
- Filename stripping `${file%.*}` removes only the last extension: `notes.old.md` → `notes.old.docx`, `README` (no dot) → `README.docx` (no extension to strip). For markdown this is correct, but a file `my.doc.md` becomes `my.doc.docx` rather than `my.docx` — acceptable, but `basename`-style stripping would be more predictable if multiple dots are expected.
- Success message `log-success "File '${file}' converted successfully!"` logs the input path, not the output `${filename}.docx` — minor UX mismatch (user may want to know output path).

#### Confirmed correct (potential false positives)

- `pandoc (pandoc-cli)` dependency syntax — `pandoc` binary with package override `pandoc-cli` (Debian/Ubuntu split) correctly handled by `checkDep`'s `grep -oP '$\K[^)]*(?=$)'` extraction (brief §2); not a syntax error.
- `if [[ -n "${MRT}" && -f "${MRT}" ]]; then pandoc ... --reference-doc="${MRT}"` — checking env var `MRT` (Markdown Reference Template) for non-empty and file existence before adding `--reference-doc` is correct; empty or missing `MRT` cleanly falls back to plain `pandoc`.
- `|| log-error "Unknown Error Occured"` after `pandoc` — `log-error` kills the parent via SIGUSR1, so the subsequent `log-success` is unreachable on failure; not a missing `else` bug (the `||` is the error path, `log-success` is the success path).

---

### `net-interface`

**Path:** `/home/othman/scripts/net-interface`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Retrieves the active network interface by checking the route to external IPs
**Declared dependencies:** `ip`, `awk`
**Verdict:** `Needs fixes`

#### Critical bugs

None found.

#### Design issues

- **What happens:** interface extraction uses `awk '{print $5;exit}'` which is position-dependent; `ip route get 1.1.1.1` output varies between `1.1.1.1 via 192.168.1.1 dev wlp0s0 ...` (`$5` = `wlp0s0`, correct) and `1.1.1.1 dev eth0 src ...` (`$3` = `eth0`, `$5` = `src`, wrong) or with `cache`/`proto` prefixes, so offline/VPN routes can cause the script to echo `src` or `via` as the interface, which `net-speed` then tries to read from `/sys/class/net/src/statistics/...`.

- **Where:**

```bash
# net-interface:31-36
interface="$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5;exit}')"
...
  interface="$(ip route get 8.8.8.8 2>/dev/null | awk '{print $5;exit}')"
```

- **Why it's wrong:** brittle field position — `ip route get` is not column-stable; the robust parse is to search for the `dev` keyword.

- **Fix:**

```bash
interface="$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev") print $(i+1)}')"
[[ -n "${interface}" ]] || interface="$(ip route get 8.8.8.8 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev") print $(i+1)}')"
```

- **What happens:** when no route is found (offline, no default gateway), script prints nothing and `exit 0`; caller `net-speed` receives empty string, then `cat /sys/class/net//statistics/...` fails with a raw `cat` error instead of a diagnostic. Silent success on failure is a contract violation.

- **Where:**

```bash
# net-interface:33-40
if [[ -n "${interface}" ]]; then
  echo "${interface}"
else
  interface="$(ip route get 8.8.8.8 2>/dev/null | awk '{print $5;exit}')"
  if [[ -n "${interface}" ]]; then
    echo "${interface}"
  fi
fi

exit 0
```

- **Why it's design:** should signal failure to the caller — either `exit 1`/`log-error` when empty, or at least `exit 2` so `set -e` in the caller can catch it without needing to test for empty string.

- **Fix:**

```bash
if [[ -n "${interface}" ]]; then
  echo "${interface}"
else
  log-error "No active network interface found"  # exits 1 via SIGUSR1, or: exit 1
fi
# or if silent-empty is intentional for scripting, document and make caller check:
# [[ -n "${interface}" ]] || exit 1
```

#### Minor / style

- Declares `awk` as a dependency despite `AGENTS.md` saying to exclude coreutils basics like `awk` — `ip` is the real external dep; `awk` listing is redundant but harmless (see `net-speed` same issue). Consistent violation across `net-*` scripts.
- Hard-codes two external IPs (Cloudflare `1.1.1.1`, Google `8.8.8.8`) for probing — fine for IPv4, but IPv6-only hosts will always fall through; adding a `1.1.1.1` → `2606:4700:4700::1111` fallback could be considered, but out of scope for this batch.
- `exit 0` at EOF is explicit but redundant after successful `echo`; not a bug, just style (other scripts rely on implicit `exit 0`).

#### Confirmed correct (potential false positives)

- `set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `checkDeps "$0"` before `cmdarg` — correct `clangc`-style ordering; `ip` dep is correctly declared as `# - ip` (no package override needed, `ip` package is `iproute2` on Debian but `command -v ip` exists regardless, and `getPackageManager` fallback handles derivatives).
- `ip route get ... 2>/dev/null` suppressing stderr is intentional — route lookup may emit `RTNETLINK answers: Network is unreachable` when offline, which should not pollute stdout; swallowing stderr is correct, not error suppression.
- `cmdarg_info "header" "$(get-desc "$0")"` with zero `cmdarg` definitions and `cmdarg_parse "$@"` is the valid no-flags CLI pattern (see `net-speed` same shape) — not a missing `cmdarg` definition bug.

---

## Batch Summary

- **Scripts reviewed:** 9 / 9
- **Critical bugs:** `mkpython` — missing `argc` validation allows empty `name` → `strip-ext ""` → `fd-all ""` full scan + `uv init --name ""` cryptic failure; `runpy` — missing `$#` validation allows empty `pattern="//main\.py$"` full scan, multi-line `file` mishandling and unescaped regex meta in project name.
- **Design issues worth escalating:** `net-interface` — fragile `awk '{print $5}'` field position (should search for `dev` keyword) and silent `exit 0` on empty (caller `net-speed` then crashes on `cat /sys/class/net//...`) — breaks the `net-speed`/`net-interface` pair contract; `net-speed` — no empty-interface guard before `cat /sys/class/net/...` and spurious `cat`/`awk`/`printf` coreutils deps; `get-package-manager` — drift from `helpers.sh:getPackageManager` (`*mint*`/`*cachy*` ID_LIKE fallbacks missing) and 120-line duplication that should delegate to helpers.
- **Cross-cutting patterns observed in this batch** (same bug/pattern repeated across multiple scripts in this batch only; batch-level, not repo-wide):
  - **Missing positional-argument guards:** `mkpython`, `runpy`, and `md2docx` all read `argv[0]`/`$1` without `((argc < 1))`/`(( $# == 0 ))` checks (like `clangc:44` does), leading to empty-name → `fd-all ""` full-scan or misleading `File '' does not exist!` errors — single fix pattern to propagate.
  - **`SCRIPTS_DIR` without default:** `mkpython` and `runpy` use `"${SCRIPTS_DIR}/python"` without `: "${SCRIPTS_DIR:=${HOME}/scripts}"` fallback, so both break identically in shells where `hooks/path.sh` hasn't been sourced.
  - **Transitive `helpers.sh` reliance:** `mdclean` and `net-speed` use `isPositive`/`eraseLine` from helpers via `check-deps` indirection rather than direct `source "$(include "lib/helpers.sh")"` — fragility repeated.
  - **`awk` as declared dependency despite coreutils exclusion:** `net-speed` (`cat`/`awk`/`printf`) and `net-interface` (`awk`) both list coreutils in `DEPENDENCIES`, contrary to `AGENTS.md` "exclude coreutils" rule — cosmetic but batch-consistent.
  - **Brittle `fd` substring matching:** `mkpython` (`fd-all "${nameNoExt}"`) and `runpy` (`fd.sh "${pattern}"`) both treat `fd` regex/substring as exact name, causing false positives on substrings and regex-meta issues; same root: should use exact-path checks or escaped regex + `mapfile` disambiguation.
- **Open questions** (design intent unclear, needs the repo owner's input rather than a guess):
  - Should `get-package-manager` remain a standalone duplicate of `helpers.sh:getPackageManager` (142 vs 140 lines, already drifted) or be deleted/replaced with `echo "$(getPackageManager)"` thin wrapper to keep a single source of truth? Current divergence suggests single source is safer.
  - For `net-interface` offline case, should it `log-error`/`exit 1` (fail fast, breaking `net-speed`'s `set -e`) or intentionally `exit 0` with empty output for scripting composability (caller checks `[[ -n $(net-interface) ]]`)? Current `net-speed` assumes non-empty, so contract needs explicit decision.
  - Is `external/testfonts`'s `STYLES="${2:-...}"` intentional two-arg API (`$1`=font, `$2`=styles) that was never implemented, or a `$1`→`$2` off-by-one bug? No caller in repo references it — can it be simplified to `STYLES="${1:-normal bold italic}"`?
  - Should `clipcopy` be added to `rofi/rofi-list`'s `DEPENDENCIES` as `xclip | wl-copy (wl-clipboard) | copyq` (like other clipboard scripts), or is `clipcopy` considered an internal `PATH` tool that doesn't need declaration? Consistency with other `rofi-*` scripts needed.

---

## Evidence appendix (optional — supporting reads beyond batch files)

- Core: `include:18-26` (`SCRIPTS_DIR` fallback, `realpath -m`, `source "$(include ...)"`), `lib/cmdarg.sh:7-53` (boolean `true`/`false` literals, `[]`/`{}` array/hash), `lib/helpers.sh:67-84,86-208,212-348` (`getPackageManager` distro matrix incl. `*mint*`/`*cachy*`, `isPositive`/`eraseLine`/`supportsColor`), `lib/loggers.sh:322-341` (`colorOnlyPrefix`), `check-deps:21-52,126-159` (`checkDep` pipe/override, `getDeps` `x-none`), `log.sh:29-43` (`LEVEL_COLORS`), `get-desc:42-52`/`get-deps:37-38` (`sed` block), `init.sh:42-88` (`fd`→`fdfind` symlink), `hooks/path.sh:21-57` (`fd` scan/cache/PATH), `clangc:21-67` (reference ordering + `((argc < 1))` guard + namerefs).
- Batch: `get-package-manager:1-142`, `mdclean:1-82`, `mkpython:1-74`, `rofi/rofi-list:1-66`, `external/testfonts:1-62`, `net-speed:1-54`, `runpy:1-49`, `md2docx:1-47`, `net-interface:1-42`, plus `strip-ext:1-44`, `fd.sh:1-43`, `fd-all:1-22` for `mkpython`/`runpy` call-graph validation, and `docs/code-reviews/batch-05.md:319-390` for `fd-all` precedent on `fd | fdfind` dependency expectations.

