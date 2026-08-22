# Batch Review: 10 of 22

**Scripts in this batch:** `check-deps` (175), `git_current_branch` (32), `git-root` (32), `copycat` (34) — 4 scripts, 273 lines
**Batch composition:** large+fillers — pairing incidental, cap 4, budget 273. `check-deps` is the large dependency-infra library; `git_current_branch` + `git-root` are git-family small wrappers, `copycat` is clipboard helper. The three fillers are unrelated to `check-deps` except via `checkDeps` call; git pair shares a real `is-git-repo` pattern.
**Reviewer:** subagent-10
**Date:** 2026-08-21

---

## House Style Reference (do not flag these as bugs)

Before reviewing, confirm you've internalized these repo conventions. Restate them here in one line each to prove the context loaded correctly:

- Dependency declaration format (`# - binary | binary2 (pkg-override)`) and how `checkDep` resolves it: one `# - exe | alt (pkg)` line per dep between `DEPENDENCIES`/`END SIGNATURE`; `checkDep` splits on `|` then `Trim` + `awk '{print $1}'`, `command -v` each alt in order — any found → satisfied (return 0, no output), else echoes `(parens)` pkg override or first exe for `installDep`.
- Logging convention: `log-*` wrapper scripts are primary, camelCase `log*` functions in `lib/helpers.sh` are fallback: `log.sh` dispatcher maps `LEVEL→LEVEL_COLORS/LEVEL_OUTPUT→colorOnlyPrefix`; `lib/helpers.sh` `logDebug/logSuccess/logInfo/logWarning/logError` + `lib/loggers.sh` `printRed/printGreen/printPurple/hex_to_rgb/printer/supportsColor` are in-process fallback, not dead code; `log-success` vs `logSuccess` naming is canonical.
- `trap 'exit 1' SIGUSR1` + `kill -SIGUSR1 "${PPID}"` propagation chain purpose: every executable script traps `SIGUSR1→exit 1`; only `log-error` kills `PPID` (guarded by `! isInteractiveShell && ! noKill`, `|| true` + `wait` suppression) to bubble fatal errors without caller checking exit codes.
- `cmdarg.sh` argument-parsing pattern used across scripts: `source "$(include "lib/cmdarg.sh")"` → `cmdarg_info "header" "$(get-desc "$0")"` → pre-`declare -a/declare -A` for `[]/{}` types → `cmdarg "v"` bool→`false`/`true`, `"m:"` required, `"o?"` optional, `"a?[]"`/`"H?{}"` arrays/hashes → `cmdarg_parse "$@"` → read `cmdarg_cfg`/`argv`/`argc`; `-h/--help` reserved, `CMDARG_ERROR_BEHAVIOR=return`.
- `get-desc` / `get-deps` signature-block parsing rules: both `sed -n` parse `# --- DESCRIPTION ---` … `# --- DEPENDENCIES ---` … `# --- END SIGNATURE ---`; `get-desc` loops `:loop; n; /DEPENDENCIES/q; /END/q; /# /p` + `sed 's|# ||g'`; `get-deps` `sed -n '/DEPENDENCIES/,/END/{/# - /p; /END/q}' | replace.sh '# - ' ''`; missing block allowed → `x-none`/empty, not a bug.
- `init.sh` / `hooks/path.sh` symlink and PATH-registration workflow: `init.sh` verifies `SCRIPTS_DIR` (`~/scripts`), ensures `fd` (prompt `fdfind→fd` symlink), checks `hooks/path.sh`, idempotently appends `[[ -s "${SCRIPTS_DIR}/hooks/path.sh" ]] && source ...` to `~/.bashrc`/`${ZDOTDIR:-$HOME}/.zshrc`; `hooks/path.sh` is sourced at shell start, caches `fd --strip-cwd-prefix=always --no-ignore-vcs -t x . --exclude .git/.venv/...` to `/tmp/path-hook.cache`, rescans only when `find -newer cache`, adds each exe dir once via `:...:` guard, unsets temps.
- Reference pattern from `clangc` (what "correct" looks like in this repo): `set -eo pipefail`+`trap`+`source cmdarg`+`source compile`+`source check-deps`+`checkDeps "$0"` → `cmdarg_info "$(get-desc "$0")"` → `declare -a compiler_args` → `cmdarg "c"`/`"o?"`/`"a?[]"`/`"q"` → `cmdarg_parse "$@"` → read `cmdarg_cfg`, `((argc<1)) && log-error`, array-safe `compile_and_run` with namerefs.

