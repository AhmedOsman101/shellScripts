# Batch Review: 05 of 22

**Scripts in this batch:** `oc-manager`, `customvscode`, `external/colorblocks`, `fd-all` (4 scripts)
**Batch composition:** large+fillers — large standalone `oc-manager` (245 lines) plus 3 small fillers (`customvscode` 21, `external/colorblocks` 22, `fd-all` 22) — pairing is incidental, not a shared pattern. Budget 310 lines, cap 4.
**Reviewer:** subagent-05
**Date:** 2026-08-21

---

## House Style Reference (do not flag these as bugs)

Before reviewing, confirm you've internalized these repo conventions. Restate them here in one line each to prove the context loaded correctly:

- Dependency declaration format (`# - binary | binary2 (pkg-override)`) and how `checkDep` resolves it: deps live between `# --- DEPENDENCIES --- #` and `# --- END SIGNATURE --- #` as `# - exe | alt (pkg)`; `checkDep` splits on `|`, `Trim`s, takes `awk '{print $1}'` per alternative and `command -v` checks each in order — any hit returns 0 satisfied, else echoes `(parens)` package or first exe for `installDep`.
- Logging convention: `log-*` wrapper scripts are primary, camelCase `log*` functions in `lib/helpers.sh` are fallback: standalone `log-debug`/`log-info`/`log-warning`/`log-error`/`log-success` + dispatcher `log.sh` via `LEVEL_COLORS`/`LEVEL_OUTPUT`/`colorOnlyPrefix` are canonical CLI entry points; `lib/helpers.sh` camelCase + `lib/loggers.sh` `printRed`/`hex_to_rgb` are in-process fallback, not dead code, and `log-success` vs `logSuccess` naming is both canonical.
- `trap 'exit 1' SIGUSR1` + `kill -SIGUSR1 "${PPID}"` propagation chain purpose: every script traps SIGUSR1 to `exit 1`; only `log-error` sends `kill -SIGUSR1 "${PPID}"` + `wait` (guarded by `! isInteractiveShell && ! noKill`, suppressed with `|| true`) to kill its parent without explicit exit-code checks.
- `cmdarg.sh` argument-parsing pattern used across scripts: `source "$(include "lib/cmdarg.sh")"` then `cmdarg_info "header" "$(get-desc "$0")"`; pre-declare `declare -a arr`/`declare -A hash` for `[]`/`{}` types; `cmdarg "v"` boolean defaults `"false"`/literal `true` (`if ${cfg['v']}; then`), `"m:"` required string, `"o?"` optional string, `"a?[]"`/`"H?{}"` array/hash; then `cmdarg_parse "$@"` and read `cmdarg_cfg`/`argv`/`argc`; `-h`/`--help` reserved.
- `get-desc` / `get-deps` signature-block parsing rules: both `sed`-parse `# --- DESCRIPTION --- #` … `# --- DEPENDENCIES --- #` … `# --- END SIGNATURE --- #`; missing block is allowed (`get-deps` prints `x-none`, `checkDeps` returns 0, `get-desc` tolerates either terminator); `get-deps` uses `sed -n '/DEPENDENCIES/,/END SIGNATURE/{/\# - /p}'`.
- `init.sh` / `hooks/path.sh` symlink and PATH-registration workflow: `init.sh` verifies `SCRIPTS_DIR` (`~/scripts`), ensures `fd` (prompts `fdfind->fd` symlink), checks `hooks/path.sh`, idempotently appends `[[ -s "${SCRIPTS_DIR}/hooks/path.sh" ]] && source ...` to `~/.bashrc`/`~/.zshrc`; `hooks/path.sh` (sourced at startup, not executed) caches `fd --strip-cwd-prefix=always --no-ignore-vcs -t x . --exclude .git/.venv/...` to `/tmp/path-hook.cache`, rescans only when `find -newer cache`, adds each exe dir once via `:":${PATH}:"` guard, then unsets temps.
- Reference pattern from `clangc` (what "correct" looks like in this repo): `set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `source "$(include "lib/cmdarg.sh")"` + `source "$(include "lib/compile.sh")"` + `source "$(include "check-deps")"` + `checkDeps "$0"` in order; `cmdarg_info`/`declare -a compiler_args`/`cmdarg "c"`/`"o?"`/`"a?[]"`/`"q"`/`cmdarg_parse "$@"`; literal `cmdarg_cfg` reads, `((argc <1)) && log-error`, array-safe delegation via namerefs.

---

## Script Reviews

### `oc-manager`

**Path:** `/home/othman/scripts/oc-manager`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): A script for managing OpenCode web interface instances
**Declared dependencies:** `opencode | opencode (opencode-bin)`, `ansifilter`, `watchexec`
**Verdict:** `Needs fixes`

#### Critical bugs

- **What happens:** `oc-manager` uses `rg` (ripgrep) twice to parse the server log for URLs, but `rg` is not declared in `DEPENDENCIES`; if `rg` is absent the 15s wait loop always times out and fails with a generic timeout, hiding the real cause. Exit path for unknown subcommands and missing subcommand also always exits 0 (success) instead of error.
- **Where:**

```bash
# oc-manager:17-19
# - opencode | opencode (opencode-bin)
# - ansifilter
# - watchexec
```

```bash
# oc-manager:160-161
    localUrl="$(logContent | rg -i 'Web interface:|Local access:' | awk '{ print $3 }' || true)"
    mapfile -t networkUrls < <(logContent | rg -i 'Network access:' | awk '{ print $3 }' || true)
