# Batch Review: 12 of 22

**Scripts in this batch:** init.sh (158), system-stats (37), catname (37), ocrshot (37)
**Batch composition:** large+fillers — pairing incidental, cap 4, budget 269. `init.sh` (158) is the large tool; `system-stats` (37), `catname` (37), `ocrshot` (37) are small unrelated fillers packed to fill the line budget, not a directory group or name-family. No shared pattern to infer.
**Reviewer:** subagent-12
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

### `init.sh`

**Path:** `/home/othman/scripts/init.sh`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Verifies the scripts repo setup and wires the path hook into shell configs
**Declared dependencies:** `fd | fdfind (fd-find)`
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **What happens:** Hard-coded symlink target `/usr/bin/fd` is distro-specific and may not be writable; `fdfind` could live in `/usr/bin/fdfind` on Debian but `/usr/local/bin` elsewhere, and some Arch installs expect `fd` without sudo.
- **Where:**
```bash
sudo ln -sv "$(command -v fdfind)" /usr/bin/fd
```
- **Why it's wrong:** Not portable, requires sudo with no `SUDO_ASKPASS` handling (unlike `check-deps:installDep` which sets `SUDO_ASKPASS="$(getAskPass)"`). Fails silently on systems where `/usr/bin` is read-only or `fdfind` is under a different prefix.
- **Fix:**
```bash
targetDir="$(dirname "$(command -v fdfind)")"
sudo ln -sv "$(command -v fdfind)" "${targetDir}/fd"
# or use SUDO_ASKPASS="$(getAskPass)" sudo -A ln -sv ...
```

- **What happens:** Uses internal repo script `collapseTilde` at runtime without declaring it as a dependency; if the PATH hook is not yet installed or `collapseTilde` is removed, the call fails with `command not found` under `set -e`.
- **Where:**
```bash
friendlyConfigPath="$(collapseTilde "${configFile}")"
```
- **Why it's wrong:** Internal script deps are conventionally not declared (e.g., `ocrcp` uses `ocr`/`clipcopy` without listing), but `init.sh` is the bootstrapper that sets up PATH — it cannot assume PATH already contains `collapseTilde`. It does add `INIT_DIR` to `PATH` at line 24, so it currently works, but the coupling is implicit.
- **Fix:** Either declare `collapseTilde` comment-dependency for documentation, or replace with bash expansion: `friendlyConfigPath="${configFile/#$HOME/\~}"` (no fork, no PATH dependency).

- **What happens:** Sourcing `check-deps` via direct file path bypasses `include` indirection, then later uses `include` for `lib/cmdarg.sh`/`lib/helpers.sh` — ordering diverges from `clangc` reference (`cmdarg` → `compile` → `check-deps` → `checkDeps`).
- **Where:**
```bash
checkDepsFile="${INIT_DIR}/check-deps"
if [[ -s "${checkDepsFile}" ]]; then
  source "${checkDepsFile}"
  checkDeps "${BASH_SOURCE[0]}"
fi
source "$(include "lib/cmdarg.sh")"
source "$(include "lib/helpers.sh")"
```
- **Why it's wrong:** Not a runtime bug — fallback is intentional because `SCRIPTS_DIR` may not yet be verified — but it creates two sourcing styles in one file and runs `checkDeps` before `cmdarg` is available to parse `--help`.
- **Fix:** Keep as-is with a comment explaining the boot order, or move `checkDeps` after `cmdarg_parse` like `clangc` once `SCRIPTS_DIR` is validated.

#### Minor / style

- Mixes primary `log-error` style and fallback `logError`/`logInfo`/`logSuccess`/`logWarning` camelCase in one file. Both are canonical per house brief, but mixing reduces consistency; prefer `log-error` etc. per `clangc`.
- `grep -qF 'hooks/path.sh' "${configFile}"` can false-positive on a commented line (`# source hooks/path.sh`); not a bug but could skip installation if user commented it out intentionally. `grep -qF 'source "${SCRIPTS_DIR}/hooks/path.sh"'` is more precise.
- `printf '\n  %s\n\n' "${sourceLine}"` preview adds leading spaces for display then `printf '\n%s\n' "${sourceLine}" >>"${configFile}"` writes without them — intentional but asymmetric; consider removing the preview indent or documenting it.

#### Confirmed correct (potential false positives)