---

## Script Reviews

### `check-deps`

**Path:** `/home/othman/scripts/check-deps`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Checks a script's dependencies and installs them
**Declared dependencies:** none (library; no `# --- DEPENDENCIES --- #` block, sourced via `include`)
**Verdict:** `Critical bug`

#### Critical bugs

- **What happens:** `getAskPass` overwrites an existing system `askpass` binary if one is already on `PATH`.
- **Where:**
```bash
# /home/othman/scripts/check-deps:101-106
  path="$(dirname "${BASH_SOURCE[0]}")/askpass"

  # create if not present
  command -v askpass &>/dev/null && path="$(command -v askpass)"

  cat >"${path}" <<EOF
```

- **Why it's wrong:** The comment says "create if not present" but the logic does the opposite: if `askpass` is found (e.g., `/usr/bin/askpass` from `ssh-askpass` package), `path` is reassigned to that absolute location and the subsequent `cat >"${path}"` clobbers the system binary (or fails with permission error and leaves `path` pointing at a non-writable file, so the later `SUDO_ASKPASS` points at the system path that was not updated). The intention was to reuse an existing `askpass` or create `SCRIPTS_DIR/askpass` only when missing.
- **Fix:**
```bash
  path="$(dirname "${BASH_SOURCE[0]}")/askpass"
  if command -v askpass &>/dev/null; then
    printf '%s' "$(command -v askpass)"
    return 0
  fi
  cat >"${path}" <<EOF
```

- **What happens:** `checkDeps` error reporting shells out to external `joinarr` script instead of an in-process join; if `joinarr` is missing, not yet on `PATH` (fresh shell before `hooks/path.sh` runs), or its own bug triggers, the failure message loses the failed package list.
- **Where:**
```bash
# /home/othman/scripts/check-deps:173
  [[ ${completed} == 1 ]] && logError "Failed to install all dependencies ($(joinarr ', ' "${failed[@]}"))"
```

- **Why it's wrong:** `joinarr` at `/home/othman/scripts/joinarr:35` itself has a bug (`$(basename scriptName)` missing `$` → prints literal `scriptName`) and is an external process that itself calls `checkDeps "$0"`; failure inside `$(joinarr ...)` with `set -e` in the caller suppresses the exit but yields empty substitution, so `logError` prints `Failed to install all dependencies ()`. A one-line `IFS=', '; echo "${failed[*]}"` or `printf` join in `helpers.sh` would be reliable and avoids the PATH ordering dependency. Not a crash on success path, but degrades the only failure diagnostic the library produces.
- **Fix:**
```bash
  [[ ${completed} == 1 ]] && logError "Failed to install all dependencies (${failed[*]})"
  # or: local joined; joined=$(IFS=', '; echo "${failed[*]}"); logError "Failed to install all dependencies (${joined})"
```
  And add `shellJoin` helper if a reusable join is needed; do not depend on external `joinarr` script for library error reporting.

#### Design issues

- **What happens:** `checkDep` duplicates the `grep -oP` extraction (once with `-q` to test, once to capture) and always exits 0 even when dependency is missing, forcing the caller to test output length (`[[ -n "${item}" ]]`) rather than exit status.
- **Where:**
```bash
# /home/othman/scripts/check-deps:39-51
  exeName=$(echo "${line}" | awk -F "|" '{print $1}' | Trim | awk '{print $1}')

  if echo "${line}" | grep -oP '\(\K[^)]*(?=\))' -q; then
    pkgName=$(echo "${line}" | grep -oP '\(\K[^)]*(?=\))')
  fi
```

- **Why it's wrong:** Works per house-style contract (house brief §2 states "if any alternative found return 0, else echo pkgName"), so not a bug to fix now, but the double-grep is wasteful and the `return 0` in both branches is confusing for future callers who expect non-zero on missing. The `-q` test + re-run also hides errors if `grep -P` is unavailable (macOS/BSD) — second grep would fail silently.
- **Fix:** Keep contract but collapse to single capture (future refactor):
```bash
  pkgName=$(echo "${line}" | grep -oP '\(\K[^)]*(?=\))' || true)
  [[ -n "${pkgName}" ]] && echo "${pkgName}" || echo "${exeName}"
```
  Do not change caller contract without updating all callers.