```

```bash
# oc-manager:48-60 & 65,244
cmdarg_usage() {
  echo "${usageMsg}"
  cat <<EOF

Subcommands:
    start        Start the OpenCode web interface server
    stop|kill    Stop the running server and config watcher
    restart      Restart the server (stop then start)
    status       Show PID and access URLs
    pid          Show only the server PID
EOF
  exit "${2:-0}"
}
# ...
((argc)) || cmdarg_usage
# ...
  ? | *) cmdarg_usage 2 ;;
```

- **Why it's wrong:**
  - `rg` is an external binary (like `fd`, `parallel` declared elsewhere); `checkDep` cannot prompt to install it and `checkDeps` passes even when `rg` missing. Under `set -o pipefail`, `logContent | rg ...` exits 1 when `rg` not found or pattern not matched, but `|| true` suppresses it, so the loop spins 15×1s then hits `log-error "Timeout waiting for OpenCode to start (check ${logFile})"` — 15s wasted and error message points at the log, not at the missing tool.
  - `cmdarg_usage` references `${2:-0}` but is called as `cmdarg_usage` (no args) and `cmdarg_usage 2` (one arg). `$2` is always empty, so `${2:-0}` always expands to `0`. An unknown action like `oc-manager bogus` therefore exits 0, violating the contract that error paths exit non-zero. `((argc)) || cmdarg_usage` with no subcommand also exits 0 (should be non-zero/help error). Reference `init.sh:48-56` correctly uses `exit "${1:-0}"`; this script copy-pasted with the wrong positional index.
- **Fix:**

```bash
# --- DEPENDENCIES --- #
# - opencode | opencode (opencode-bin)
# - ansifilter
# - watchexec
# - rg (ripgrep)
# --- END SIGNATURE --- #
```

```bash
cmdarg_usage() {
  echo "${usageMsg}"
  cat <<EOF

Subcommands:
    start        Start the OpenCode web interface server
    stop|kill    Stop the running server and config watcher
    restart      Restart the server (stop then start)
    status       Show PID and access URLs
    pid          Show only the server PID
EOF
  exit "${1:-0}"
}
# and at call sites:
((argc)) || cmdarg_usage 2
# ...
  ? | *) cmdarg_usage 2 ;;
# (or keep bare cmdarg_usage for help, but error cases must pass 2 as $1)
```

Optional: add early `command -v rg &>/dev/null || log-error "rg (ripgrep) is required but not installed"` before the wait loop if keeping the `DEPENDENCIES` declaration is insufficient for local runs.

#### Design issues

- **What happens:** `isRunning() { [[ -s "${lockFile}" ]]; }` treats any non-empty lock file as "running" without checking if the recorded PID is still alive; a crashed `opencode` leaves a stale `lockFile`, then `start` incorrectly `terminate`s with "already running" and `status`/`pid` report the stale PID.
- **Where:**

```bash
# oc-manager:108,140-141,195-196,207-208,230-231
isRunning() { [[ -s "${lockFile}" ]]; }
# ...
  isRunning && terminate "OpenCode is already running with pid: $(pid), check '${scriptName} status'."
