# Batch Review: 16 of 22

**Scripts in this batch:** benchmark, shellfmt, biome-check, clangc, no-orphans, remove-blanks, insert-selection, kill-window, strip-ext, env-qoutes
**Batch composition:** grab-bag (10 scripts, 655 lines, under 12 cap, no large >150 except benchmark 127) — Mix of benchmark, shellfmt, biome-check, clangc, no-orphans — no single family, header note grab-bag.
**Reviewer:** subagent-16
**Date:** 2026-08-21

---

## House Style Reference (do not flag these as bugs)

Before reviewing, confirm you've internalized these repo conventions. Restate them here in one line each to prove the context loaded correctly:

- Dependency declaration format (`# - binary | binary2 (pkg-override)`) and how `checkDep` resolves it: deps listed as `# - exe | alt (pkg)` between SIGNATURE markers; `checkDep` splits on `|`/Trim/`awk '{print $1}'`, `command -v` each alt and returns 0 if any found, else echoes `pkg` override or first exe for `installDep`.
- Logging convention: `log-*` wrapper scripts are primary, camelCase `log*` functions in `lib/helpers.sh` are fallback: standalone `log-debug`/`log-info`/`log-error` etc. dispatch via `log.sh`+`lib/loggers.sh`; `lib/helpers.sh` camelCase `logDebug`/`logError` are in-process fallback fork-free — both canonical, not dead code.
- `trap 'exit 1' SIGUSR1` + `kill -SIGUSR1 "${PPID}"` propagation chain purpose: every script traps SIGUSR1 → exit 1; only `log-error` kills parent PID with SIGUSR1 (guarded by `! isInteractiveShell && ! noKill`) to propagate fatal error up call chain without exit-code checks.
- `cmdarg.sh` argument-parsing pattern used across scripts: `source "$(include "lib/cmdarg.sh")"` → `cmdarg_info "header" "$(get-desc "$0")"` → pre-declare arrays `declare -a/ -A` → `cmdarg "v"`/`"m:"`/`"o?"`/`"a?[]" ` → `cmdarg_parse "$@"` → read `cmdarg_cfg['key']` (booleans literal `true`/`false`) and `argv`/`argc`.
- `get-desc` / `get-deps` signature-block parsing rules: `sed -n` between `# --- DESCRIPTION --- #` … `# --- DEPENDENCIES --- #` … `# --- END SIGNATURE --- #`; missing DESCRIPTION or DEPENDENCIES block is allowed (`x-none` → skip), `get-desc` terminates on either DEPENDENCIES or END SIGNATURE.
- `init.sh` / `hooks/path.sh` symlink and PATH-registration workflow: `init.sh` verifies `SCRIPTS_DIR`, `fd|fdfind` symlink, idempotently appends `source hooks/path.sh` to bashrc/zshrc; `hooks/path.sh` is sourced at shell start, `fd`-scans executables, caches to `/tmp/path-hook.cache`, rescans on newer dirs, adds each dirname once to PATH.
- Reference pattern from `clangc` (what "correct" looks like in this repo): `set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `source cmdarg.sh` + `source lib/compile.sh` + `source check-deps` + `checkDeps "$0"` → `cmdarg_info` → pre-declare `compiler_args` → `cmdarg "c"`/`"o?"`/`"a?[]"`/`"q"` → `cmdarg_parse "$@"` → `((argc<1))&&log-error` → array-build → delegate via namerefs to `compile_and_run`.

---

## Script Reviews

### `benchmark`

**Path:** `/home/othman/scripts/benchmark`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Benchmarks a command by running it multiple times and collecting statistics
**Declared dependencies:** bc, awk
**Verdict:** `Critical bug`

#### Critical bugs

- **What happens:** Every timing aggregation and comparison branch throws `Bad substitution` at runtime and produces no output; `total:` line never prints. Script exits non-zero inside `bench_cmd`.
- **Where:**
```bash
# benchmark:58
  elapsed=${ awk "BEGIN { print ${end} - ${start} }"; }
# benchmark:60
  awk -v label="${ shellJoinHumanQuote "$@"; }" '
# benchmark:81
  printf "  total: %s\n" "${ sec2time "${elapsed}" --short; }"
# benchmark:106,108,111,112
  out1=${ bench_cmd "${cmd1[@]}"; }
  avg1=${ grep '^AVG=' <<<"${out1}" | cut -d= -f2; }
  out2=${ bench_cmd "${cmd2[@]}"; }
  avg2=${ grep '^AVG=' <<<"${out2}" | cut -d= -f2; }
```
- **Why it's wrong:** `${ ... ; }` is Bash parameter expansion, not command substitution. At parse time `bash -n` passes, at runtime Bash tries to expand parameter named ` awk "BEGIN { print ` or ` shellJoinHumanQuote "$@"; ` and fails `Bad substitution`. Intent was `$(cmd)`. Same systematic typo across 7 call sites. Also `elapsed` computed incorrectly due to `${end}` expansion inside double-quoted `"BEGIN {print ${t2} - ${t1}}"` — but that inner expansion is correct; outer `${ awk ... }` is not.
- **Fix:**
```bash
  elapsed=$(awk "BEGIN { print ${end} - ${start} }")

  awk -v label="$(shellJoinHumanQuote "$@")" '

  printf "  total: %s\n" "$(sec2time "${elapsed}" --short)"

  out1=$(bench_cmd "${cmd1[@]}")
  avg1=$(grep '^AVG=' <<<"${out1}" | cut -d= -f2)
  out2=$(bench_cmd "${cmd2[@]}")
  avg2=$(grep '^AVG=' <<<"${out2}" | cut -d= -f2)
```
- **What happens:** comparison `printf` silently drops third argument, and `bc` declared but never used.
- **Where:**
```bash
# benchmark:115-122
    BEGIN {
      if (a1 < a2) {
        printf "\n\"%s\"\n is %.2fx faster\n", c1, a2 / a1, c2
      } else {
        printf "\n%s\n is %.2fx faster\n", c2, a1 / a2
      }
    }
```
- **Why it's wrong:** First branch format has 2 verbs (`%s`, `%.2f`) but 3 args (`c1`, `a2/a1`, `c2`) — `c2` discarded. Second branch missing quotes around `%s`. `bc` is declared dep but script uses only `awk` for math.
- **Fix:**
```bash
      if (a1 < a2) {
        printf "\n\"%s\" is %.2fx faster than \"%s\"\n", c1, a2 / a1, c2
      } else {
        printf "\n\"%s\" is %.2fx faster than \"%s\"\n", c2, a1 / a2, c1
      }
```
Or remove unused `bc` from deps.