- `# - fd | fdfind (fd-find)` with `(fd-find)` pkg override — correct per `checkDep` (splits on `|`, `command -v` each alt, any found → 0, else `grep -oP '\(\K[^)]*(?=\))'`).
- `set -eo pipefail` + `trap 'exit 1' SIGUSR1` — canonical; `trap` alone without `kill` is intentional (only `log-error` kills PPID).
- `source "$(include "lib/cmdarg.sh")"` / `lib/helpers.sh` via `include` with `realpath -m` — house style, not fragile; `SCRIPTS_DIR="${HOME}/scripts"` fallback to `dirname BASH_SOURCE[0]` handled in `include:19-24`.
- `declare -a shells` pre-declared before `cmdarg "s?[]" "shells"` — required for `[]` type per `cmdarg.sh:54-59`; `cmdarg_info "header" "$(get-desc "$0")"` + overridden `cmdarg_usage` via `cmdarg_helpers['usage']` to add `SCRIPTS_DIR`/`SCRIPTS_HOOK_EXCLUDE` env docs — works because `cmdarg_helpers['usage']` holds function name.
- `: "${SCRIPTS_DIR:=${HOME}/scripts}"` default-assignment guard and `[[ ! -d "${SCRIPTS_DIR}" ]]` check — correct per `init.sh`/`hooks/path.sh` workflow.
- `[[ -f "${configFile}" ]] && grep ...` before appending, plus `mkdir -p "$(dirname "${configFile}")"` — idempotent PATH registration per house brief.

---

### `system-stats`

**Path:** `/home/othman/scripts/system-stats`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Displays vairous system monitoring stats like cpu, ram, and disk usage
**Declared dependencies:** `top`, `awk`, `free`, `df`
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **What happens:** `awk` printf uses single `%` for literal percent — non-portable per POSIX/GAWK spec (should be `%%`).
- **Where:**
```bash
printf '  %s\t' "$(top -bn1 | awk '/Cpu\(s\)/ {printf "%.0f%", 100 - $8}')"
```
- **Why it's wrong:** POSIX requires `%%` for a literal `%`; `%.0f%` relies on gawk/mawk treating trailing single `%` as literal. Works on this host (`60%`) but may error or drop `%` on stricter awks.
- **Fix:**
```bash
printf '  %s\t' "$(top -bn1 | awk '/Cpu\(s\)/ {printf "%.0f%%", 100 - $8}')"
```

- **What happens:** `top -bn1` + `/Cpu\(s\)/` and `free -m` / `df -h /` are Linux procps-specific; no `TERM`/`LANG=C` guard.
- **Where:**
```bash
top -bn1 | awk '/Cpu\(s\)/ {printf "%.0f%", 100 - $8}'
free -m | awk '/Mem:/ {print $3 "MB"}'
df -h / | awk 'NR==2 {print $4}'
```
- **Why it's wrong:** If `LANG` is non-English, `top` header may be localized (e.g., German `Prozessor`). `top` flags `-bn1` also not portable to BusyBox/macOS. Repo targets Arch Linux, so acceptable, but fragile without `LC_ALL=C`.
- **Fix:**
```bash
LC_ALL=C top -bn1 | awk '/Cpu\(s\)/ {printf "%.0f%%", 100 - $8}'
```

#### Minor / style

- Dependency list includes `awk`, `free`, `df` — per AGENTS.md coreutils/basic commands (`awk`, `df`) are excluded from declaration; not wrong, just verbose (compare `collapseTilde` declares `sed` similarly — inconsistency across fillers).
- Icons ``, ``, `󰋊` require Nerd Fonts; no ASCII fallback. Cosmetic, not a bug.
- Spelling in description: `vairous` → `various`. `get-desc` consumers will display the typo.

#### Confirmed correct (potential false positives)

- `set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `source "$(include "lib/cmdarg.sh")"` + `source "$(include "lib/helpers.sh")"` + `source "$(include "check-deps")"` + `checkDeps "$0"` + `cmdarg_info "$(get-desc "$0")"` + `cmdarg_parse "$@"` with zero user flags — minimal `cmdarg` boilerplate is allowed (mirrors `clangc` minus flag defines; `get-deps` returns `x-none` when empty).
- `# - top` / `awk` etc. one-per-line format — correct even though `checkDep` will check `command -v` for each; pipe not needed here because no alt.
- `top -bn1 | awk '/Cpu\(s\)/ ... 100 - $8'` where `$8` is idle column — correct column on procps `top` (`%Cpu(s): us, sy, ni, id` → field 8 is idle).
- `free -m | awk '/Mem:/ {print $3 "MB"}'` column 3 is used — correct for `free` output.
- `df -h / | awk 'NR==2 {print $4}'` column 4 is Avail — correct for `df -h` (`Filesystem Size Used Avail Use%`).