```

- **Why it's wrong:** lock file is not a reliable liveness indicator; PID could be reused or dead. `hooks/path.sh` and `init.sh` already show the canonical liveness check `kill -0 "$pid" 2>/dev/null`. Stale locks require manual `rm /tmp/oc-manager/lock`.
- **Fix:** make `isRunning` check liveness, e.g.:

```bash
isRunning() { [[ -s "${lockFile}" ]] && kill -0 "$(head -n1 "${lockFile}" 2>/dev/null)" 2>/dev/null; }
# or
isRunning() { [[ -s "${lockFile}" ]] && ps -p "$(viewlines 1 "${lockFile}" 2>/dev/null)" &>/dev/null; }
```

and update `start`/`status`/`pid` callers to handle the stale-file cleanup path.

- **What happens:** `cacheDir="/tmp/${scriptName}"` is world-shared (`/tmp/oc-manager`) with no per-user namespacing or `mktemp`; on multi-user hosts another user can pre-create or symlink the path to hijack `lockFile`/`logFile`.
- **Where:**

```bash
# oc-manager:81-85
cacheDir="/tmp/${scriptName}"
lockFile="${cacheDir}/lock"
logFile="${cacheDir}/log"
watchPidFile="${cacheDir}/watch"
watchLog="${cacheDir}/watch.log"
```

- **Why it's wrong:** `/tmp` is shared; canonical fix is `${XDG_RUNTIME_DIR:-/tmp}/oc-manager-${UID}` or `mktemp -d` + `trap 'rm -rf'`. Not exploitable on single-user desktop but diverges from secure-tempdir practice.
- **Fix:** `cacheDir="${XDG_RUNTIME_DIR:-/tmp}/oc-manager-${UID}"` or `cacheDir="$(mktemp -d "/tmp/${scriptName}.XXXXXX")"` with cleanup, or at least `mkdir -p "${cacheDir}" && chmod 700 "${cacheDir}"`.

- **What happens:** `trim "${lockFile}" &>/dev/null` edits the lock file in place via `trim` (which `sed -i` strips leading/trailing spaces per line and `log-success`es), suppressed to `/dev/null`; not needed (PID/URLs have no surrounding whitespace) and silently invokes a file-edit + logging side effect in the middle of `start`.
- **Where:**

```bash
# oc-manager:172-178
  {
    printf '%d\n' "${PID}"
    printf '%s\n' "${localUrl}"
    printf '%s\n' "${networkUrls[@]}"
  } >"${lockFile}"

  trim "${lockFile}" &>/dev/null
```

- **Why it's wrong:** `trim` is a file-mutating helper (`trim:44-51` does `sed -i` + `log-success`); calling it here adds an implicit dependency (`trim`, `viewlines`, `killwait` are internal scripts exposed only via `hooks/path.sh` PATH hook) and a suppressed success log. If `hooks/path.sh` has not yet added the script dir to PATH (e.g. in a non-interactive shell), `trim` may not be found under `set -e`.
- **Fix:** remove the line (URLs need no trimming), or guard: `command -v trim &>/dev/null && trim "${lockFile}" &>/dev/null || true`. Prefer removal.

- **What happens:** `printf '%s\n' "${networkUrls[@]}"` when `networkUrls` is empty still emits one blank line (bare `printf '%s\n'` prints a newline), so `lockFile` gains a trailing empty line and `status`'s `mapfile -t net < <(tail -n +3 "${lockFile}")` yields `net=("")` (length 1) instead of empty, printing `Network Access:` with an empty string rather than `N/A`.
- **Where:**

```bash
# oc-manager:172-176 & 217-218
  {
    printf '%d\n' "${PID}"
    printf '%s\n' "${localUrl}"
    printf '%s\n' "${networkUrls[@]}"
  } >"${lockFile}"