#### Design issues

- **What happens:** No `set -eo pipefail` despite house style (only `trap` at `benchmark:21`). Failures in `checkDeps`/`has-bash-version` won't abort early.
- **Where:**
```bash
# benchmark:21
trap 'exit 1' SIGUSR1
```
Missing preceding `set -eo pipefail`.
- **Why it's wrong:** All canonical scripts (e.g., `clangc:21-22`) use both. `has-bash-version 5 3` depends on `set -e` to exit on mismatch.
- **Fix:** Add `set -eo pipefail` before trap.

- **What happens:** `sec2time` (from `lib/helpers.sh`? not found) used without being declared or sourced; `benchmark` sources `helpers.sh` but `helpers.sh` has no `sec2time` — lookup fails at runtime. Also `bc`/`awk` dep list includes `bc` unused, misses `sec2time`/`shellJoinHumanQuote` (helpers) which are implicit via helpers include.
- **Where:**
```bash
# benchmark:81
  printf "  total: %s\n" "${ sec2time "${elapsed}" --short; }"
```
- **Why it's wrong:** Hidden dependency. If `sec2time` is elsewhere (e.g., `lib/time.sh`) it must be sourced/declared.
- **Fix:** `source "$(include "lib/time.sh")"` or implement inline, or remove `sec2time` and print raw seconds.

- **What happens:** `bench_cmd` traps `RETURN`+`EXIT` with deferred expansion `trap 'rm -f "$tmp"' RETURN EXIT` — `$tmp` is `local` and `EXIT` fires after function returns when `tmp` locals are gone, leaving stale `/tmp/tmp.*` on early exit.
- **Where:**
```bash
# benchmark:48
  trap 'rm -f "$tmp"' RETURN EXIT
```
- **Why it's wrong:** Single-quoted trap defers `$tmp` expansion until trap fires; on `EXIT` `tmp` is out of scope. Should expand at definition time.
- **Fix:** `trap "rm -f '${tmp}'" RETURN EXIT` or `trap 'rm -f "${tmp:-}"' EXIT` outside function.

#### Minor / style

- `trap 'rm -f "$tmp"'` inside function overwrites global `trap 'exit 1' SIGUSR1`? No, different signals — okay but `RETURN` trap stacking may hide caller traps.
- `for ((i=0; i < iterations; i++))` uses bashism okay after `has-bash-version 5 3`.
- `awk "BEGIN {print ${t2} - ${t1}}"` injects raw float into awk script — okay for EPOCHREALTIME but `awk -v t1="${t1}" -v t2="${t2}" 'BEGIN{print t2-t1}'` is safer against injection.
- `sec2time` path with `:::` separator logic correctly validates empty commands but `cmd=("${argv[@]}")` shadowed by `local cmd=("$@")` inside `bench_cmd` — harmless shadowing.

#### Confirmed correct (potential false positives)

- `source "$(include "lib/cmdarg.sh")"` / `source "$(include "lib/helpers.sh")"` indirection via `include`+`realpath -m` is house-style `include` resolution — not fragile.
- `trap 'exit 1' SIGUSR1` without matching `kill` in this file is correct; only `log-error` sends SIGUSR1 per house style.
- `cmdarg "n:" "iterations"` required-string pattern (`:` + no default → required) and `isPositiveInt`/`((0 < iterations))` validation matches `cmdarg.sh` contract; booleans as literal `true`/`false` not flagged.
- `has-bash-version 5 3` for `EPOCHREALTIME` is intentional version gate.

---

### `shellfmt`

**Path:** `/home/othman/scripts/shellfmt`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): A script for formatting bash code and fixing common issues in code
**Declared dependencies:** shfmt, shellcheck, patch
**Verdict:** `Needs fixes`

#### Critical bugs

None found.

#### Design issues

- **What happens:** Hidden dependency `tabs2spaces` (and potentially `replace.sh` indirectly) used but not declared; script fails with `command not found` on minimal installs where only declared deps are auto-installed.
- **Where:**
```bash
# shellfmt:76
  tabs2spaces <"${tmpfile}" | write_output
# shellfmt:78
  echo "${formatted}" | tabs2spaces | write_output
```
- **Why it's wrong:** House style requires every external exe between `# --- DEPENDENCIES --- #` markers so `checkDeps` can install. `tabs2spaces` is a repo script (not coreutils) and must be listed.
- **Fix:** Add `# - tabs2spaces` to dependency block, or inline `expand -t 2` / `sed`.