---

### `catname`

**Path:** `/home/othman/scripts/catname`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Spits out file names' and their content
**Declared dependencies:** `bat | batcat (bat)`
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **What happens:** `bat` invocation lacks `--` sentinel, so files starting with `-` are parsed as options.
- **Where:**
```bash
bat --pager=none --style=header "${file}"
```
- **Why it's wrong:** A file named `-test.txt` becomes an unknown flag; `bat` will error. `clangc:49-53` correctly validates files before passing them; `catname` should similarly guard.
- **Fix:**
```bash
bat --pager=none --style=header -- "${file}"
```

- **What happens:** No validation of `argc`/empty `argv`; running `catname` with no arguments silently does nothing (loop over empty `argv` prints only blank lines).
- **Where:**
```bash
cmdarg_parse "$@"
for file in "${argv[@]}"; do
```
- **Why it's wrong:** Users get no feedback; contrasts with `clangc:44 ((argc < 1)) && log-error "No input files were provided."` which fails loudly. Silent no-op hides typo (`catname` vs `catname foo`).
- **Fix:**
```bash
((argc > 0)) || log-warning "No files provided"
# or fail: ((argc > 0)) || log-error "No files provided"
```

#### Minor / style

- `[[ -f "${file}" ]]` rejects directories, FIFOs, device nodes, and broken symlinks — logs `file 'x' doesn't exist` for a directory `x` which does exist but is not a regular file. Prefer `[[ -e "${file}" ]]` check then branch, or keep `-f` if only regular files intended — document it.
- `printf '\n'` unconditionally after each file adds a trailing blank line after the last file; harmless but differs from typical `cat` behavior.
- `log-warning` (primary wrapper) is used without sourcing `lib/helpers.sh` directly — works because `check-deps:18` sources `helpers` transitively, but explicit `source "$(include "lib/helpers.sh")"` would make the dependency obvious (as `system-stats` does).

#### Confirmed correct (potential false positives)

- `# - bat | batcat (bat)` with `|` alt and `(bat)` pkg override — correct per `checkDep`; `checkDeps` returns 0 if either `bat` or `batcat` is found, else suggests `bat` pkg.
- `set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `source "$(include "lib/cmdarg.sh")"` + `source "$(include "check-deps")"` + `checkDeps "$0"` + `cmdarg_info "$(get-desc "$0")"` + `cmdarg_parse "$@"` — correct even though `lib/helpers.sh` is not sourced explicitly (transitively via `check-deps`).
- Loop `for file in "${argv[@]}"` — correct `cmdarg` positional handling per house brief (`argv`/`argc` hold positionals, not `$@` after parse).
- `bat --pager=none --style=header` flags — intentional to avoid paging in scripts and show filename header.
- `log-warning` as external command (not `logWarning` camelCase) — primary interface per logging two-layer design; `lib/helpers.sh:logWarning` is fallback, not dead code.

---

### `ocrshot`

**Path:** `/home/othman/scripts/ocrshot`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Screen OCR: select a region, copy extracted text to clipboard. Related script: ocr, ocrcp
**Declared dependencies:** `tesseract`, `flameshot`
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **What happens:** Pipeline suppresses all stderr and has no explicit handling for `flameshot` cancel (user presses Esc); failure propagates via `pipefail` + `clipcopy` empty-input check, but diagnostics are hidden.
- **Where:**
```bash
flameshot gui -r 2>/dev/null | tesseract stdin stdout 2>/dev/null | clipcopy

notify-send -a "${BASH_SOURCE[0]##*\/}" "Done!" &
```
- **Why it's wrong:** `2>/dev/null` hides why `flameshot` or `tesseract` failed (missing X/Wayland, `tesseract` language data missing). With `set -eo pipefail`, a cancel (`flameshot` exit 1) makes `tesseract stdin stdout` receive empty stdin → empty output → `clipcopy` sees `str == ""` → `log-error "No valid input was given"` → `kill -SIGUSR1 $PPID` → `ocrshot` dies without user-visible reason. `Done!` notification is never reached on success-path failure and fires even on empty OCR if `clipcopy` succeeded.
- **Fix:**
```bash
tmp="$(mktemp -t ocrshot-XXXX.png)"
trap 'rm -f "${tmp}"' EXIT
if ! flameshot gui -r >"${tmp}" 2>/dev/null; then
  log-warning "Selection cancelled"
  exit 0
fi
if ! text="$(tesseract "${tmp}" stdout 2>/dev/null)"; then
  log-error "Tesseract failed"