# ...
  mapfile -t net < <(tail -n +3 "${lockFile}")
  if ((${#net[@]})); then
```

- **Why it's wrong:** empty-array expansion with `printf` is a classic bash pitfall; status branch is then never taken as `N/A`.
- **Fix:**

```bash
  {
    printf '%d\n' "${PID}"
    printf '%s\n' "${localUrl}"
    ((${#networkUrls[@]})) && printf '%s\n' "${networkUrls[@]}"
  } >"${lockFile}"
```

and in `status` filter empties: `mapfile -t net < <(tail -n +3 "${lockFile}" | grep -v '^$')` or `[[ -n "${net[0]}" ]]`.

- **What happens:** `declare localUrl PID` at top level and `local prefix len="${#networkUrls[@]}"` inside `start` rely on implicit `declare` without `-g`/`-a`; `networkUrls` is global `-a` but reassigned via `mapfile -t networkUrls` inside the function, mixing scopes.
- **Where:**

```bash
# oc-manager:77-78 & 158-182
declare localUrl PID
declare -a networkUrls
# ...
start() {
  local maxWait=15 waited=0
  while ((waited < maxWait)); do
    mapfile -t networkUrls < <(...)
```

- **Why it's wrong:** not a runtime bug but fragile scoping; `localUrl`/`PID` are global due to top-level `declare`, yet `start` also assigns `PID=$!` and `localUrl` without `local`. Works but diverges from `clangc` reference which keeps `declare -a files` at top and passes array names via namerefs. Low severity.
- **Fix:** declare `localUrl`/`PID` as `declare -g` or move into `start` as `local`, and mark `networkUrls` global explicitly (`declare -g -a networkUrls`) or pass via nameref. No functional change.

- **What happens:** `opencode | opencode (opencode-bin)` lists the same exe twice; second alternative is redundant (both resolve to `command -v opencode`).
- **Where:**

```bash
# oc-manager:17
# - opencode | opencode (opencode-bin)
```

- **Why it's wrong:** `checkDep` splits on `|`, so both fields test `opencode`; the `(opencode-bin)` package override is only meaningful on the branch where `opencode` is missing, but both branches test the same binary. Likely intended `opencode-bin | opencode` or a distinct alternative. Not a bug — `checkDep` still correctly reports `opencode-bin` package when missing — but the self-fallback is redundant.
- **Fix:** keep as-is or clarify to `# - opencode (opencode-bin)` (single entry with override), matching `clangc`'s single `clang` entry style. Keep pipe only if a second binary name exists.

#### Minor / style

- Boolean flags quoted as `"${mdns}" && args+=("--mdns")` — works (`"true"` still executes as `true`) but canonical house style is unquoted `${cmdarg_cfg['x']}` (`if ${cfg['v']}; then`). Keep or unquote: `${mdns} && args+=("--mdns")`. Not a bug.
- `using watchexec` with `-f "opencode.json" -f "opencode.jsonc" -d 5s -p -r` is correct; `hooks/path.sh` already excludes `release.sh` etc., but `watchexec` watching `configDir` recursively may trigger on temp files — limited to two filters so intentional.
- `logContent()` wraps `ansifilter "${logFile}"` (file arg, not stdin) — `ansifilter` supports file arg; `echo ""` fallback for missing log is intentional to make `rg` pipeline return empty, not error.

#### Confirmed correct (potential false positives)

- `# - opencode | opencode (opencode-bin)` pipe + parens is correct `checkDep` syntax per house-style-brief §2; `checkDep` splits on `|` then `Trim` then `awk '{print $1}'` per alternative, `command -v` order matters — not a syntax error.
- `set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `source "$(include "lib/cmdarg.sh")"` + `source "$(include "lib/helpers.sh")"` + `source "$(include "check-deps")"` + `checkDeps "$0"` + `cmdarg_info "header" "$(get-desc "$0")"` + `declare -a corsDomains` before `cmdarg "c?[]"` + `cmdarg_parse "$@"` order exactly matches `clangc` reference; overriding `cmdarg_usage` after `usageMsg="$(cmdarg_usage)"` + `unset -f 'cmdarg_usage'` is the same pattern as `init.sh:42-56`, not a missing-help bug (only the `$2` index is wrong, flagged above).
- `"${mdns}" && args+=("--mdns")` / `"${pure}" && args+=("--pure")` boolean literal `true`/`false` usage is canonical `cmdarg.sh` boolean handling per brief §5; `if ${cmdarg_cfg['verbose']}; then` is the documented form.
- `trap 'exit 1' SIGUSR1` without a matching `kill` in this file is correct per brief §4 — only `log-error` sends `kill -SIGUSR1 "${PPID}"`, trap is for when this script is the parent.
- `((++waited))` pre-increment under `set -e` is correct; `((waited++))` would have triggered `set -e` on the first 0→1 transition — not flagged.
- `trim`/`viewlines`/`killwait` not listed in `DEPENDENCIES` is correct — they are internal repo scripts exposed via `hooks/path.sh` PATH hook (brief §7), not external packages for `checkDep`/`installDep`.
- `OPENCODE_SERVER_PASSWORD="${password:-${OPENCODE_SERVER_PASSWORD}}"` fallback to env is intentional; `password` defaults to `""` (optional `s?`), so `${var:-fallback}` correctly preserves an existing env when flag not given.
- `ansifilter` in `DEPENDENCIES` is not stale — `logContent()` calls `ansifilter "${logFile}"` on `oc-manager:102`.

---

### `customvscode`

**Path:** `/home/othman/scripts/customvscode`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): none declared — file contains no signature block (no `# --- DESCRIPTION --- #` / `# --- DEPENDENCIES --- #` / `# --- END SIGNATURE --- #`; `get-desc` returns empty, `get-deps` returns `x-none`)
**Declared dependencies:** none declared
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **What happens:** script runs `sudo chown -R "$(whoami)"` recursively on system paths (`/opt/visual-studio-code`, `/usr/share/code`, `/opt/cursor`, etc.) without confirmation, without checking ownership first, and without `set -eo pipefail`/`trap`/`log-*` error handling; a typo in a future path addition would recursively chown the wrong tree, and `sudo` will prompt for password non-interactively in a way that `log-error` cannot propagate via SIGUSR1.
- **Where:**

```bash
# customvscode:3-18
if command -v code &>/dev/null; then
  sudo chown -R "$(whoami)" "$(command -v code)" 2>/dev/null
  sudo chown -R "$(whoami)" /opt/visual-studio-code 2>/dev/null
  sudo chown -R "$(whoami)" /usr/share/code 2>/dev/null
fi
```

- **Why it's wrong:** `chown -R` on system directories is destructive and not guarded by `getPackageManager`/`installDep` or `yesNo` (cf. `init.sh:75` which asks before `sudo ln`). The `2>/dev/null` suppression hides real errors (e.g. `sudo` failure, missing path). Works as a personal convenience helper but diverges from `lib/helpers.sh`/`log.sh` logging and `clangc` `set -eo pipefail` + `trap` invariants.
- **Fix:** add `set -eo pipefail; trap 'exit 1' SIGUSR1` + `source "$(include "lib/helpers.sh")"` + use `log-info`/`log-warning` for each `chown`, check `[[ -e "${path}" ]]` before `chown`, and consider `yesNo "chown ${path} to $(whoami)?"` guard or at least `log-warning` before the destructive operation. Keep `2>/dev/null` only for the expected "path does not exist" case, not for `sudo` failures.

- **What happens:** `$(command -v code)` when `code` is a shell alias or function expands to the alias text, not a filesystem path; `chown` then operates on a non-path string and fails silently.
- **Where:**

```bash
# customvscode:4
  sudo chown -R "$(whoami)" "$(command -v code)" 2>/dev/null
```

- **Why it's wrong:** `command -v` without `command -v --` or `type -p` can return shell aliases; `chown` error is suppressed, so the intended `code` binary directory is never fixed, but `/opt/visual-studio-code` still is.
- **Fix:** use `command -v -- code` or `type -p code` or `which code 2>/dev/null`, and only chown if result is a file: `bin="$(command -v -- code 2>/dev/null)" && [[ -f "${bin}" ]] && sudo chown -R "$(whoami)" "${bin}"`.

#### Minor / style

- No `# --- SCRIPT SIGNATURE --- #` / `# --- DESCRIPTION --- #` / `# --- DEPENDENCIES --- #` block. Per house-style-brief §6 missing block is allowed ( `get-deps` prints `x-none`, `checkDeps` returns 0), so not a bug, but this script will not appear in `get-desc`/`Home.md` indexing via `create-wiki`. Add a minimal signature if it should be documented; leave as-is if intentionally private.
- No `set -eo pipefail` / `trap 'exit 1' SIGUSR1` / `source "$(include ...)"` / `checkDeps` — intentional for a tiny `sudo chown` shim, but any future `set -u` or `pipefail` caller sourcing this file would inherit no guard. Adding the `clangc` preamble is low cost if the script grows.
- Hard-coded paths `/opt/visual-studio-code`, `/usr/share/code`, `/opt/cursor`, `/usr/lib/cursor`, `/opt/antigravity-ide`, `/usr/lib/antigravity-ide` cover current packaging for Code/Cursor/Antigravity on Arch/Debian, but distro-specific alternatives (e.g. `~/.vscode`, `/snap/code`) are not handled — document as best-effort personal helper, not portable.

#### Confirmed correct (potential false positives)

- Missing `DEPENDENCIES` block is allowed per house-style-brief §6 — `get-deps` would emit `x-none` and `checkDeps` would return 0, so the absence of `# - code` etc. is not a missing-dep bug; `sudo`/`chown`/`whoami` are coreutils per `AGENTS.md` exclusion list, correctly not declared.
- `command -v code &>/dev/null` as existence test before `chown` is correct; the `include` indirection (`source "$(include "lib/helpers.sh")"`) is not required here because the script does not use `log-*`/`cmdarg.sh`/`checkDeps`.
- `exit 0` unconditional at `customvscode:21` is intentional — script reports success even when no editor is installed (no `command -v` hit), which matches its role as a best-effort permission fixer, not a status checker.

---

### `external/colorblocks`

**Path:** `/home/othman/scripts/external/colorblocks`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): none declared — file is an `external/` text-art asset (no `# --- DESCRIPTION --- #` block; header comments cite `colorblocks.textart`, author Adhi Pambudi, converted by NNB, URL `https://github.com/NNBnh/nnbs-text-art`)
**Declared dependencies:** none
**Verdict:** `Clean`

#### Critical bugs

None found.

#### Design issues

None found.

#### Minor / style

None found. — intentional `external/` demo asset; adding a `clangc`-style preamble (`set -eo pipefail`, `trap`, `checkDeps`) would add no signal for a 4-line `printf` + `exit 0`.

#### Confirmed correct (potential false positives)

- Raw ANSI `\e[41m`/`\e[101m` etc. hardcoded in `printf` at `external/colorblocks:17-20` is intentional for a color demo; not flagged as "use `loggers.sh` `printRed`/`printHex`" — `lib/loggers.sh` is for structured `log-*` output (`colorOnlyPrefix`), raw escapes are correct for an art demo that intentionally bypasses `supportsColor` (`NO_COLOR`/`CI`/TTY) gating.
- No `set -eo pipefail` / `trap 'exit 1' SIGUSR1` / `source "$(include ...)"` / `# --- SCRIPT SIGNATURE --- #` is correct for `external/` vendored text-art; per house-style-brief §6 missing signature is allowed, and `hooks/path.sh:27-32` explicitly `--exclude .git` etc. but does not exclude `external/` executables — the file is intentionally executable and on PATH via the hook.
- `exit 0` at `external/colorblocks:22` is intentional; no `log-success`/`log-error` needed for a visual demo.

---

### `fd-all`

**Path:** `/home/othman/scripts/fd-all`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): simple fd wrapper with nothing ignored
**Declared dependencies:** none declared (empty `DEPENDENCIES` block)
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **What happens:** script declares no `fd` dependency and hard-codes `fd` binary name, so on Debian systems where the binary is `fdfind` and the `init.sh` symlink (`/usr/bin/fd -> $(command -v fdfind)`) was declined, `fd-all` fails even though `checkDep` would have considered `fdfind` sufficient, and `init.sh:73-82` already documents the `fd | fdfind (fd-find)` fallback.
- **Where:**

```bash
# fd-all:12-22
# --- DESCRIPTION --- #
# simple fd wrapper with nothing ignored
# --- END SIGNATURE --- #

set -eo pipefail
trap 'exit 1' SIGUSR1

# ---  Main script logic --- #
fd --no-ignore --hidden --no-require-git "$@"
```

- **Why it's wrong:** `DEDEPENDENCIES` declares nothing, so `getDeps` returns `x-none` and `checkDeps` (not even called) never prompts to install `fd-find`; direct `fd` invocation lacks the `command -v fd || command -v fdfind` fallback that `check-deps:27-37` and `init.sh` already handle. House-style-brief §2 says `fd | fdfind (fd-find)` pipe is the correct declaration, and brief §7 says `hooks/path.sh` only adds script dirs to PATH, not `fdfind` symlinks.
- **Fix:** add dependency and either delegate to `fd.sh` wrapper (which centralizes the fallback) or handle fallback inline:

```bash
# --- DEPENDENCIES --- #
# - fd | fdfind (fd-find)
# --- END SIGNATURE --- #

set -eo pipefail
trap 'exit 1' SIGUSR1

source "$(include "check-deps")"
checkDeps "$0"

# ---  Main script logic --- #
# Prefer fd.sh wrapper that already handles fdfind fallback:
fd.sh --no-ignore --hidden --no-require-git "$@"
# or inline: "${FD:-$(command -v fd || command -v fdfind)}" --no-ignore --hidden --no-require-git "$@"
```

- **What happens:** script omits `source "$(include "lib/helpers.sh")"` / `source "$(include "check-deps")"` / `checkDeps "$0"` preamble that `clangc:24-27` and `log.sh:23-25` use; dependency validation is therefore skipped.
- **Where:** `fd-all:18-22` (no `source`/`checkDeps` lines)
- **Why it's wrong:** diverges from `clangc` reference pattern without a stated reason; not a runtime bug today (single `fd` call), but inconsistent with `init.sh`'s `fd` prerequisite chain.
- **Fix:** add the three preamble lines as shown above, or document that `fd` is pre-validated by `init.sh` and intentionally leave `checkDeps` out. Low severity.

#### Minor / style

- `trap 'exit 1' SIGUSR1` present without a matching `kill` is intentional per brief §4 — only `log-error` sends `kill -SIGUSR1 "${PPID}"`; do not flag as suspicious.
- `fd --no-ignore --hidden --no-require-git "$@"` correctly forwards all args; no quoting issue.

#### Confirmed correct (potential false positives)

- `set -eo pipefail` + `trap 'exit 1' SIGUSR1` present at `fd-all:18-19` — correct even though this leaf script never sends SIGUSR1 itself (only `log-error` does); brief §4 says every script should trap, not every script should kill.
- Empty `DEPENDENCIES` block (`# --- DEPENDENCIES --- #` immediately followed by `# --- END SIGNATURE --- #`) is allowed per brief §6 — if the script intentionally has no deps, `get-deps` printing `x-none` is not a bug (though here `fd` should be listed, flagged above as a design gap, not a parse error).
- `--no-ignore --hidden --no-require-git` are correct `fd` flags for "nothing ignored" semantics; not flagged as missing `--no-ignore-vcs` (that's `fd.sh`/`hooks/path.sh` specific, `fd` upstream supports both).
- `source "$(include "lib/helpers.sh")"` absence is not flagged as broken `include` indirection — `include:19-26` `realpath -m` + `[[ -f "${file}" ]] && echo "${file}"` is intentional, and this script simply chooses not to source it.

---

## Batch Summary

- **Scripts reviewed:** 4 / 4
- **Critical bugs:** `oc-manager` — 1) missing `rg (ripgrep)` in `DEPENDENCIES` causes 15s silent timeout with generic `log-error` instead of a `checkDep` install prompt; 2) `cmdarg_usage` uses `${2:-0}` instead of `${1:-0}` so `oc-manager bogus` / missing subcommand always exits 0 (should exit 2). No critical bugs in `customvscode`, `external/colorblocks`, `fd-all`.
- **Design issues worth escalating:** `oc-manager` — stale `isRunning` without `kill -0` liveness, world-shared `/tmp/${scriptName}` not per-user/`XDG_RUNTIME_DIR`, unnecessary `trim "${lockFile}"` mutation, empty-array `printf '%s\n' "${networkUrls[@]}"` blank-line bug causing `status` to never show `N/A`. `fd-all` — missing `fd | fdfind (fd-find)` dependency and `checkDeps`/`fd.sh` fallback (hard-coded `fd` breaks Debian `fdfind` installs). `customvscode` — destructive `sudo chown -R` without guard/confirmation and `command -v code` alias pitfall (suppressed errors).
- **Cross-cutting patterns observed in this batch** (same bug/pattern repeated across multiple scripts in this batch only; batch-level, not repo-wide):
  - No batch-wide repeated bug — `oc-manager` is the only `cmdarg.sh`/`checkDeps`/`log-*` consumer in this batch, so its `cmdarg_usage` `$2` bug and missing `rg` dep do not repeat across `customvscode`/`external/colorblocks`/`fd-all`. The three fillers are all intentionally minimal (no `cmdarg`, no `log-*`, no `checkDeps`), which is consistent for tiny shims/demos, not a shared omission.
  - `customvscode` and `fd-all` both suppress errors with `2>/dev/null` on expected-missing paths, but for different reasons (`sudo chown` non-existent `/opt/...` vs `fd-all` missing binary) — not a shared root cause to fix collectively.
- **Open questions** (design intent unclear, needs the repo owner's input rather than a guess):
  - `oc-manager` `isRunning` — is a stale `lockFile` after a crash supposed to require manual `oc-manager stop`/`rm /tmp/oc-manager/lock`, or should `isRunning`/`start` auto-detect dead PID via `kill -0` and auto-clean?
  - `oc-manager` `cacheDir` — is `/tmp/${scriptName}` intentionally shared (single-user desktop assumption) or should it be `${XDG_RUNTIME_DIR:-/tmp}/oc-manager-${UID}` / `mktemp -d` for multi-user safety?
  - `oc-manager` `trim "${lockFile}"` — was the `trim` call intended to sanitize `localUrl`/`networkUrls` whitespace, or is it leftover from debugging and safe to remove?
  - `customvscode` — is the recursive `sudo chown -R` on `/opt/...`/`/usr/share/code` intentional for a personal Arch setup, or should it be gated behind `yesNo` / `log-warning` like `init.sh`'s `fdfind` symlink prompt?
  - `fd-all` — should it stay a zero-dep shim (relying on `init.sh`'s `fd` guarantee) or gain the canonical `fd | fdfind (fd-find)` dependency + `checkDeps` + `fd.sh` delegation like other `fd`-based helpers (`load-fonts`, `create-wiki`)?

---

## Evidence Appendix (optional)

- House style brief: `/home/othman/scripts/docs/code-reviews/house-style-brief.md:1-68`
- Core files read: `include:1-26`, `lib/cmdarg.sh:1-462`, `lib/loggers.sh:1-341`, `lib/helpers.sh:1-420`, `check-deps:1-175`, `log.sh:1-66`, `get-desc:1-53`, `get-deps:1-39`, `init.sh:1-158`, `hooks/path.sh:1-86`, `clangc:1-67`
- Batch scripts read: `oc-manager:1-245`, `customvscode:1-21`, `external/colorblocks:1-22`, `fd-all:1-22`
- Supporting reads: `killwait:1-39`, `trim:1-57`, `viewlines:1-67`, `fd.sh:1-43` (via grep), `batch-01.md:1-385`, `batch-02.md:1-212` (template style reference)
- Verification: `grep -R "killwait|trim|viewlines" /home/othman/scripts --exclude-dir=bin --exclude-dir=.git` confirmed `oc-manager:113,178-178,199,214,232` internal helper usage; `grep -R "rg " /home/othman/scripts` confirmed `oc-manager:160-161` only `rg` consumer without dep; `cat hooks/path.sh` confirmed PATH hook caching, not per-script concern.