- **What happens:** Hard-coded shellcheck RC path may not exist; `shellcheck --rcfile="${HOME}/.config/.shellcheckrc"` fails silently (stderr → /dev/null) leaving `fileDiff` empty — formatting still succeeds but shellcheck fixes silently skipped. No fallback to repo `.shellcheckrc`.
- **Where:**
```bash
# shellfmt:73
fileDiff=$(shellcheck --rcfile="${HOME}/.config/.shellcheckrc" -f diff "${tmpfile}" 2>/dev/null || true)
```
- **Why it's wrong:** Distro/CI without that file gets no lint fixes, no warning. `clangc` reference uses repo-local config.
- **Fix:** `rc="${HOME}/.config/.shellcheckrc"`; `[[ -f "$rc" ]] && extra="--rcfile=$rc"` else `extra=""`.

- **What happens:** Trap overwrites EXIT without preserving previous; global `trap 'exit 1' SIGUSR1` remains but `trap 'rm -f $tmpfile' EXIT` on `shellfmt:41` is the only EXIT handler — okay but quoting deferred.
- **Where:**
```bash
# shellfmt:40-41
tmpfile="$(mktemp)"
trap 'rm -f $tmpfile' EXIT
```
- **Why it's wrong:** Single quotes defer expansion; `$tmpfile` unquoted inside single-quoted trap will word-split if path contains spaces; also expansion happens at trap time when `tmpfile` still in scope (global) so works, but fragile. Also `/tmp/shellfmt.log` (line 66) is fixed path, race-prone parallel runs.
- **Fix:** `trap "rm -f '${tmpfile}'" EXIT` and `logFile="$(mktemp)"` + same trap.

#### Minor / style

- `input="$(read_input)"` + `echo "${input}" >"${tmpfile}"` loses trailing newlines and interprets backslashes; use `printf '%s' "${input}" >"${tmpfile}"` or `read_input >"${tmpfile}"` directly.
- `write_output` uses `if "${in_place}" && [[ -n "${file}" ]]; then cat >"${file}"` — `${in_place}` expands to `true`/`false` command, quoted as `"${in_place}"` still executes but `if "${in_place}"` with quotes is unnecessary; house style is `if ${cmdarg_cfg['in-place']}; then` unquoted.
- `logFile="/tmp/shellfmt.log"` should be `mktemp`; current stomps concurrent runs.
- `fileDiff=$(shellcheck ... || true)` + `echo "${fileDiff}" | patch -p0 ...` — `patch -p0` expects unified diff rooted at `.`; `-p0` with `--no-backup-if-mismatch` okay but `--forward` might be safer for idempotence.

#### Confirmed correct (potential false positives)

- `source "$(include "lib/cmdarg.sh")"` / `lib/helpers.sh` / `check-deps` chain + `trap 'exit 1' SIGUSR1` + `set -eo pipefail` matches house `clangc` shape — correct.
- `checkDeps "$0"` immediately after sourcing `check-deps` is intentional per house style, not redundant.
- `cmdarg "i" "in-place"` boolean and `cmdarg "f?" "file"` optional-string with no default matches `cmdarg.sh` `?`/no-arg contract; `cmdarg_parse "$@"` exactly required form — correct.
- `log-error --safe "${line}"` in `shellfmt:82` loop is house-style safe error (no `kill -SIGUSR1`) — correctly not propagating as fatal.

---

### `biome-check`

**Path:** `/home/othman/scripts/biome-check`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Runs the check command and fixes changes with biome.js
**Declared dependencies:** biome
**Verdict:** `Needs fixes`

#### Critical bugs

None found.

#### Design issues

- **What happens:** Three hidden executables `is-git-repo`, `git-root`, `fd-by-depth` used but not declared; minimal install with only `biome` will fail with `command not found` despite `checkDeps` passing.
- **Where:**
```bash
# biome-check:46-48
if is-git-repo --safe &>/dev/null; then
  cd "$(git-root)"
  result="$(fd-by-depth --type f biome.json . | head -n 1)"
# biome-check:54
  result="$(fd-by-depth --type f biome.json . | head -n 1)"
```
- **Why it's wrong:** House `checkDep` only installs declared deps. `is-git-repo`/`git-root`/`fd-by-depth` are repo scripts, not coreutils, must be listed.
- **Fix:** Add to DEPENDENCIES: `# - is-git-repo` `# - git-root` `# - fd-by-depth` `# - fd | fdfind (fd-find)` if `fd-by-depth` wraps `fd`.

- **What happens:** `--config-path` receives path to `biome.json` file, not its directory; Biome's `--config-path` expects directory containing config (or file path depending on version — in this repo `biome.json` at project root, passing file may fail or be ignored). Also `[[ -s ${result} ]]` without quotes and `result` is relative to `git-root` then `cd -` returns to original dir, leaving `result` stale relative.
- **Where:**
```bash
# biome-check:64-66
if [[ -s ${result} ]]; then
  unset BIOME_CONFIG_PATH
  cmdArray+=("--config-path=${result}")
fi
```
- **Why it's wrong:** `BIOME_CONFIG_PATH` env is unset then `--config-path=${result}` may point to wrong cwd. Should use `$(dirname "${result}")` or absolute path `$(realpath "${result}")`, and `result` should be absolute (`fd-by-depth` output is relative).
- **Fix:**
```bash
if [[ -s "${result}" ]]; then
  unset BIOME_CONFIG_PATH
  cmdArray+=("--config-path=$(dirname "$(realpath "${result}")")")
fi
```
Quote `result`.