fi
[[ -n "${text}" ]] || { log-warning "No text detected"; exit 0; }
printf '%s' "${text}" | clipcopy
notify-send -a "${BASH_SOURCE[0]##*/}" "OCR complete" || true
```

- **What happens:** External commands `clipcopy` (internal repo script) and `notify-send` (libnotify) are used but not declared in `# --- DEPENDENCIES --- #`; `notify-send` absent on minimal installs fails silently due to `&` backgrounding.
- **Where:**
```bash
# --- DEPENDENCIES --- #
# - tesseract
# - flameshot
# --- END SIGNATURE --- #

flameshot gui -r 2>/dev/null | tesseract stdin stdout 2>/dev/null | clipcopy
notify-send -a "${BASH_SOURCE[0]##*\/}" "Done!" &
```
- **Why it's wrong:** `checkDeps` cannot install missing `libnotify`/`clipcopy` prereqs; `notify-send` backgrounded with `&` discards exit status due to `set -e` not applying to background jobs. Similar pattern in `ocrcp` (uses `ocr` + `clipcopy` but declares only `tesseract`) — internal repo deps are conventionally not declared, but `notify-send` is external and should be listed as `notify-send (libnotify)` or `libnotify`.
- **Fix:**
```bash
# --- DEPENDENCIES --- #
# - tesseract
# - flameshot
# - clipcopy
# - notify-send (libnotify)
```

- **What happens:** No `argc` validation — accepts arbitrary positional args silently, ignoring them, because no `cmdarg` flags are defined.
- **Where:**
```bash
cmdarg_info "header" "$(get-desc "$0")"
cmdarg_parse "$@"
flameshot gui -r 2>/dev/null | tesseract stdin stdout 2>/dev/null | clipcopy
```
- **Why it's wrong:** `ocrshot extra args` does the same as `ocrshot`; could confuse users. Should either reject extras (`((argc == 0)) || log-warning "ignoring arguments"`), or document that positionals are ignored.
- **Fix:**
```bash
((argc == 0)) || log-warning "ocrshot takes no arguments — ignoring ${argc} extra"
```

#### Minor / style

- `source "$(include "lib/helpers.sh")"` is sourced but helpers functions (`input`, `Trim`, etc.) are never called directly — only transitively via `clipcopy`/`flameshot`; not wrong, just redundant (compare `catname` which omits it and relies on `check-deps` transitive source).
- `${BASH_SOURCE[0]##*\/}` uses `*\/` escape — works but `##*/` is simpler and unescaped (`${BASH_SOURCE[0]##*/}`); both expand identically.
- `notify-send` backgrounded with `&` — if notification daemon is slow, script may exit before delivery, but `&` also prevents `set -e` from catching failure; prefer `notify-send ... || true` without `&` or explicitly `&` wait.

#### Confirmed correct (potential false positives)