- **What happens:** `installDep` parses `installCmd` via `read -ra cmdArray <<<"${installCmd} ${pkg}"` then executes `SUDO_ASKPASS="$(getAskPass)" "${cmdArray[@]}"`.
- **Where:**
```bash
# /home/othman/scripts/check-deps:121-132
  pkgManager=$(getPackageManager)
  installCmd=$(echo "${pkgManager}" | awk -F ':' '{print $NF}')
  read -ra cmdArray <<<"${installCmd} ${pkg}"
  # ...
  if SUDO_ASKPASS="$(getAskPass)" "${cmdArray[@]}"; then
    sleep 1 && clear
```

- **Why it's wrong:** `awk -F ':' '{print $NF}'` assumes `getPackageManager` format `manager:installCmd` where manager contains no colon — true today but fragile if installCmd ever contains a colon (e.g., yum variants). `read -ra` word-splits on `IFS` and loses quoting if `pkg` contained special chars (not today, but e.g., `pkg:version`). `sleep 1 && clear` runs `clear` even when not on a TTY; `clear` exits 1 when `TERM` is unset, and with caller's `set -e` the `&&` prevents exit but still wastes a sleep.
- **Fix:** Use `installCmd="${pkgManager#*:}"` (parameter expansion, no awk) and `cmdArray=(${installCmd} "${pkg}")` split only the known install prefix; gate `clear` on TTY: `[[ -t 1 ]] && clear`.

- **What happens:** `getAskPass` embeds the selected display/terminal command raw into the generated askpass script via heredoc.
- **Where:**
```bash
# /home/othman/scripts/check-deps:106-113
  cat >"${path}" <<EOF
#!/usr/bin/env bash

set -euo pipefail

# ---  Main script logic --- #
${cmd}
EOF
```

- **Why it's wrong:** `cmd` contains `/bin/sh -c 'whiptail --passwordbox "Authentication Required" 8 40 2>&1 >/dev/tty; echo $?'` with nested quotes and `$?` that must be literal `$?` not expanded at generation time. Inside `<<EOF` (unquoted), `$?` would be expanded if not escaped as `\$?` — the current code relies on the caller having written `\$?` in the string (which `checkTerminal` does), but the `zenity`/`kdialog` branches have no `$` to escape, so fragile. Also writes to `SCRIPTS_DIR/askpass` polluting the repo; `/tmp` would be more appropriate.
- **Fix:** Use `<<'EOF'` and controlled substitution, or write to `$(mktemp)`/`/tmp/askpass.$$`; ensure `$` handling is explicit. Low priority — works today due to `\$?` escaping.

#### Minor / style

- `Trim` in `/home/othman/scripts/lib/helpers.sh:210-214` uses `[[ -z ${str} ]] && printf '' && exit 0` — `exit` instead of `return`. Inside `checkDep`'s pipeline (`echo ... | awk | Trim | awk`) this is a subshell so harmless, but direct calls like `Trim " "` would `exit` the whole script. Should be `return 0`. Not a `check-deps` line to patch, but `checkDep` is the only caller that masks the bug via pipeline.
- `while` idiom `while exeName=$(echo "${line}" | awk -F "|" "{print \$${i}}" | Trim | awk '{print $1}'); [[ -n "${exeName}" ]]; do` uses `echo | awk` for splitting; `IFS='|' read -ra parts <<<"${line}"` would be pure bash and avoid three forks per alternative.
- `grep -oP '\(\K[^)]*(?=\))'` is GNU-specific (`-P`); repo targets Arch/debian per `getPackageManager`, so house-style accepts it, but note portability.

#### Confirmed correct (potential false positives)

- `source "$(include "lib/helpers.sh")"` indirection with `realpath -m` is intentional per house style §1, not fragile.
- `checkDep` splitting on `|` with `Trim` + `awk '{print $1}'` and `command -v` loop returning 0 on any alternative found is canonical per house brief §2 (`fd | fdfind (fd-find)`, `xxh3sum (xxhash) | xxhsum (xxhash) | sha1sum (coreutils)` pattern).
- `grep -oP '\(\K[^)]*(?=\))'` for `(pkg)` override and `# --- DEPENDENCIES --- #` block parsing via `getDeps` returning `x-none` with early `return 0` are per spec.
- No `set -eo pipefail` / `trap 'exit 1' SIGUSR1` in this file is correct — it's a library sourced by executables, not an executable itself; only `log-error` sends `SIGUSR1`.
- `logError` (camelCase) vs `log-error` (wrapper) — fallback layer per house brief §3, not dead code/naming bug.

---

### `git_current_branch`