- **What happens:** Boolean flags executed as `"${summary}" &&` with quotes — while `"true"` still executes, it's fragile and style-divergent from house (`if ${cmdarg_cfg['x']}; then`). Also `${summary}` may be `false` → `false &&` short-circuits but exit code 1 with `set -e` could abort before next line.
- **Where:**
```bash
# biome-check:69-70
"${summary}" && cmdArray+=(--reporter=summary)
"${unsafe}" && cmdArray+=(--unsafe)
```
- **Why it's wrong:** With `set -eo pipefail`, `false &&` returns 1; if script had `set -e`, the failed `false` command in `&&` list is not supposed to trigger errexit (Bash exempts `&&`/`||` lists), so okay, but quoting is unnecessary and inconsistent with `clangc` boolean handling.
- **Fix:** `${summary} && cmdArray+=(--reporter=summary)` unquoted, or `if ${summary}; then ...; fi`.

#### Minor / style

- `configFile="${BIOME_CONFIG_PATH:-${HOME}/.config/biome/biome.json}"` computed but never used.
- `declare result` without value is unnecessary; just `result=""`.
- `cd "$(git-root)"` + `cd - &>/dev/null` changes directory twice; prefer `( cd "$(git-root)" && result=... )` subshell to avoid side effects.
- `BIOME_CONFIG_PATH` unset only if `result` found — leaves user-provided `BIOME_CONFIG_PATH` active otherwise, which may be intended but uncomment.

#### Confirmed correct (potential false positives)

- `source "$(include "lib/cmdarg.sh")"` + `source "$(include "check-deps")"` + `checkDeps "$0"` → `cmdarg_info` → `cmdarg "s"`/`"u"` booleans/`"m?"` optional with default `"20"` matches `cmdarg.sh` hash contract — correct.
- `configFile="${BIOME_CONFIG_PATH:-...}"` defaulting idiom is standard.
- `cmdArray+=("${argv[@]}")` forwarding positionals after parsing matches intended `biome check` passthrough.

---

### `clangc`

**Path:** `/home/othman/scripts/clangc`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Compiles and optionally runs C files with customizable compiler arguments
**Declared dependencies:** clang, xxh3sum (xxhash) | xxhsum (xxhash) | sha1sum (coreutils)
**Verdict:** `Clean`

#### Critical bugs

None found.

#### Design issues

None found.

#### Minor / style

- `hasher` fallback logic lives in `lib/compile.sh`/`lib/helpers.sh`; declaring `xxh3sum | xxhsum | sha1sum` alternative chain is correct per house `checkDep` but note `hasher()` function (in helpers) uses same order — consistent.

#### Confirmed correct (potential false positives)

- Full `clangc` shape matches house brief §8 canonical positive example exactly: `set -eo pipefail` + `trap 'exit 1' SIGUSR1` (`clangc:21-22`), `source "$(include "lib/cmdarg.sh")"` (`clangc:24`), `source "$(include "lib/compile.sh")"` (`clangc:25`), `source "$(include "check-deps")"`+`checkDeps` (`clangc:26-27`), `cmdarg_info` + pre-declared `declare -a compiler_args` + boolean/array/optional defs (`clangc:31-36`), `cmdarg_parse "$@"`, `((argc<1)) && log-error`, array-safe nameref delegation to `compile_and_run` — copy-paste correct.
- Dependency line `xxh3sum (xxhash) | xxhsum (xxhash) | sha1sum (coreutils)` with pipe fallbacks and paren package overrides is house-style correct per `checkDep` splitting.
- `declare -a default_flags` / array passing by name (`'default_flags'` etc.) uses Bash namerefs as intended (`# shellcheck disable=SC2034` justified).

---

### `no-orphans`

**Path:** `/home/othman/scripts/no-orphans`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Removes orphan packages using paru
**Declared dependencies:** paru
**Verdict:** `Critical bug`

#### Critical bugs

- **What happens:** User selects packages to KEEP via `gum choose`, but script then **adds** kept packages back into removal list and deduplicates, so kept packages are still removed — inverted logic causes data loss (removes packages user explicitly kept). With `--force` the path is correct, without it it's broken.
- **Where:**
```bash
# no-orphans:47-59
mapfile -t keepPkgs < <(
    gum choose \
      --header='Choose what to KEEP' \
      --no-limit "${removablePkgs[@]}" ||
      log-error "Program terminated"
  )
  removablePkgs+=("${keepPkgs[@]}")
}

mapfile -t pkgsToRemove < <(
  printf '%s\n' "${removablePkgs[@]}" | get-unique
)
```
- **Why it's wrong:** `gum choose` returns items to **keep**, but they are appended to `removablePkgs` and unique-filtered still present. Should **subtract** keep list from removable list. `get-unique` dedupes, doesn't subtract.
- **Fix:**
```bash
mapfile -t keepPkgs < <(
    gum choose --header='Choose what to KEEP' --no-limit "${removablePkgs[@]}" || log-error "Program terminated"
  )
  # subtract keepPkgs from removablePkgs
  declare -A keepMap
  for k in "${keepPkgs[@]}"; do keepMap["$k"]=1; done
  tmp=()
  for p in "${removablePkgs[@]}"; do [[ -z "${keepMap[$p]:-}" ]] && tmp+=("$p"); done
  removablePkgs=("${tmp[@]}")
  # no need for get-unique after subtract, but keep if deps duplicate
  mapfile -t pkgsToRemove < <(printf '%s\n' "${removablePkgs[@]}" | get-unique)
```
Or use `comm` / `grep -vxF`.

#### Design issues

- **What happens:** Hidden deps `gum`, `get-unique` (and transitively `paru -Rps` deps) not declared; script will fail post-`checkDeps` on systems with only `paru`. `joinarr` used indirectly via `check-deps` logError but not needed here.
- **Where:**
```bash
# no-orphans:49 gum choose
# no-orphans:58 get-unique
```
- **Why it's wrong:** House style requires every non-coreutils exe between DEPENDENCIES markers.
- **Fix:** Add `# - gum` `# - get-unique` (or declare `# - gum` + handle fallback if gum missing — prompt via `yesNo`).