- `# - tesseract` / `flameshot` deps — correct format; `checkDep` will echo `tesseract`/`flameshot` if missing for `installDep`.
- `set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `source "$(include "lib/cmdarg.sh")"` + `source "$(include "lib/helpers.sh")"` + `source "$(include "check-deps")"` + `checkDeps "$0"` + `cmdarg_info "$(get-desc "$0")"` + `cmdarg_parse "$@"` — minimal `cmdarg` with no flags is allowed per house brief (like `system-stats`).
- `flameshot gui -r 2>/dev/null | tesseract stdin stdout 2>/dev/null | clipcopy` — `tesseract stdin stdout` (read PNG from stdin, write text to stdout) is canonical per `tesseract` docs; `stdin`/`stdout` keywords are not filenames.
- `trap 'exit 1' SIGUSR1` alone without `kill` — correct; only `log-error` sends SIGUSR1 per propagation chain.
- `include` with `realpath -m` fallback — not fragile per house brief.

---

## Batch Summary

- **Scripts reviewed:** 4 / 4
- **Critical bugs:** none — no crashes, data loss, or silent wrong results requiring immediate fix. Closest is `ocrshot`'s hidden pipeline failure on cancel, but it still surfaces via `clipcopy`'s `log-error` and SIGUSR1 kill rather than silently corrupting data.
- **Design issues worth escalating:** `init.sh` — hard-coded `/usr/bin/fd` symlink target and implicit `collapseTilde` PATH dependency; `system-stats` — `awk "%.0f%"` non-portable single-percent and `LC_ALL` locale fragility; `catname` — missing `--` sentinel for `bat` and silent no-op on empty `argv`; `ocrshot` — suppressed `2>/dev/null` hiding `flameshot` cancel vs real error, undeclared `clipcopy`/`notify-send (libnotify)` deps, and `notify-send &` background masking failures.
- **Cross-cutting patterns observed in this batch** (same bug/pattern repeated across multiple scripts in this batch only; batch-level, not repo-wide): (1) All 4 correctly use canonical `set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `include` + `checkDeps` + `cmdarg_info/parse` — consistent with `clangc` reference; (2) The 3 small fillers (`system-stats`, `catname`, `ocrshot`) all use minimal `cmdarg` (no flag defines, just `cmdarg_info`/`parse`) and rely on `argv`/`argc` correctly, but `catname`/`ocrshot` both lack empty-`argc` guard (`clangc` checks `((argc <1))`); (3) `system-stats` and `ocrshot` both pipe external tools with `2>/dev/null` suppressing diagnostics, trading debuggability for quiet UX; (4) `init.sh` and `ocrshot` both invoke repo-internal scripts (`collapseTilde` / `clipcopy`) without declaring them in `# --- DEPENDENCIES --- #`, consistent with `ocr`/`ocrcp` family convention but leaving `checkDeps` unable to verify pre-install.
- **Open questions** (design intent unclear, needs the repo owner's input rather than a guess): `init.sh` — Should `fd` symlink target be computed as `$(dirname "$(command -v fdfind)")/fd` with `SUDO_ASKPASS` support, or is `/usr/bin/fd` hard-code intentional for Debian convention? Should `collapseTilde` be replaced with parameter expansion `${configFile/#$HOME/~}` to avoid PATH dependency during bootstrap? `ocrshot` — Is `flameshot` cancel intended to be silent (`exit 0` + `log-warning`) or an error (`log-error`)? Should `notify-send` be a hard dependency or best-effort (`|| true` without `&`)? Should `clipcopy`/`notify-send` be added to the DEPENDENCIES block for discoverability?

---

## Evidence appendix

- `include:19-24` `SCRIPTS_DIR="${HOME}/scripts"` fallback to `dirname BASH_SOURCE[0]` + `realpath -m` — used by all 4 scripts via `source "$(include ...)"`.
- `check-deps:21-51` `checkDep` splits `line` on `|`, `Trim`, `awk '{print $1}'`, `command -v` each alt — validates `fd | fdfind (fd-find)` (init.sh) and `bat | batcat (bat)` (catname).
- `lib/cmdarg.sh:7-8,18-100` `CMDARG_ERROR_BEHAVIOR=return`, `cmdarg "s?[]"` requires `declare -a` pre-exist, booleans default `false` — used correctly in `init.sh:39-42`.
- `lib/helpers.sh:21-32` `input()` stdin-or-args logic, `lib/loggers.sh:322-341` `colorOnlyPrefix` + `LOG_LEVEL_COLORS` — underpins `log-*` two-layer design.
- `lib/helpers.sh:402-408` `yesNo()` reads from `/dev/tty` — used by `init.sh:75,139` symlink and hook install prompts.
- `hooks/path.sh:24-57` `__cacheFile=/tmp/path-hook.cache`, `fd --strip-cwd-prefix -t x` scan, `:":${PATH}:"` guard — PATH registration that `init.sh` installs into rc files.
- `collapseTilde:32` `sed "s|^${HOME}|~|"` with unescaped `${HOME}` — bug noted in batch-08 but reused by `init.sh:128`; `expandTilde:32` sibling uses same unescaped pattern `sed "s|^~|${HOME}|"`.
- `clipcopy:32-44` `str="$(input "${argv[@]}" | ansifilter)"` + `xclip | wl-copy | copyq` dispatch, `[[ -z "${str}" ]] && log-error` — invoked by `ocrshot:35` pipeline; empty `flameshot` cancel triggers this `log-error` + SIGUSR1 kill.
- `ocr:37-58` / `ocrcp:30-41` both use only `# - tesseract` but call `strip-ext`, `clipcopy`, `ocr` internally — precedent for internal-dep omission that `ocrshot` follows.
- `system-stats:35` `top -bn1 | awk '/Cpu\(s\)/ {printf "%.0f%",100-$8}'` single `%` produced `60%` in live `awk` test (gawk accepts, but POSIX expects `%%`); `free -m` / `df -h /` column checks verified live (`free` used MB `9165MB`, `df` Avail `129G`).
- `log-error:58-62` `isInteractiveShell || noKill` guard + `kill -SIGUSR1 "${PPID}"` — propagation chain that `clipcopy:34` empty-input error would trigger from inside `ocrshot` pipeline subshell.