**Path:** `/home/othman/scripts/git_current_branch`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Displays the name of the current Git branch
**Declared dependencies:** `git`
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **What happens:** `git branch --show-current` outputs empty string on detached HEAD (exit 0) with no error, after `is-git-repo` already passed.
- **Where:**
```bash
# /home/othman/scripts/git_current_branch:30-32
is-git-repo

git branch --show-current 2>/dev/null
```

- **Why it's wrong:** User expectation for "current branch" on detached HEAD is usually the short SHA or `HEAD` with a warning; empty output is silent success that scripts piping this value will misinterpret as "no branch". Other repo git helpers (e.g., `gitsync`, `switch-branch`) guard with `git rev-parse --abbrev-ref HEAD`. Not a crash, but an unhandled expected state.
- **Fix:** 
```bash
is-git-repo
branch="$(git branch --show-current 2>/dev/null)"
if [[ -z "${branch}" ]]; then
  git rev-parse --short HEAD 2>/dev/null || log-error "Detached HEAD and cannot resolve commit"
else
  printf '%s\n' "${branch}"
fi
```
  Or document that empty means detached and exit 0 is intentional.

- **What happens:** Transitive `helpers.sh` inclusion via `check-deps` (`git_current_branch` sources only `lib/cmdarg.sh` + `check-deps`; `check-deps` sources `lib/helpers.sh`).
- **Where:**
```bash
# /home/othman/scripts/git_current_branch:23-24
source "$(include "lib/cmdarg.sh")"
source "$(include "check-deps")"
```

- **Why it's wrong:** Works because `check-deps:18` sources `helpers.sh`, but couples `git_current_branch` to an internal detail of `check-deps`. If `check-deps` were refactored to not source helpers, `is-git-repo`'s `log-error` fallback would break. Canonical `clangc` sources both explicitly.
- **Fix:**
```bash
source "$(include "lib/cmdarg.sh")"
source "$(include "lib/helpers.sh")"
source "$(include "check-deps")"
```

#### Minor / style

- No `declare -a`/`declare -A` before `cmdarg_parse "$@"` needed — correct, no `[]`/`{}` args declared.
- No `((argc))` validation — extra positional args are silently ignored (they land in `argv` but never read). Harmless for this zero-arg command, but `((argc > 0)) && log-warning "ignoring extra args: ${argv[*]}"` would catch user typos.
- `2>/dev/null` on `git branch` hides the error that `is-git-repo` already reports with more context — intentional to avoid duplicate message, not a bug.

#### Confirmed correct (potential false positives)

- `source "$(include "lib/cmdarg.sh")"` + `checkDeps "$0"` + `cmdarg_info "$(get-desc "$0")"` + `cmdarg_parse "$@"` minimal cmdarg usage with no user flags is allowed; empty DEPENDENCIES alternatives not needed (git declared correctly, single dep no pipe/parens).
- `set -eo pipefail` + `trap 'exit 1' SIGUSR1` present and correctly ordered before sourcing — matches `clangc` reference even though this leaf never sends `SIGUSR1` itself.
- `is-git-repo` without `--safe` (kill parent on failure) is intentional; `is-git-repo:35-43` uses `log-error` (kills) by default and `--safe` only when caller wants non-fatal.
- Dependency line `- git` correctly lists binary name without pkg override; `checkDep` will `command -v git` and install `git` if missing.

---

### `git-root`

**Path:** `/home/othman/scripts/git-root`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Displays the root directory of the current Git repository
**Declared dependencies:** `git`
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **What happens:** Same transitive `helpers.sh` inclusion as `git_current_branch`.
- **Where:**
```bash
# /home/othman/scripts/git-root:23-24
source "$(include "lib/cmdarg.sh")"
source "$(include "check-deps")"
```

- **Why it's wrong:** Relies on `check-deps` to pull in `helpers.sh` for `is-git-repo`'s `logError` fallback. Should source `lib/helpers.sh` directly like `clangc` does.
- **Fix:** Same as `git_current_branch`: add `source "$(include "lib/helpers.sh")"` between `cmdarg` and `check-deps` sources.

#### Minor / style

- No `argc` validation — extra args silently ignored; same harmless pattern as twin script.
- Could use `printf '%s\n' "$(git rev-parse --show-toplevel 2>/dev/null)"` to ensure newline handling, but bare `git rev-parse` is idiomatic and correct.

#### Confirmed correct (potential false positives)