- **What happens:** `paru -Qtdq || true` swallow: if no orphans `paru` exits 1, mapfile gets empty, then `((${#orphanPkgs[@]})) || terminate` correctly exits 0 — okay, but comment says "if no orphan packages found, paru fails" acknowledges. However `paru -Rps --print-format "%n"` dry-run may return non-zero if orphans include non-installed deps, unhandled `set -e` will abort before `get-unique`.
- **Where:**
```bash
# no-orphans:37
mapfile -t orphanPkgs < <(paru -Qtdq || true)
# no-orphans:40
mapfile -t removablePkgs < <(paru -Rps --print-format "%n" "${orphanPkgs[@]}")
```
- **Why it's wrong:** Second `mapfile` lacks `|| true`, so `set -e` will exit on `paru -Rps` failure, skipping terminate message.
- **Fix:** `mapfile ... < <(paru -Rps ... || true)` and check `removablePkgs` empty.

#### Minor / style

- `declare -a orphanPkgs removablePkgs keepPkgs pkgsToRemove` then `force="${cmdarg_cfg['force']}"` — `force` undeclared; okay but `force` should be `local` or just use `${cmdarg_cfg['force']}` directly as `${force}` executes `true`/`false`.
- `((${#pkgsToRemove} < 1)) && terminate "No orphan packages..."` — `terminate` exits 0 via `logInfo`; using `terminate` for empty case is okay but double message (also line 38).
- `paru -Rn "${pkgsToRemove[@]}"` without `--noconfirm` vs `paru -Qtdq` earlier; interactive confirmation may be desired — matches `force` semantics via `gum`.

#### Confirmed correct (potential false positives)

- `source "$(include "lib/cmdarg.sh")"` + `source "$(include "check-deps")"` + `trap` + `set -eo pipefail` matches house `clangc` shape.
- `cmdarg "f" "force"` boolean without default correctly defaults to `false` per `cmdarg.sh` §5.
- `checkDeps "$0"` after sourcing is house-correct.
- `paru -Qtdq` / `paru -Rps --print-format "%n"` Arch/paru idiom is correct; not a bug.

---

### `remove-blanks`

**Path:** `/home/othman/scripts/remove-blanks`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Removes blank lines from stdin or a file
**Declared dependencies:** sed, sponge (moreutils)
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **What happens:** String fallback branch treats all positional args as input string but includes the filename itself again (`str="$*"` after `file=${argv[0]}`), and `sponge` path vs stdin path diverge. If user passes `remove-blanks "hello\n\nworld"` expecting stdin-style, `file` is `"hello\n\nworld"` which is not a file, so falls to `else` and `echo "${str}" | awk 'NF'` works but `str="$*"` includes the same string — okay but if user passes two args `remove-blanks file.txt extra`, `file=file.txt`, `str="$*"` is `file.txt extra` — wrong. Also `cp -i` with `-i` prompts interactively under `set -e` non-TTY will hang.
- **Where:**
```bash
# remove-blanks:37-55
file=${argv[0]}
if [[ ${file} == "-" ]] || ((argc == 0)); then
  str=$(cat)
  ...
elif [[ -f ${file} ]]; then
  if ${useBackup}; then
    cp -i "${file}" "${file}.bak"
...
else
  str="$*"
  ...
  echo "${str}" | awk 'NF'
```
- **Why it's wrong:** Mixed file-vs-string mode is fragile; `cp -i` interactive prompt not desired in scripted use. Should error on non-file instead of treating as string, or explicitly check `argc`.
- **Fix:** `cp -- "${file}" "${file}.bak"` (or `cp -a`), and for else branch `log-error "File not found: ${file}"` instead of string fallback, or document string mode as `remove-blanks -- "string"`.

#### Minor / style

- `[[ ${file} == "-" ]]` and `[[ -f ${file} ]]` unquoted — word-splits/globs if file contains spaces; should be `[[ "${file}" == "-" ]]`.
- `str=$(cat)` + `echo "${str}" | awk 'NF'` loses trailing newlines and mangles; prefer `awk 'NF'` directly on stdin: `cat | awk 'NF'` or `awk 'NF' <(cat)`. Same for `echo "${str}" | awk 'NF'` in else branch.
- `awk 'NF'` removes blank lines but also lines with only whitespace? Actually `NF` is false for empty or whitespace-only lines — matches purpose ("blank lines") but comment says blank lines — okay but whitespace-only removal may be surprising.
- `declare sed/sponge` but script also uses `awk`/`cp` without declaring `awk` (coreutils-adjacent but still should be declared per house if strict; `awk` is common but `sed` is declared while `awk` not — inconsistent).
- `useBackup=${cmdarg_cfg['backup']}` then `if ${useBackup}; then` — house boolean style but should be unquoted `if ${useBackup}; then` (already) — okay but `useBackup` quoted assignment unnecessary.

#### Confirmed correct (potential false positives)

- `source "$(include "lib/helpers.sh")"` + `source "$(include "lib/cmdarg.sh")"` + `checkDeps` order matches house (order flexible but both sourced before `checkDeps`).
- `cmdarg "b" "backup"` boolean, `cmdarg_parse "$@"`, then `useBackup=${cmdarg_cfg['backup']}` and `file=${argv[0]}` / `((argc == 0))` positional handling matches `cmdarg.sh` contract.
- `awk 'NF' ... | sponge "${file}"` is house-idiomatic for in-place edit via `moreutils` (same as `sponge` use in `env-qoutes`).
- `trap 'exit 1' SIGUSR1` + `set -eo pipefail` correct.

---

### `insert-selection`

**Path:** `/home/othman/scripts/insert-selection`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Inserts selected text at the current cursor
**Declared dependencies:** xsel, xdotool
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **What happens:** Hidden deps `loop` (repo helper) and `copyq` (optional clipboard manager) used but not declared; on Wayland or without `copyq`, `loop -n 2 'copyq remove 0 &>/dev/null || true'` spawns errors or hangs. `copyq` not declared means `checkDeps` won't prompt install.
- **Where:**
```bash
# insert-selection:49
loop -n 2 'copyq remove 0 &>/dev/null || true'
```
- **Why it's wrong:** House `checkDep` requires every spawned exe between DEPENDENCIES markers. `loop` is a repo script (likely `loop` helper).
- **Fix:** Add `# - loop` `# - copyq | xsel` or make `copyq` optional: `command -v copyq &>/dev/null && loop ...`.

- **What happens:** Clipboard restore races `xdotool key ctrl+v` — `sleep 0.05` is heuristic; on slow compositors paste may fire before clipboard registers, pasting stale content. No verification that `xsel --clipboard --input` completed before `xdotool`.
- **Where:**
```bash
# insert-selection:42-46
printf '%s' "${content}" | xsel --clipboard --input
sleep 0.05
xdotool key --clearmodifiers ctrl+v
```
- **Why it's wrong:** Timing dependency fragile, distro-specific.
- **Fix:** Increase sleep or use `xsel --clipboard` sync check, or use `xdotool type --clearmodifiers -- "${content}"` as fallback (but loses rich paste).

#### Minor / style

- `prev="$(xsel --clipboard 2>/dev/null)"` captures clipboard but `xsel --clipboard --input` later with `printf '%s'` loses trailing newline; restore with same `printf`.
- `loop -n 2 'copyq remove 0 ...'` passes string to `loop` which likely `eval`s — quoting okay but `&>/dev/null || true` inside single quotes relies on loop's eval shell, not direct.
- No `--` guards on `xsel`/`xdotool`; content starting with `-` could be parsed as option, but clipboard content is via pipe, not arg — okay.

#### Confirmed correct (potential false positives)

- `source "$(include "lib/cmdarg.sh")"` / `helpers.sh` / `check-deps` + `trap` + `set -eo pipefail` + `cmdarg_info` + `cmdarg_parse "$@"` matches `clangc` template — correct.
- `content="$(xsel --primary 2>/dev/null)"` `[[ -z "${content}" ]] && content="$(xsel --clipboard ...)"` fallback primary→clipboard is intentional X11 selection semantics — not a bug.
- `xdotool key --clearmodifiers ctrl+v` is canonical paste simulation per X11.

---

### `kill-window`

**Path:** `/home/othman/scripts/kill-window`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Tries to kill a window gracefully then forcefully
**Declared dependencies:** wmctrl, xdotool, xkill (xorg-xkill), notify-send (libnotify)
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **What happens:** Window existence check `wmctrl -l | grep -q "${wid}"` may match substring (e.g., `0x012` matches `0x0123`) or fail if `wmctrl -l` output format changes across WMs.
- **Where:**
```bash
# kill-window:42
if wmctrl -l | grep -q "${wid}"; then
```
- **Why it's wrong:** No `-w`/`-F` anchoring; `wid` from `xdotool selectwindow` is hex with `0x`, but partial match risk remains.
- **Fix:** `grep -qw "${wid}"` or `wmctrl -l | awk -v id="${wid}" '$1==id'`.

#### Minor / style

- `wid="$(xdotool selectwindow 2>/dev/null)" || terminate` — `terminate` exits 0 via `logInfo` (helpers), so user-cancel is not error — matches intent but `terminate` message "Program terminated!" is generic.
- `notify-send -a "Kill Window" ... &` and `notify-send "Force killing..." &` backgrounded but not waited; notifications may be lost if script exits quickly — but `sleep 0.5` gives time.
- `wmctrl -ic "${wid}" &>/dev/null` graceful close may fail for Wayland clients (wmctrl is X11-only) — distro-specific but declared deps assume X11.
- `set -eo pipefail` with `grep -q` in `if` is exempt from errexit — correct.

#### Confirmed correct (potential false positives)

- Dependency block correctly lists alternatives with package overrides `xkill (xorg-xkill)` / `notify-send (libnotify)` matching house §2 pipe/parens semantics — `checkDep` will resolve correctly, not a syntax error.
- `source "$(include ...)"` house `include` indirection is correct.
- `trap 'exit 1' SIGUSR1` propagation chain is house-intentional; `log-error` kill path not needed here.

---

### `strip-ext`

**Path:** `/home/othman/scripts/strip-ext`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Remove extension(s) from a file name
**Declared dependencies:** basename
**Verdict:** `Needs fixes`

#### Critical bugs

None found.

#### Design issues

- **What happens:** Hidden dependency `replace.sh` (repo script) not declared; `checkDeps` passes with only `basename`, but script fails with `replace.sh: command not found` if `hooks/path.sh` not sourced.
- **Where:**
```bash
# strip-ext:40
    filename=$(echo "${filename}" | replace.sh ".${ext}" "")
```
- **Why it's wrong:** House requires all spawned exes between DEPENDENCIES markers.
- **Fix:** Add `# - replace.sh` or replace with pure Bash: `filename=${filename//.${ext}/}` (but careful to only strip suffix, not all occurrences).