- `set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `source "$(include "lib/cmdarg.sh")"` + `source "$(include "check-deps")"` + `checkDeps "$0"` + `cmdarg_info/cli` ordering matches `clangc` reference (minus explicit `helpers.sh` which is transitive but intentional in many small scripts).
- `is-git-repo` bare call (without `--safe`) correctly kills parent on non-repo via `log-error` → `SIGUSR1`; `git rev-parse --show-toplevel` without `2>/dev/null` suppression would be duplicate error — but current code has no `2>/dev/null`, so on non-repo it prints git's `fatal: not a git repository` to stderr before `is-git-repo`'s message. That's slightly verbose but not wrong; `git_current_branch` suppresses with `2>/dev/null` while this one does not — inconsistency but not a bug.
- Dependency block `- git` single dep, no pipe/parens, correctly resolved by `checkDep`.
- Empty `argv` handling (no declared positionals) is allowed per `cmdarg` contract.

---

### `copycat`

**Path:** `/home/othman/scripts/copycat`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Copies the contents of a file to the clipboard.
**Declared dependencies:** `cat` (declared) — actual runtime uses `clipcopy` + `log-error`/`log-success`
**Verdict:** `Needs fixes`

#### Critical bugs

None found. (Dependency miss and silent `clipcopy` failure are design-level — they cause wrong package install attempts and missing success signal, but do not crash with wrong data.)

#### Design issues

- **What happens:** Declared dependency `- cat` does not match runtime binary `clipcopy`; `checkDeps` will `command -v cat` (always true via `coreutils`) and skip install, even when `clipcopy` (and its underlying `xclip|wl-copy|copyq + ansifilter`) is missing.
- **Where:**
```bash
# /home/othman/scripts/copycat:16-18,34
# --- DEPENDENCIES --- #
# - cat
# --- END SIGNATURE --- #
# ...
clipcopy <"${file}" && log-success "Copied file ${file} contents successfully"
```

- **Why it's wrong:** `clipcopy` at `/home/othman/scripts/clipcopy:11-12` declares `- xclip | wl-copy (wl-clipboard) | copyq` + `ansifilter`; `copycat` bypasses that declaration by listing `cat`. On a fresh machine without `xclip`/`wl-copy`/`copyq`/`ansifilter`, `copycat` will pass `checkDeps`, then `clipcopy` will `log-error "No clipboard tool ... was found"` but `copycat`'s `&&` chain means failure is silent (see next issue). `cat` is never called — `clipcopy` reads via stdin.
- **Fix:**
```bash
# --- DEPENDENCIES --- #
# - xclip | wl-copy (wl-clipboard) | copyq
# - ansifilter
# --- END SIGNATURE --- #
```
  Or if `clipcopy` is the intended abstraction, declare `- clipcopy` and make `checkDeps` resolve internal scripts via `command -v` (which `hooks/path.sh` provides), but prefer the underlying binaries so `installDep` can map to a real package.

- **What happens:** `clipcopy` failure is not reported; script exits 0 with no output.
- **Where:**
```bash
# /home/othman/scripts/copycat:34
clipcopy <"${file}" && log-success "Copied file ${file} contents successfully"
```

- **Why it's wrong:** Under `set -eo pipefail`, `A && B` is a conditional context where `set -e` does not exit on `A`'s failure; `&&` short-circuits so `log-success` is skipped, but the script's exit status is that of the last executed command — the failed `clipcopy` is not the last (it's part of `&&` list), so the overall statement exits 0. User sees no error and clipboard is empty.
- **Fix:**
```bash
clipcopy <"${file}" || log-error "Failed to copy ${file} to clipboard"
log-success "Copied file ${file} contents successfully"
```
  Or `clipcopy <"${file}" && log-success ... || log-error ...` if both paths must message.

#### Minor / style

- `file="${argv[0]}"` without prior `((argc >= 1))` check relies on `-z` test on next line; clearer as `((argc == 0)) && log-error "No file provided"` before assignment. Current `[[ -z "${file}" || ! -f "${file}" ]] && log-error "File ${file} not found"` reports `File  not found` (double space) when no arg given.
- Missing quotes for `log-error` argument inside double quotes not needed (`"${file}"` is quoted) but message should use `$(humanQuote "${file}")` for consistency with repo's `humanQuote` helper for display.
- No handling for multiple files — takes only `argv[0]` while description says "a file" (singular) so correct, but `((argc > 1)) && log-warning "only first file used"` would catch user error.

#### Confirmed correct (potential false positives)

- `set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `source "$(include "lib/cmdarg.sh")"` + `source "$(include "check-deps")"` + `checkDeps "$0"` + `cmdarg_info "$(get-desc "$0")"` + `cmdarg_parse "$@"` ordering matches `clangc` reference.
- `source "$(include "lib/helpers.sh")"` transitive via `check-deps` (like git scripts) — works per current `check-deps:18`, though explicit inclusion is preferred.
- `log-error` / `log-success` as external commands (not `logError` camelCase) is primary logging interface per house brief §3 — not a missing import.
- `[[ -z "${file}" || ! -f "${file}" ]]` guard with `log-error` correctly kills parent via `SIGUSR1` propagation chain.