- **What happens:** Double-strips extension via both `basename -s` and `replace.sh`, and `replace.sh` removes **all** occurrences of `.ext` not just suffix — `strip-ext file.tar.gz gz` on `my.gz.file` would mangle internal `.gz`.
- **Where:**
```bash
# strip-ext:38-40
  for ext in "$@"; do
    filename=$(basename -s ".${ext}" "${filename}")
    filename=$(echo "${filename}" | replace.sh ".${ext}" "")
  done
```
- **Why it's wrong:** `basename -s` already strips trailing suffix; second `replace.sh` is redundant and overly broad. For `strip-ext archive.tar.gz tar.gz`, first iteration `basename -s ".tar.gz"` no-op, second `replace.sh ".tar.gz"` removes all — but intention is to strip suffixes sequentially.
- **Fix:** Use only `basename -s` or pure Bash `[[ "${filename}" == *.${ext} ]] && filename=${filename%.${ext}}`.

- **What happens:** `[[ $# == 0 ]]` uses string-pattern `==` not numeric `-eq`; works for `0` but is semantically wrong and shellcheck warns; also `$#` unquoted inside `[[ ]]` is okay but inconsistent with house style `(( ))` arithmetic.
- **Where:**
```bash
# strip-ext:33
if [[ $# == 0 ]]; then
```
- **Why it's wrong:** Should be `(( $# == 0 ))` or `[[ $# -eq 0 ]]` per house arithmetic style.
- **Fix:** `if (( $# == 0 )); then`.

#### Minor / style

- `file="$1"; shift` without `local` and without checking `argc` from `cmdarg` — script uses `cmdarg_parse "$@"` but then accesses `$1`/`$#` directly instead of `argv`/`argc`; mixes `cmdarg` positionals with raw `$@` after parse. House style expects `file="${argv[0]}"`; raw `$1` after `cmdarg_parse` is shifted but okay because `cmdarg_parse` consumes flags and leaves positionals in `argv`, while `$@` still holds original? Actually `cmdarg_parse` shifts its own copy, not caller's `$@` — so `$1` after `cmdarg_parse` is still original `$1`. This works only because no flags defined, so `$1` happens to equal `argv[0]`, but fragile.
- `basename "${file}"` without `--` — file starting with `-` will be parsed as option; should be `basename -- "${file}"`.
- No handling for `strip-ext ""` or directory paths — edge case.

#### Confirmed correct (potential false positives)

- `set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `source "$(include "lib/cmdarg.sh")"` chain is house-correct.
- `checkDeps "$0"` immediately after sourcing is per house.
- `cmdarg_info "header" "$(get-desc "$0")"` + `cmdarg_parse "$@"` with no flags (just positionals) is allowed — missing DESCRIPTION/DEPENDENCIES optional per house §6, and `cmdarg` with no declarations correctly leaves all args as positionals.

---

### `env-qoutes`

**Path:** `/home/othman/scripts/env-qoutes` *(filename typo `qoutes` vs `quotes` — not flagged as bug but note)*
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Wraps all values inside a .env file with double qoutes for clarity
**Declared dependencies:** awk, sponge (moreutils)
**Verdict:** `Critical bug`

#### Critical bugs

- **What happens:** Values containing `=` are truncated to first field; comments and blank lines are corrupted. `.env` file is silently mangled in-place via `sponge`, causing data loss (API keys/URLs with `=` lost).
- **Where:**
```bash
# env-qoutes:33-38
awk -F= '{
  if ($2 ~ /"/ || NF == 0) {
    print $0
  } else {
    OFS=""; print $1, "=", "\"", $2, "\""
  }
}' "${file}" | sponge "${file}"
```
- **Why it's wrong:** `-F=` splits on every `=`; `$2` is only second field, `$3…$NF` discarded. `DATABASE_URL=postgres://a=b=c` becomes `DATABASE_URL="postgres://a"`. `NF==0` never true for lines like `FOO=bar` vs blank lines `NF==0` is empty line — okay, but lines without `=` (e.g., `# comment`, `export FOO`) have `NF==1`, `$2==""` not matching `/"` → else prints `$1=""` corrupting comment to `# comment=""`. `FOO=` empty value correctly quoted but `FOO=bar # comment` loses comment.
- **Fix:**
```bash
awk '{
  if ($0 ~ /^#/ || $0 ~ /^$/ || $0 ~ /=.*"/) { print; next }
  idx=index($0,"=")
  if (idx==0) { print; next }
  key=substr($0,1,idx-1); val=substr($0,idx+1)
  # optionally trim, handle existing quotes
  if (val ~ /^".*"$/) print
  else print key "=\"" val "\""
}' "${file}" | sponge "${file}"
```
Or with `awk -F= '{key=$1; sub(/^[^=]*=/,""); print key "=\"" $0 "\""}'` keeping remainder. Also handle `export`.

#### Design issues

- **What happens:** No validation that `file` exists/is-writable; `file="${argv[0]}"` may be empty if no args → `awk ... "" | sponge ""` creates error but with `set -e` aborts without friendly `log-error`. No backup despite in-place `sponge` destructive.
- **Where:**
```bash
# env-qoutes:31
file="${argv[0]}"
# env-qoutes:33
}' "${file}" | sponge "${file}"
```
- **Why it's wrong:** Should `[[ -f "${file}" ]] || log-error "File not found: ${file}"` and support stdin or `-i` backup flag like `remove-blanks`/`shellfmt`.
- **Fix:** Add check, and `cp "${file}" "${file}.bak"` before sponge or `cmdarg "b" "backup"`.

#### Minor / style

- Filename typo `env-qoutes` vs `env-quotes` — consistent but misspelled; not functional but grep `qoute` may confuse.
- `OFS=""` with `print $1, "=", "\"", $2, "\""` is awkward; `printf '%s="%s"\n', $1, $2` clearer.
- `sponge` without `moreutils` fallback — if missing, pipe fails but `checkDeps` would install.
- `awk -F=` logic also wraps values already single-quoted `'...'` — may double-wrap; should check `^['\"]`.

#### Confirmed correct (potential false positives)

- `source "$(include "lib/cmdarg.sh")"` + `checkDeps` + `trap` + `set -eo pipefail` + `cmdarg_info` + `cmdarg_parse "$@"` + `argv[0]` access matches house `clangc` pattern for positional scripts.
- `sponge` use for safe in-place edit is house-idiomatic (same as `remove-blanks:46`).
- Dependency block `awk` `sponge (moreutils)` with pipe/parens is house-correct — `checkDep` resolves `sponge` → `moreutils`.

---

## Batch Summary

- **Scripts reviewed:** 10 / 10
- **Critical bugs:** benchmark (systematic `${ cmd; }` Bad substitution → total/comparison broken, 7 call sites), no-orphans (keep-list inverted → removes kept packages = data loss), env-qoutes (value truncation on `=` + comment corruption via `sponge` = silent .env mangling)
- **Design issues worth escalating:** shellfmt (hidden `tabs2spaces`, hard-coded `~/.config/.shellcheckrc` fallback, fixed `/tmp/shellfmt.log` race), biome-check (hidden `is-git-repo`/`git-root`/`fd-by-depth`, `--config-path` file-vs-dir + relative path after `cd -`), strip-ext (hidden `replace.sh` + double `basename`/`replace` stripping all occurrences, `[[ $# == 0 ]]` style, raw `$1` vs `argv`), insert-selection (hidden `loop`/`copyq` + `sleep 0.05` race), remove-blanks (`cp -i` hang + `str="$*"` file-vs-string ambiguity + unquoted `[[ ${file} ]]`)
- **Cross-cutting patterns observed in this batch only** (same bug/pattern repeated across multiple scripts in this batch only; batch-level, not repo-wide):
  - Hidden/undeclared repo-script dependencies: `shellfmt→tabs2spaces`, `biome-check→is-git-repo/git-root/fd-by-depth`, `no-orphans→gum/get-unique`, `insert-selection→loop/copyq`, `strip-ext→replace.sh` — 5/10 scripts rely on `checkDeps` bypass; `checkDeps` would pass but runtime `command not found` if `hooks/path.sh` not sourced.
  - In-place `sponge` editing without backup/validation: `remove-blanks`, `env-qoutes` (and `shellfmt` tmp handling) all use `sponge`/overwrite destructively; `env-qoutes` critical truncation shows risk.
  - Boolean `true`/`false` execution style drift: `biome-check:69-70` `"${summary}" &&` quoted vs `remove-blanks:44` `if ${useBackup}` vs house `if ${cmdarg_cfg['x']}` — all functional but inconsistent and `set -e` interaction fragile.
  - Grab-bag nature → no single functional family; but 4/10 are text-transform filters (`remove-blanks`, `strip-ext`, `env-qoutes`, `shellfmt`) sharing `awk`/`sed`/`sponge` patterns and same quoting/blank-line pitfalls.
- **Open questions** (design intent unclear, needs the repo owner's input rather than a guess):
  - `benchmark` intended `sec2time` source: is `sec2time` from `lib/helpers.sh` (not present), `lib/time.sh`, or external? Should it be added to deps or vendored? Also whether `bc` should remain declared (currently unused) or be removed.
  - `biome-check` config resolution: should `--config-path` receive directory (`dirname`) or file? And should it respect `BIOME_CONFIG_PATH` env when no file found, or always prefer discovered `biome.json`?
  - `no-orphans` keep-vs-remove UX: `gum choose --header='Choose what to KEEP'` implies subtraction, but current `get-unique` suggests original intent was union/dedup — confirm whether `gum` prompt should be "choose to REMOVE" or logic should stay subtract.
  - `env-qoutes` scope: should it handle `export KEY=val`, `KEY='single'` , `KEY=val # comment`, and already-quoted `KEY="val"` identically, and should it create `.bak` like `remove-blanks` does?
  - `strip-ext` vs `basename` semantics: for `strip-ext a/b/c.tar.gz gz` should result be `c` (basename stripped) or `a/b/c.tar` (path-preserving suffix strip)? Current `basename -s` strips directory always — confirm intended behavior.

---

## Evidence Appendix

`benchmark:21` missing `set -eo pipefail` vs `clangc:21`:
```bash
# benchmark:21 (actual)
trap 'exit 1' SIGUSR1
# clangc:21-22 (reference)
set -eo pipefail
trap 'exit 1' SIGUSR1
```
`benchmark:58,60,81,106-112` Bad substitution family (6 distinct lines, 7 call sites) — `bash -n` passes (syntax 0) but runtime `Bad substitution` (tested `bash -c 'x=${ echo hi; }'` → Bad substitution).
`shellfmt:73` hard-coded RC: `shellcheck --rcfile="${HOME}/.config/.shellcheckrc"` vs no fallback.
`biome-check:46-54` hidden deps not in `# --- DEPENDENCIES --- #` (`biome` only).
`no-orphans:54` inverted: `removablePkgs+=("${keepPkgs[@]}")` then `get-unique` keeps.
`strip-ext:40` `replace.sh` not declared; `clangc` declares `xxh3sum | xxhsum | sha1sum` correctly.
`env-qoutes:33` `awk -F=` truncation proof: `echo 'A=b=c' | awk -F= '{print $2}'` → `b` not `b=c`; `NF==0` never hits comment lines.