---

## Batch Summary

- **Scripts reviewed:** 4 / 4
- **Critical bugs:** `check-deps` — `getAskPass:101-106` clobbers existing system `askpass` binary; `checkDeps:173` depends on external `joinarr` script for its only failure diagnostic (fragile, loses failed list if `joinarr` missing/buggy).
- **Design issues worth escalating:** `copycat` — wrong `DEPENDENCIES` (`- cat` instead of `xclip | wl-copy | copyq + ansifilter`) + silent `clipcopy` failure via `&&` (exits 0); `check-deps` — double `grep -oP`, `read -ra`/`awk -F ':'` fragility, heredoc `$?` handling, repo-polluting `askpass` path; `git_current_branch`/`git-root` — transitive `helpers.sh` via `check-deps`.
- **Cross-cutting patterns observed in this batch** (same bug/pattern repeated across multiple scripts in this batch only; batch-level, not repo-wide):
  - `git_current_branch` + `git-root` are twin wrappers: identical `cmdarg` zero-flag boilerplate, identical transitive `helpers.sh` sourcing, same `is-git-repo` guard pattern. Not a bug, but both share the detached-HEAD empty-output nuance (`git branch --show-current` silent empty vs `git rev-parse --show-toplevel` verbose) and the missing `helpers.sh` explicit source.
  - All four scripts rely on `checkDeps "$0"` → `getDeps` → `sed -n '/DEPENDENCIES/,/END/{/# - /p}'`; all four correctly use `# - ` convention, but `copycat`'s block is semantically wrong while `check-deps` itself has no block (library) — the only inconsistent dep declaration in the batch.
- **Open questions** (design intent unclear, needs the repo owner's input rather than a guess):
  - `check-deps:getAskPass` — is `SCRIPTS_DIR/askpass` polluting the repo intentional (so `SUDO_ASKPASS` survives reboot without `/tmp` cleanup) or should it be `mktemp`/XDG cache? Current overwrite-if-exists suggests intent was "reuse system askpass if present, else create local one" but comment/logic diverge.
  - `check-deps:checkDeps:173` — should failure joining use an in-process `helpers.sh` helper (e.g., `IFS=', '; echo "${failed[*]}"`) or keep external `joinarr` for reuse? External adds a process + `checkDeps` recursion + PATH dependency for a one-line join.
  - `copycat` — is the intended contract "file path → clipboard" (current) or "stdin/args → clipboard" like `clipcopy` (`str="$(input "$@") | ansifilter"`)? `copycat` is the file-only convenience wrapper; confirm `cat` dep was a placeholder for `clipcopy` or a stale declaration.
  - `git_current_branch` — should detached HEAD return empty (current), `HEAD`, or short SHA? Determines whether to patch the depth-sort-style fix above.

---

## Evidence Appendix

- House brief loaded from `/home/othman/scripts/docs/code-reviews/house-style-brief.md` (8 sections, 67 lines).
- Core files cross-checked: `include:1-26` (`realpath -m` existence gate), `lib/cmdarg.sh:7-462` (`CMDARG_FLAG_*`, `cmdarg "h"` reserved, `CMDARG_ERROR_BEHAVIOR=return`), `lib/loggers.sh:322-341` (`colorOnlyPrefix`), `lib/helpers.sh:67-84` (`getDeps`), `lib/helpers.sh:210-214` (`Trim` `exit` vs `return`), `check-deps:21-175` full, `log.sh:29-43` (`LEVEL_COLORS`), `get-desc:42-50`, `get-deps:37-38`, `init.sh:20-33`, `hooks/path.sh:44-83`, `clangc:21-67` reference.
- `joinarr` at `/home/othman/scripts/joinarr:35` confirmed `$(basename scriptName)` bug; `is-git-repo` at `/home/othman/scripts/is-git-repo:35-43` confirmed `--safe` → `log-error --no-kill` branching.
- Line counts: `check-deps 175 + git_current_branch 32 + git-root 32 + copycat 34 = 273` matches batch budget.
