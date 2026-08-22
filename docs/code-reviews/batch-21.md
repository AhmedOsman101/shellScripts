# Batch Review: 21 of 22

**Scripts in this batch:** `lua/sec2time.lua`, `get-askpass`, `no-dups`, `make-caddy`, `mdfmt`, `cpu-usage`, `phpfmt`, `pkg-files`, `clipcopy`, `ocrcp`
**Batch composition:** grab-bag (small-grab) — 10 scripts, 654 lines, under 12 cap. No single family; mix of lua, get-askpass, no-dups, make-caddy, mdfmt — no single family, header note grab-bag.
**Reviewer:** subagent-21
**Date:** 2026-08-21

---

## House Style Reference (do not flag these as bugs)

Before reviewing, confirm you've internalized these repo conventions. Restate them here in one line each to prove the context loaded correctly:

- Dependency declaration format (`# - binary | binary2 (pkg-override)`) and how `checkDep` resolves it: Between `# --- DEPENDENCIES --- #` and `# --- END SIGNATURE --- #` as `# - exe | alt (pkg)`; `check-deps:21` splits on `|`/Trims, `command -v` each bare exe in order and returns 0 if any exists, else echoes parenthesized override or first exe for `installDep`→`getPackageManager`.
- Logging convention: `log-*` wrapper scripts are primary, camelCase `log*` functions in `lib/helpers.sh` are fallback: `log.sh:28` maps `LEVEL→(colorFunc, fd)` to `colorOnlyPrefix`; `lib/helpers.sh:34` camelCase `logInfo`/`logError` etc. are in-process fork-free fallbacks — `log-error` delegating to `log.sh:52` is not dead code.
- `trap 'exit 1' SIGUSR1` + `kill -SIGUSR1 "${PPID}"` propagation chain purpose: Every script sets `set -eo pipefail`+`trap 'exit 1' SIGUSR1`; only `log-error:58` (guarded by `! isInteractiveShell && ! noKill`) signals `PPID` to propagate fatal without exit-code checks — trap alone is expected.
- `cmdarg.sh` argument-parsing pattern used across scripts: `source "$(include "lib/cmdarg.sh")"` → `cmdarg_info "header" "$(get-desc "$0")"` → pre-declare `declare -a arr; declare -A map` before `cmdarg "v" "verbose"`/`"m:"` required/`"o?"` optional/`[]` array/`{}` hash → `cmdarg_parse "$@"` → read `cmdarg_cfg['key']` (booleans literally `true`/`false` executable) and positionals via `argv`/`argc`.
- `get-desc` / `get-deps` signature-block parsing rules: Both `sed -n` the `# --- DESCRIPTION --- #`→`# --- DEPENDENCIES --- #`→`# --- END SIGNATURE --- #` block; `get-desc:42` tolerates either terminator, `get-deps:37` extracts `# - ` lines via `replace.sh`/`sed` and prints `x-none` if empty — missing sections are allowed.
- `init.sh` / `hooks/path.sh` symlink and PATH-registration workflow: `init.sh:63` verifies `SCRIPTS_DIR`/`fd`/`hooks/path.sh` then idempotently appends `[[ -s "${SCRIPTS_DIR}/hooks/path.sh" ]] && source ...` to `~/.bashrc`/`~/.zshrc`; `hooks/path.sh:20` sourced at shell startup caches `fd -t x` to `/tmp/path-hook.cache` and appends each exe's dir to `PATH` once — scripts need not manage PATH.
- Reference pattern from `clangc` (what "correct" looks like in this repo): `clangc:21` canonical order `set -eo pipefail`+`trap`+`source "$(include "lib/cmdarg.sh")"`+`source "$(include "lib/compile.sh")"`+`source "$(include "check-deps")"`+`checkDeps "$0"` → `cmdarg_info`+pre-declare `compiler_args`+`cmdarg "c"`/`"o?"`/`"a?[]"`/`"q"`→`cmdarg_parse "$@"`→`${cmdarg_cfg[...]}` reads+`((argc<1))&&log-error`+safe arrays+nameref delegation.

---

## Script Reviews

### `lua/sec2time.lua`

**Path:** `/home/othman/scripts/lua/sec2time.lua`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): No bash signature block (Lua script) — inferred from code: convert seconds (arg 1) to human-readable duration, optional `-s`/`--short` (arg 2) for abbreviated units.
**Declared dependencies:** none (Lua, no bash deps block)
**Verdict:** `Needs fixes`

#### Critical bugs

- **Error handling via `os.execute("log-error …")` does not terminate and kills wrong PID:**

  ```lua
  -- sec2time.lua:3
  if arg[1] == nil then os.execute("log-error 'Seconds must be provided'") end
  -- sec2time.lua:12
  if seconds == nil then os.execute("log-error 'seconds must be a number'") end
  ```

  - **What happens:** Both branches log but fall through. `arg[1]==nil` → `tonumber(nil)` → `nil` → `math.floor(nil or 0)` → `0` → `print("")` empty output instead of fatal. Invalid number similarly yields empty output with stray `[ERROR]` on stderr but exit 0.
  - **Why it's wrong:** `os.execute` spawns `sh -c "log-error …"`; `log-error:60` does `kill -SIGUSR1 "${PPID}"` where PPID is the intermediate `sh`, not the Lua process. Lua never traps SIGUSR1, and `os.execute` return value is unchecked. No `os.exit` follows, so mutation of `seconds` continues.
  - **Fix:**

  ```lua
  if arg[1] == nil then io.stderr:write("[ERROR] Seconds must be provided\n"); os.exit(1) end
  local seconds = tonumber(arg[1])
  if seconds == nil then io.stderr:write("[ERROR] seconds must be a number\n"); os.exit(1) end
  -- or if repo logging required: os.execute("log-error '...'"); os.exit(1)
  ```

- **Zero/negative input yields empty output (no unit emitted):**

  ```lua
  -- sec2time.lua:14-70
  seconds = math.floor(seconds or 0)
  -- getSuffix returns nil when time==0, so 0 seconds → output={} → len=0 → result="" → print("")
  ```

  - **What happens:** `sec2time.lua 0` prints blank line; `-5` likewise blank. Expected `0s` / `0 seconds` or error.
  - **Why it's wrong:** All four `getSuffix` calls guard `if time > 0`, so no suffix for remainder <1s. No fallback.
  - **Fix:**

  ```lua
  if #output == 0 then print(isShort and "0s" or "0 seconds"); return end
  -- or validate seconds>=0 early: if seconds<0 then error
  ```

#### Design issues

- **Mixing Bash logger from Lua:** Relies on `log-error` being in PATH via `hooks/path.sh` and on SIGUSR1 propagation that doesn't reach Lua. Pure Lua `io.stderr` + `os.exit` is more portable and avoids shell injection surface.

- **Hidden mutation of outer `seconds` inside `getSuffix`:** `getSuffix` captures and mutates outer `seconds` via `seconds = seconds % unit` (`sec2time.lua:29`). Works but side-effect is invisible at call sites; passing `seconds` by value and returning remainder would be clearer.

- **No validation for negative or fractional seconds before floor:** `tonumber("-3.7")` → `-3.7` → `math.floor` → `-4` → blank output. Should `log-error` on `seconds < 0`.

#### Minor / style

- **`isShort` only checks `arg[2]`:** Conventional `lua sec2time.lua -s 90` would treat `-s` as seconds; flag should be position-independent or use loop over `arg`. Low risk for current `sec2time.lua <seconds> [-s]` contract.

- **String building via `result = result .. output[i]` loop:** Could use `table.concat(output, sep)` with computed separator, but current loop correctly handles Oxford comma vs short-space.

- **Shebang `#!/usr/bin/env lua`:** On Arch `lua` may be `lua5.4`; `lua` symlink not guaranteed — `lua` vs `lua5.4` portability nit.

#### Confirmed correct (potential false positives)

- `ONE_DAY`/`ONE_HOUR`/`ONE_MINUTE` constants and `seconds / unit` + `% unit` breakdown correctly decompose duration; `math.floor(seconds / unit)` not naive `seconds // unit` — correct for Lua 5.3+ compatibility.
- `suffixes.short` vs `single`/`multiple` branching (`time==1`) handles pluralization correctly — not flagged.
- `os.execute("log-error …")` string is constant (no user interpolation), so shell injection not present — pattern is fragile but not exploitable here.

---

### `get-askpass`

**Path:** `/home/othman/scripts/get-askpass`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Returns a suitable askpass program for `sudo -A`
**Declared dependencies:** none
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **Full duplication of `check-deps` askpass logic (`checkTerminal` + graphical probing) — drift risk:**

  ```bash
  # get-askpass:34-46 vs check-deps:54-66 identical
  checkTerminal() {
    if command -v whiptail >/dev/null 2>&1; then
      echo "/bin/sh -c 'whiptail --passwordbox \"Authentication Required\" 8 40 2>&1 >/dev/tty; echo \$?'"
  ```

  - **Why:** Same 30-line cascade copied verbatim; fix to `check-deps` (e.g., adding `ksshaskpass`) must be duplicated. `get-askpass` already `source "$(include "check-deps")"` so it could call `getAskPass`/`checkTerminal` from there.
  - **Fix:** Remove local `checkTerminal` and graphical if-chain, reuse `getAskPass` from `check-deps`: `path="$(getAskPass)"` directly, or at least `source` and call `checkTerminal`.

- **Generated `askpass` file overwritten via `command -v askpass` fallback without warning:**

  ```bash
  # get-askpass:78-81
  path="$(dirname "${BASH_SOURCE[0]}")/askpass"
  command -v askpass &>/dev/null && path="$(command -v askpass)"
  cat >"${path}" <<EOF
  ```

  - **Why:** If user has `/usr/local/bin/askpass` earlier in PATH, script overwrites it silently with current `cmd`. Also `dirname "${BASH_SOURCE[0]}"` may be `/tmp` or unwritable when invoked via PATH hook — `cat >` will fail with `No such file` under `set -e`.
  - **Fix:** Always write to `SCRIPTS_DIR/askpass` or `mktemp` and `printf '%s' "$path"`; or check `[[ -w "$path" ]] || log-error`.

- **Unquoted `cat <<EOF` with `${cmd}` interpolation — heredoc expands `$` inside `cmd`:** `cmd` contains `echo \$?` and `\$password` already escaped as `\$`, but future `cmd` containing backticks or `$(...)` would double-expand. Safer as `cat >"${path}" <<'EOFH'` + explicit variable, or `printf '%s\n' "${cmd}"`.

#### Minor / style

- **No args defined yet `cmdarg_parse "$@"` handles `--help` only:** Correct per house brief §5 (zero-flag script still supports `-h/--help` via `CMDARG_GETOPTLIST="h"`), but `get-askpass` could document `cmdarg` is unused and just `source "$(include "lib/helpers.sh")"` would suffice.

- **`chmod +x "${path}" &>/dev/null` swallows permission errors:** If `path` on read-only FS, failure hidden.

- **Empty deps block `x-none`:** `checkDeps "$0"` returns 0 immediately — correct per house brief §6, not flagged.

#### Confirmed correct (potential false positives)

- `set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `source "$(include "lib/cmdarg.sh")"` + `source "$(include "lib/helpers.sh")"` + `source "$(include "check-deps")"` + `checkDeps "$0"` order matches house reference (`clangc`) — not flagged.
- `cmdarg_info "header" "$(get-desc "$0")"` + `cmdarg_parse "$@"` with no flags — allowed (positionals-only), not a bug.
- Dependency alternations not present but empty block handling via `x-none` matches `getDeps` spec.
- Graphical detection order `zenity → kdialog → yad → whiptail → dialog → ssh-askpass` matches `check-deps:68` — not flagged as arbitrary.

---

### `no-dups`

**Path:** `/home/othman/scripts/no-dups`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Removes duplicate lines from a file or stdin, with options for backup, output as array, and quiet mode
**Declared dependencies:** `tr`, `awk`, `paste`
**Verdict:** `Needs fixes`

#### Critical bugs

None found — no silent data loss beyond design fragility below; failures log via `log-error`.

#### Design issues

- **`trap 'rm -f $tmpfile' EXIT` word-splits and deferred-expansion style masks missing quoting:**

  ```bash
  # no-dups:59-60
  tmpfile="$(mktemp)"
  trap 'rm -f $tmpfile' EXIT
  ```

  - **Why:** Single-quoted trap defers `$tmpfile` expansion until EXIT, when `rm -f $tmpfile` splits on spaces. `mktemp` on this host is safe (`/tmp/tmp.XXXXXX` no spaces) but pattern is fragile; also if script early-exits before `mktemp`, `rm -f ` removes ` `? Harmless but `shellcheck SC2064` flags it.
  - **Fix:**

  ```bash
  tmpfile="$(mktemp)"
  trap 'rm -f "${tmpfile}"' EXIT
  # or immediately after mktemp: trap "rm -f \"${tmpfile}\"" EXIT
  ```

- **`mv -i` can hang non-interactively when `force` false (default):**

  ```bash
  # no-dups:71-75
  if ${force}; then
    mv "${tmpfile}" "${file}"
  else
    mv -i "${tmpfile}" "${file}"
  fi
  ```

  - **Why:** `mv -i` prompts on overwrite and blocks in CI/headless/pipe; `set -eo pipefail` has no prompt handler. Pair script `get-unique` same pattern. Should gate on `isInteractiveShell` or require `-f` for overwrite, like `mkscript` does via `yesNo`.
  - **Fix:** `if ${force} || ! isInteractiveShell; then mv -f ...; else mv -i ...; fi` or use `mv -f` and document force flag as overwrite guard.

- **Array mode `tr ' ' '\n' | paste -sd " "` splits only on single spaces and loses quoting:**

  ```bash
  # no-dups:47
  tr ' ' '\n' | awk '!seen[$0]++' | paste -sd " "
  ```

  - **Why:** Input `echo 'a "b c" a' | no-dups -a` → `a` `"` `b` `c` `"` tokens, not lines; downstream `paste` rejoins with single space, not valid `declare -a` syntax (`('a' 'b c')`). Works for simple word lists but breaks quoted strings/tabs.
  - **Fix:** Document as word-list only or emit `printf '%q '` joined array: `awk '!seen[$0]++' | tr '\n' ' '` with `shellQuote`.

- **Stdin vs file branching conflates missing file with empty file:**

  ```bash
  # no-dups:53-57
  file=${argv[0]}
  if [[ -z ${file} || ${file} == "-" ]]; then
    remove_duplicates
  else
    # Read from file
    if [[ -f ${file} ]]; then
  ```

  - **Why:** `no-dups ""` (empty string positional) incorrectly goes to stdin path; also `[[ -f ${file} ]]` unquoted but inside `[[ ]]` safe, yet `${file}` with glob chars (`*`) would expand? Inside `[[ ]]` glob not expanded, but still style drift.

#### Minor / style

- **Unquoted `${file}` in `[[ -f ${file} ]]` and `cp "${file}" "${file}.bak"` is safe inside `[[ ]]` but inconsistent with repo's quoted style (`"${file}"` elsewhere). Keep quoted.**

- **`tr`/`paste` not declared as deps beyond header? Actually declared `tr`, `awk`, `paste` — correct, though `tr`/`paste` are coreutils-excluded per brief, not harmful.**

- **Duplicated `awk '!seen[$0]++'`** — could be single function with conditional pipe; cosmetic.

#### Confirmed correct (potential false positives)

- `set -eo pipefail` + `trap` + `source "$(include "lib/cmdarg.sh")"` + `checkDeps` + `cmdarg "b"`/`"f"`/`"a"`/`"q"` boolean flags defaulting to `false` and tested as `${useBackup}` as command — correct per `cmdarg.sh:86`.
- Declaration `# - tr` `# - awk` `# - paste` — `tr`/`awk`/`paste` are coreutils but declaring them does not break `checkDep` (passes if found), not flagged.
- `remove_duplicates <"${file}" >"${tmpfile}"` correctly uses input redirection rather than `cat`.

---

### `make-caddy`

**Path:** `/home/othman/scripts/make-caddy`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Creates a Caddy reverse proxy site for local development: writes a site config to /etc/caddy/sites, generates a local TLS certificate with mkcert, adds a /etc/hosts entry, and restarts Caddy to apply it.
**Declared dependencies:** `mkcert`, `caddy`
**Verdict:** `Needs fixes`

#### Critical bugs

- **Required arguments `source`/`target` not validated — empty values create broken site/certs:**

  ```bash
  # make-caddy:33-40
  cmdarg "s:" "source" "The local endpoint (e.g. localhost:3000)" ""
  cmdarg "t:" "target" "The target proxy url (e.g. local.dev)" ""
  # ...
  source="${cmdarg_cfg['source']}"
  target="${cmdarg_cfg['target']}"
  cat <<Caddyfile | sudo tee "/etc/caddy/sites/${target%.*}.caddy" >/dev/null
  ${target} {
    reverse_proxy ${source}
  ```

  - **What happens:** With `make-caddy` (no args) `cmdarg.sh:79` marks both as required (no default) and `cmdarg_parse` will error `Missing arguments : -s -t` via `log-error` → SIGUSR1 → exit 1. So direct invocation is safe. But `make-caddy -s localhost:3000` (missing `-t`) also fails. The residual bug is when values are whitespace or `/` — `${target%.*}` strips extension then `tee` writes to `/etc/caddy/sites/.caddy` (empty basename) or with `/` in target breaks path.
  - **Fix:** Add explicit empty check even though cmdarg will catch missing, and sanitize `target`: `[[ -n "${target}" && "${target}" != *"/"* ]] || log-error "Invalid target"` and `target="${target,,}"` lower-case.

#### Design issues

- **Unsanitized interpolation into sudo tee / Caddyfile + mkcert + hosts:**

  ```bash
  # make-caddy:40-53
  cat <<Caddyfile | sudo tee "/etc/caddy/sites/${target%.*}.caddy" >/dev/null
  ${target} {
    reverse_proxy ${source}
  # ...
  sudo mkcert "${target}" &>/dev/null
  sudo chmod 644 "${target}"*.pem
  hostLine="${source}        ${target}"
  echo "${hostLine}" | sudo tee -a /etc/hosts >/dev/null
  ```

  - **Why:** `target="foo; rm -rf /"` not expanded as shell (heredoc is not eval) but `mkcert "${target}"` quoted so safe; however `target="example.com bar"` with space creates `example.com bar {` invalid Caddyfile and `mkcert` with space creates two SANs unintended. No validation of `source` as `host:port` or `target` as valid hostname.
  - **Fix:** Validate `[[ "${target}" =~ ^[a-z0-9.-]+$ ]] || log-error`; validate source via `[[ "${source}" =~ ^(localhost|127\.0\.0\.1|0\.0\.0\.0)(:[0-9]+)?$ ]] || ...` or allow IP.

- **Glob `chmod 644 "${target}"*.pem` is quoted on prefix only — glob still expands but target with spaces splits:**

  - **Fix:** `sudo chmod 644 -- "${target}"*.pem` or `(cd /etc/caddy/certs && sudo chmod 644 -- "${target}"*.pem)`.

- **`grep -qF "${hostLine}" /etc/hosts` without `sudo` may fail to read if permissions restrict? `/etc/hosts` is 644 readable, fine. But duplicate detection uses exact `hostLine` which includes source IP; if source changes from `localhost:3000` to `127.0.0.1:3000` same target, duplicate not detected and hosts appended twice.**

#### Minor / style

- **Heredoc indented via `cat <<Caddyfile` not `<<-Caddyfile`:** Whitespace preserved; fine but `Caddyfile` terminator must be at column 0 (currently is).

- **Subshell `( cd /etc/caddy/certs; sudo mkcert ... ) && log-info`** — `&&` masks `set -e` failure: if `mkcert` fails, `log-info` not run but subshell exit 1 does not abort outer script due to `&&` list exception.

- **Dependency `caddy` declared but also uses `systemctl` (implicit) + `sudo`/`mkcert` — `systemctl` not declared; but systemd is ubiquitous.**

#### Confirmed correct (potential false positives)

- `cmdarg "s:"`/`"t:"` with `""` default correctly map to `CMDARG_REQUIRED` per `cmdarg.sh:79` (`":"` + empty default → required) — not flagged as optional-default bug.
- `source "$(include "lib/cmdarg.sh")"` + `source "$(include "lib/helpers.sh")"` + `source "$(include "check-deps")"` + `checkDeps "$0"` order matches `clangc` reference.
- `sudo systemctl restart caddy >/dev/null || log-error "Failed to restart caddy service"` correctly handles restart failure without `set -e` abort.
- `trap 'exit 1' SIGUSR1` propagation via `log-error` is intentional per house brief §4.

---

### `mdfmt`

**Path:** `/home/othman/scripts/mdfmt`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Formats Markdown files using Prettier; auto-discovers files with fd or formats given .md/.markdown files
**Declared dependencies:** `fd | fdfind (fd-find)`, `awk`, `prettier`
**Verdict:** `Critical bug`

#### Critical bugs

- **Missing `lib/helpers.sh` source — `isPositive` and `killwait` are undefined, script aborts on any invocation:**

  ```bash
  # mdfmt:25-34
  source "$(include "lib/cmdarg.sh")"
  source "$(include "check-deps")"
  checkDeps "$0"
  cmdarg_info "header" "$(get-desc "$0")"
  cmdarg "j?" "jobs" "How many threads to use in parallel?" "$(nproc)"
  cmdarg_parse "$@"
  jobs="${cmdarg_cfg['jobs']}"
  isPositive "${jobs}" || log-error "Number of threads must be positive"
  # ...
  killwait "${SPINNER_PID}"
  ```

  - **What happens:** `isPositive` is defined in `lib/helpers.sh:225`, not `lib/cmdarg.sh` nor `check-deps`. Call → `bash: isPositive: command not found` → `set -eo pipefail` → exit 127 before formatting. Similarly `killwait` is standalone script `/home/othman/scripts/killwait:20` (expects `killwait <pid>`), but with `set -e` and no `command -v` guard, if `killwait` not in PATH (hook not sourced non-interactive) → `command not found`.
  - **Why it's wrong:** `mdfmt` omitted `source "$(include "lib/helpers.sh")"` that `clangc` reference includes; all other formatters (`cpu-usage:25`, `make-caddy:27`) source helpers.
  - **Fix:**

  ```bash
  source "$(include "lib/helpers.sh")"
  source "$(include "lib/cmdarg.sh")"
  source "$(include "check-deps")"
  checkDeps "$0"
  ```

  Or change to `isPositiveInt`/`isPositiveFloat` after sourcing helpers.

- **`PRETTIERRC` may be unset — `prettier --config ""` errors:**

  ```bash
  # mdfmt:63-66
  prettier --write \
    --ignore-path '/dev/null' \
    --ignore-unknown='false' \
    --config "${PRETTIERRC}" "${files[@]}"
  ```

  - **What happens:** `PRETTIERRC` is not declared in this repo (no `export PRETTIERRC` in `init.sh`/`hooks/path.sh`). With `set -u` off, expands to `""` → `prettier --config ""` → `Error: Invalid config file ""`. Even without, empty config overrides `prettier` discovery.
  - **Fix:**

  ```bash
  if [[ -n "${PRETTIERRC:-}" && -f "${PRETTIERRC}" ]]; then
    prettier --write --config "${PRETTIERRC}" "${files[@]}"
  else
    prettier --write "${files[@]}"
  fi
  # or: prettier --write --ignore-path '/dev/null' "${files[@]}"
  ```

#### Design issues

- **Undeclared runtime dependencies `mdmath`, `mdclean`, `spinner.sh`/`killwait`, `nproc` not in deps block:**

  ```bash
  # mdfmt:55-61
  spinner.sh "Formatting ${filesCount} files..." 1>&2 &
  SPINNER_PID=$!
  mdmath -q -j "${jobs}" "${files[@]}" || log-warning "Failed to fix math in ${filesCount} files"
  mdclean -q -j "${jobs}" "${files[@]}" || log-warning "Failed to clean ${filesCount} files"
  ```

  - **Why:** Block declares `prettier`/`fd`/`awk` but not `mdmath`/`mdclean`/`spinner.sh`. `checkDeps` will not install them; on minimal host `mdmath: command not found` → masked by `|| log-warning` but `spinner.sh` failure is not masked (background).
  - **Fix:** Add `# - mdmath` `# - mdclean` `# - spinner.sh` `# - killwait` to header, or degrade gracefully: `command -v mdmath &>/dev/null && mdmath ... || true`.

- **`fd.sh` wrapper vs declared `fd | fdfind`:** Declares `fd | fdfind (fd-find)` but actually invokes `fd.sh` (`mdfmt:39,44`) which hardcodes `/usr/bin/fd` + excludes. If system has `fdfind` only, `fd.sh` fails despite `fdfind` being installed and `checkDep` passing. Should declare `fd.sh` or make `fd.sh` fallback to `fdfind`.

- **`spinner.sh` background job not waited correctly on early exit — orphan on `log-error`:** `spinner.sh ... &` then `SPINNER_PID=$!` then `killwait "${SPINNER_PID}"` — correct name for `killwait:27` (`killwait <pid>`). But if `filesCount==0` → `log-error` kills parent via SIGUSR1 before `killwait` — spinner orphaned. Add `trap 'killwait "${SPINNER_PID}" 2>/dev/null || true' EXIT`.

- **`jobs="$(nproc)"` default evaluated at `cmdarg` definition time, not parse time — stale if `nproc` fails:** If `nproc` not found (declared? not in deps), substitution yields empty → `jobs=""` → `isPositive ""` fails.

#### Minor / style

- **`mapfile -t files < <(fd.sh . -I -e md -e markdown .)` includes hidden `.git` excluded via `fd.sh` excludes, fine, but `fd.sh` already adds `--hidden` — `-I` (`--no-ignore`) is redundant with `fd.sh`'s own args? `fd.sh` passes `--hidden` then caller adds `-I` (alias for `--no-ignore`) duplicate.

- **`[[ "${arg##*.}" =~ ^(md|markdown)$ ]] && files+=("${arg}")` skips files without extension but with `*.md` hidden? Acceptable.**

#### Confirmed correct (potential false positives)

- `fd | fdfind (fd-find)` pipe fallback with package override — correct per house brief §2, not flagged.
- `set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `source "$(include "lib/cmdarg.sh")"` + `checkDeps "$0"` + `cmdarg "j?"` optional with `$(nproc)` default — `?` + default → optional per `cmdarg.sh:44`, correct.
- `((0 < filesCount)) || log-error "No valid markdown files were passed"` — correct `log-error` termination via SIGUSR1.
- `spinner.sh` + `killwait` pattern is repo-conventional (see `spin.sh`/`killwait`) — not flagged as arbitrary background handling.

---

### `cpu-usage`

**Path:** `/home/othman/scripts/cpu-usage`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Displays cpu usage percentage
**Declared dependencies:** `bc`, `grep`
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **`usage` may be unset when `total_diff==0` (identical successive `/proc/stat` reads or VM freeze):**

  ```bash
  # cpu-usage:54-58
  if ((total_diff)); then
    usage=$(bc -l <<<"scale=2; (1 - ${idle_diff} / ${total_diff}) * 100")
  fi
  echo "${usage}"
  ```

  - **Why:** If `total_diff==0` (e.g., `sleep 0.5` too short or `/proc/stat` not updating), `usage` never assigned → `echo ""` blank line instead of `0.00` or error. Caller parsing numeric output gets empty string.
  - **Fix:**

  ```bash
  if ((total_diff)); then
    usage=$(bc -l <<<"scale=2; (1 - ${idle_diff} / ${total_diff}) * 100")
  else
    usage="0.00"
  fi
  echo "${usage}"
  ```

- **Idle calculation ignores `iowait` — under-reports truly idle time:**

  ```bash
  # cpu-usage:41,43
  idle1=${cpu1[4]}
  idle2=${cpu2[4]}
  ```

  - **Why:** `cpu` line `cpu user nice system idle iowait irq softirq steal guest guest_nice`. Conventional `idle = idle + iowait` (fields 4+5 zero-indexed after `cpu`?). Some monitors use `idle + iowait`. Current 1-2% error on I/O-heavy hosts.
  - **Fix:** `idle1=$((cpu1[4] + cpu1[5]))` likewise `idle2`.

- **`grep '^cpu ' /proc/stat` assumes first line is aggregate — future kernels add `cpu` prefix with leading spaces? Already anchored `^cpu ` correct, but `read -ra cpu1` includes literal `cpu` at index 0 then `total1` sums from `1` correctly; no bug, just note.

#### Minor / style

- **`bc -l` may output many decimals (`scale=2` respected but division may yield trailing zeros trimmed). `printf "%.2f\n" "${usage}"` would normalize.**

- **`sleep 0.5` hard-coded sampling window — 0.5s adequate but not configurable; occasional scheduler jitter.**

- **No validation of `/proc/stat` existence — container without `/proc` would `grep` fail → `read` empty → `idle1=` empty → arithmetic error. Low risk on Linux.**

#### Confirmed correct (potential false positives)

- `set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `source "$(include "lib/cmdarg.sh")"` + `source "$(include "lib/helpers.sh")"` + `checkDeps "$0"` — correct per `clangc`.
- Dependencies `bc`/`grep` declared; `sleep`/`cat`/`read` coreutils-excluded per brief — not flagged.
- `read -ra cpu1 < <(grep '^cpu ' /proc/stat)` + `for v in "${cpu1[@]:1}"` skipping `cpu` token — correct aggregation, not flagged as off-by-one.
- `cmdarg_parse "$@"` with no flags (supports `-h/--help`) — allowed per house brief §5.

---

### `phpfmt`

**Path:** `/home/othman/scripts/phpfmt`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Formats PHP files using phpcbf; accepts files, directories, or reads from stdin
**Declared dependencies:** `phpcbf (php-codesniffer)`
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **Missing `set -eo pipefail` (only `trap 'exit 1' SIGUSR1` present) — diverges from house style:**

  ```bash
  # phpfmt:20-25 vs clangc:21
  trap 'exit 1' SIGUSR1
  source "$(include "lib/cmdarg.sh")"
  ```

  - **Why:** Every other script uses `set -eo pipefail` for early failure on pipeline errors; `phpfmt` omits it, so `nproc` failure or `phpcbf` pipeline errors would not abort. Not fatal but inconsistent and masks `bc`/`grep` style errors in other scripts.
  - **Fix:** Add `set -eo pipefail` above `trap`.

- **`phpcbf` exit code semantics masked vs passed through — success vs fixable errors ambiguous:**

  ```bash
  # phpfmt:54
  "${cmd[@]}"
  ```

  - **Why:** `phpcbf` exits 0 only if no fixable errors, 1 if fixable errors were fixed, 2 if unfixable. Script forwards that code; caller may treat 1 as failure even though formatting succeeded. `mdfmt` masks with `|| log-warning`; `phpfmt` should decide: `&& exit 0` or `|| true` after `phpcbf`.
  - **Fix:** `"${cmd[@]}" || { rc=$?; ((rc==1)) && exit 0; exit $rc; }` or document forwarding.

- **`--stdin-path=file.php -` assumes `phpcbf` reads args as `phpcbf --stdin-path=file.php -`:** Correct per `phpcs` docs, but `cmd` already contains `-n -p --parallel=...`; order `phpcbf -n -p --stdin-path=file.php -` works; fine, just non-obvious.

#### Minor / style

- **`cmd=(phpcbf -n -p --parallel=$(($(nproc) / 2 + 1)))` — if `nproc` missing, arithmetic fails with `nproc: command not found` substitution empty → `(( / 2 + 1))` syntax error.** `nproc` is coreutils, usually present.

- **`"${isQuiet}" && cmd+=(-q)` pattern relies on literal `true`/`false` command — correct per house brief §5, but with `set -e` would need `|| true`; currently safe because `set -e` absent. If `set -e` added, change to `if ${isQuiet}; then cmd+=(-q); fi`.**

- **No `argc` check for stdin case: `if ((argc == 0)); then if [[ ! -t 0 ]]; then`** — correctly handles `phpfmt < file.php` vs `phpfmt` interactive (adds `.`). Fallback to `.` when stdin is TTY may be unexpected for empty invocation in non-git dir.

#### Confirmed correct (potential false positives)

- `phpcbf (php-codesniffer)` package override — correct parse per house brief §2 (`checkDep` extracts `php-codesniffer` via `grep -oP '\(\K[^)]*'`).
- `source "$(include ...)"` indirection via `realpath -m` — intentional per house brief §1.
- `cmdarg "q"`/`"b"` booleans default `false` and tested as `"${isQuiet}" && cmd+=(-q)` — valid `true`/`false` command pattern.
- `trap 'exit 1' SIGUSR1` alone (without `set -e`) not flagged as suspicious per house brief §4 — `log-error` still signals.

---

### `pkg-files`

**Path:** `/home/othman/scripts/pkg-files`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Displays all files/directories owned by a given package.
**Declared dependencies:** none
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **No dependencies declared though `pacman` is distro-specific runtime requirement:**

  ```bash
  # pkg-files:15-18
  # --- DEPENDENCIES --- #
  #
  # --- END SIGNATURE --- #
  # ...
  pacman -Ql "${package}" | cut -d' ' -f2-
  ```

  - **Why:** On non-Arch (Ubuntu container, CI) `pacman: command not found` → `set -eo pipefail` aborts without `checkDeps` hint (`pacman` not listed). For Arch-only repo this is acceptable but `checkDep` would not auto-install; worth declaring `# - pacman` explicitly.
  - **Fix:** Add `# - pacman` to deps block.

- **`pacman -Ql` failure is silent (no files) vs error — caller cannot distinguish missing package from package with no files:**

  ```bash
  # pkg-files:39-48
  while read -r entry; do
    # ...
  done < <(pacman -Ql "${package}" | cut -d' ' -f2-)
  exit 0
  ```

  - **Why:** `pacman -Ql nonexistent` exits 1 with `error: package 'x' was not found` on stderr, but pipeline `| cut` succeeds, `while read` reads 0 lines, script `exit 0` with no output and no error. With `set -o pipefail`, `pacman | cut` returns 1 but process substitution `< <(...)` exit code is not propagated to `while` guard; `set -e` does not abort inside `< <()` list? So missing package appears as empty output.
  - **Fix:**

  ```bash
  if ! pacman -Ql "${package}" 2>/dev/null | cut -d' ' -f2- | while read -r entry; do ...; done; then
    log-error "Package '${package}' not found"
  fi
  # or: entries=$(pacman -Ql "${package}" 2>&1) || log-error "$entries"
  ```

- **Associative-array style keys unquoted in expansion — inconsistent but not fatal:**

  ```bash
  # pkg-files:34-35
  showAll="${cmdarg_cfg[all]}"
  showDirs="${cmdarg_cfg[directories]}"
  ```

  - **Why:** Should be `${cmdarg_cfg['all']}` / `${cmdarg_cfg['directories']}`. Without inner quotes, Bash treats `all` as literal string unless variable `all` exists — works but diverges from `clangc:40` `${cmdarg_cfg['compile']}` style. `shellcheck SC2190` would flag.
  - **Fix:** `showAll="${cmdarg_cfg['all']}"`.

#### Minor / style

- **`[[ -z ${package} ]] && log-error`** — unquoted `${package}` inside `[[ ]]` safe, but repo prefers `"${package}"`.

- **`cut -d' ' -f2-` assumes `pacman -Ql` output always `pkgname /path`** — true for current pacman, but path with consecutive spaces preserved via `-f2-`; fine.

- **`[[ -d "${entry}" ]]` per entry does `stat` per file — okay for small packages, but `pacman -Ql` may list 10k files; acceptable.**

#### Confirmed correct (potential false positives)

- `set -eo pipefail` + `trap` + `source "$(include "lib/cmdarg.sh")"` + `checkDeps "$0"` → `cmdarg "a"`/`"d"` booleans → `cmdarg_parse "$@"` → `((argc))` not required but `[[ -z ${package} ]]` + `log-error` is alternative positional check — not flagged as missing `argc` validation.
- `while read -r entry; do ...; done < <(pacman -Ql ... | cut ...)` correctly avoids subshell variable loss (no variables needed).
- Empty deps block → `getDeps` prints `x-none` and `checkDeps` returns 0 per house brief §6 — correct, not flagged.

---

### `clipcopy`

**Path:** `/home/othman/scripts/clipcopy`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Copies input text or arguments to the system clipboard using available clipboard tools.
**Declared dependencies:** `xclip | wl-copy (wl-clipboard) | copyq`, `ansifilter`
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **`wl-copy` invoked as `wl-copy "${str}"` instead of stdin pipe — argument mode may not be primary API:**

  ```bash
  # clipcopy:38-39
  elif [[ "${XDG_SESSION_TYPE}" == "wayland" ]] && command -v wl-copy &>/dev/null; then
    wl-copy "${str}"
  ```

  - **Why:** `wl-copy` typically reads from stdin (`printf %s "$str" | wl-copy`), though recent `wl-clipboard 2.x` does accept arguments as text to copy. Passing `"${str}"` as argument works but for multiline or leading `-` may be parsed as option. `printf '%s' "${str}" | wl-copy` is more robust and matches `xclip` branch `echo -n "${str}" | xclip`.
  - **Fix:** `printf '%s' "${str}" | wl-copy` or `wl-copy -- "${str}"`.

- **`echo -n "${str}" | xclip -selection clipboard` — `echo -n` interprets backslash escapes on some shells and adds newline handling edge:** `printf '%s' "${str}" | xclip -selection clipboard` is POSIX-safe and preserves trailing `-n` strings.

- **`XDG_SESSION_TYPE` gates clipboard tool selection — may fallback to `copyq` even when `xclip` available on XWayland:**

  - **Why:** On Wayland with XWayland, `XDG_SESSION_TYPE=wayland` but `xclip` still works for X apps; current prioritizes `wl-copy` then `copyq`, skipping `xclip` though `xclip` present. Could probe tools in order regardless of session type.
  - **Fix:** Try `wl-copy` first if Wayland, then `xclip`, then `copyq` without strict `XDG_SESSION_TYPE` guard, or probe all: `if command -v wl-copy &>/dev/null && [[ "$XDG_SESSION_TYPE" == wayland ]]; then ... elif command -v xclip ...`.

#### Minor / style

- **`str="$(input "${argv[@]}" | ansifilter)"` — `input` from `lib/helpers.sh:21` does `str="$*"` join with space; passing `"${argv[@]}"` as separate args joins with IFS space, correct, but `ansifilter` declared as dep — if `input` contains ANSI, `ansifilter` strips, fine.

- **Order of `source` — `clipcopy:24` sources `lib/helpers.sh` before `lib/cmdarg.sh` — reverse vs `clangc` reference (`cmdarg` then `helpers` then `check-deps`) but not harmful; both declare globals.**

- **`&>/dev/null` not used; clipboard errors suppressed? `copyq` errors hidden via `1>/dev/null` only, stderr visible.**

#### Confirmed correct (potential false positives)

- Dependency alternation `xclip | wl-copy (wl-clipboard) | copyq` with `(wl-clipboard)` override — correct per house brief §2, not flagged. `ansifilter` second line similarly correct.
- `set -eo pipefail` + `trap` + `source "$(include ...)"` + `checkDeps "$0"` + `cmdarg_parse` with no flags — allowed.
- `[[ -z "${str}" ]] && log-error` termination via SIGUSR1 — correct per house brief §4.

---

### `ocrcp`

**Path:** `/home/othman/scripts/ocrcp`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): OCR an image and copy the result to clipboard
**Declared dependencies:** `tesseract`
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **Bypasses `cmdarg` contract — reads raw `$1` instead of `argv[0]` after `cmdarg_parse`:**

  ```bash
  # ocrcp:27-31
  cmdarg_info "header" "$(get-desc "$0")"
  cmdarg_parse "$@"
  # ---  Main script logic --- #
  file="$1"
  [[ -f "${file}" ]] || log-error "file '${file}' was not found!"
  ```

  - **Why:** House brief §5 mandates `argv`/`argc` after `cmdarg_parse`. Inside `cmdarg_parse` the loop `shift`s a local copy of `$@`, not caller's `$1`. With single arg `ocrcp foo.png` it accidentally works (`$1 == argv[0]`), but with `ocrcp -- foo.png` or `ocrcp -h` (reserved), `$1` is `--`/`-h` while `argv[0]` is `foo.png`. Also `argc` not checked, so `ocrcp a b` silently uses `a` and ignores `b`.
  - **Fix:**

  ```bash
  file="${argv[0]}"
  ((argc == 1)) || log-error "Exactly one image file required"
  [[ -f "${file}" ]] || log-error "file '${file}' was not found!"
  ```

- **Undeclared runtime dependency `ocr`/`clipcopy` (repo-internal) plus `ansifilter` indirect:**

  ```bash
  # ocrcp:34-39
  text=$(ocr "${file}")
  echo "${text}" | clipcopy || log-error "Copy to clipboard failed."
  ```

  - **Why:** Declares `tesseract` but actually calls `ocr` wrapper (`ocr:42` → `tesseract "${image}" "${imgNameWithoutExt}"`) and `clipcopy`. `checkDeps` will not ensure `ocr`/`clipcopy` in PATH (though hook provides them, not `checkDeps`). Worth noting as `ocr`/`clipcopy` are internal scripts, not external packages — pattern seen repo-wide.

- **`ocr` wrapper's `trap 'rm -f $outputFile' EXIT` bug is inherited (see `ocr:48`):** `trap 'rm -f $outputFile' EXIT` single-quoted deferred but `outputFile` contains `mktemp -t ocr-XXXXX` with no spaces, low risk but same quoting fragility as `no-dups`.

- **No handling for image path with spaces in `ocr` dispatch:** `text=$(ocr "${file}")` quoted correctly, but `ocr` internally does `tesseract "${image}" "${outputFile}"` — correctly quoted, so safe.

#### Minor / style

- **`[[ -z "${text}" ]]` → `log-warning` not `log-error` — treats empty OCR as warning, correct for scan of blank image; but `log-warning` exits 0 and still `log-success` not reached, fine.**

- **`echo "${text}" | clipcopy` — `echo` adds newline; `printf '%s' "${text}" | clipcopy` would preserve exact OCR without trailing newline.**

- **`&>/dev/null` not used for `ocr` call — `ocr` itself suppresses `tesseract` output, fine.**

#### Confirmed correct (potential false positives)

- `set -eo pipefail` + `trap` + `source "$(include "lib/cmdarg.sh")"` + `checkDeps "$0"` + `cmdarg_info` + `cmdarg_parse` order — correct per `clangc` reference.
- `tesseract` declared alone without package override — correct; `ocr`/`clipcopy` are PATH-supplied via `hooks/path.sh`, not `checkDep` — per house brief §7 not flagged as missing deps.
- `trap 'exit 1' SIGUSR1` not flagged per house brief §4.

---

## Batch Summary

- **Scripts reviewed:** 10 / 10
- **Critical bugs:** `mdfmt` (missing `lib/helpers.sh` source → `isPositive`/`killwait` undefined, `PRETTIERRC` unset causes prettier config error), `lua/sec2time.lua` (error branches via `os.execute("log-error")` do not `os.exit`, zero/negative input yields empty output)
- **Design issues worth escalating:** `make-caddy` (no target/source sanitization, glob/chmod and hosts duplicate), `no-dups` (trap `rm -f $tmpfile` splits, `mv -i` hangs non-interactively, `tr` array mode), `ocrcp` (`$1` vs `argv[0]` bypasses cmdarg sentinel), `phpfmt` (missing `set -eo pipefail`), `pkg-files` (silent `pacman -Ql` missing-package empty output, unquoted `cmdarg_cfg[all]`), `clipcopy` (`wl-copy "${str}"` arg vs pipe, `XDG_SESSION_TYPE` gating)
- **Cross-cutting patterns observed in this batch** (same bug/pattern repeated across multiple scripts in this batch only; batch-level, not repo-wide):
  - **Positional contract bypass (`$1`/`$#`/`$*` after `cmdarg_parse`)** — `ocrcp:30` (`file="$1"`), partially `mdfmt` uses `argc` correctly but `phpfmt` OK, `no-dups` uses `argv[0]` correctly; isolated to `ocrcp` in this batch but echoes pattern seen in batches 20/22 — batch-local instance is `ocrcp`.
  - **`trap 'rm -f $var' EXIT` unquoted deferred expansion** — `no-dups:60` and inherited `ocr:48` (called by `ocrcp`) both use single-quoted `rm -f $var` without inner quotes; low risk with `mktemp` but fragile for spaces.
  - **Undeclared repo-internal runtime deps** — `mdfmt` omits `mdmath`/`mdclean`/`spinner.sh`/`killwait`, `ocrcp` omits `ocr`/`clipcopy`, `make-caddy` omits `systemctl`/`sudo` — 3/10 scripts rely on PATH hook without declaration; consistent with grab-bag mix.
  - **`isPositive`/`isPossiblyUnset` guard missing or helper not sourced** — `mdfmt` fails to source `helpers.sh` while `cpu-usage:34` and `mdfmt:34` both validate numeric args, but only `cpu-usage` sources helpers.
  - **Empty/unset variable fallback for critical config** — `mdfmt:66` (`PRETTIERRC` empty → `prettier --config ""`), `cpu-usage:58` (`usage` unset when `total_diff==0` → `echo ""`), `make-caddy:33` (`target`/`source` required but cmdarg default `""` masks if parse not checking) — 3 scripts emit empty strings instead of defaults/errors.
- **Open questions** (design intent unclear, needs the repo owner's input rather than a guess):
  - `lua/sec2time.lua`: Should `0` seconds output `0 seconds`/`0s` or error? Should negative seconds be rejected or formatted as `-5 seconds`? And should Lua use `log-error` at all vs pure `io.stderr`?
  - `mdfmt`: Is `PRETTIERRC` intended to be optional env var pointing to repo's `prettier` config, or should it default to `${SCRIPTS_DIR}/.prettierrc`? And should `mdmath`/`mdclean` be hard requirements (fail) or best-effort (`|| log-warning` already does best-effort — should they be declared)?
  - `make-caddy`: Should `source` accept non-localhost IPs/hostnames (currently case assumes `localhost* | 127.0.0.1 | 0.0.0.0*` else raw source) — is `example.com:4000` valid source or should it be restricted to local?
  - `no-dups`: Should `-a` array mode output valid Bash syntax (`declare -p`) or is space-joined word list sufficient? Determines `tr`/`paste` vs `printf '%q'` fix.
  - `ocrcp`: Should it support `ocrcp -- image.png` sentinel and multiple images, or strictly one positional? Affects `argc` validation.
  - `clipcopy`: Should `wl-copy` be invoked via pipe (`printf %s | wl-copy`) for multiline safety, and should session-type gate be removed to probe `xclip`/`wl-copy`/`copyq` in order regardless of `XDG_SESSION_TYPE`?
  - `pkg-files`: Should missing package be fatal (`log-error`) or silent empty (current)? Current `exit 0` with no output ambiguous for scripting.

---

## Evidence Appendix (selected raw excerpts)

```bash
# mdfmt critical: missing helpers, isPositive undefined
$ grep -n "source.*helpers\|isPositive\|killwait\|PRETTIERRC" /home/othman/scripts/mdfmt
25:source "$(include "lib/cmdarg.sh")"
34:isPositive "${jobs}" || log-error "Number of threads must be positive"
61:killwait "${SPINNER_PID}"
66:  --config "${PRETTIERRC}" "${files[@]}"
$ grep -n "isPositive" /home/othman/scripts/lib/helpers.sh
225:isPositive() { isPositiveFloat "$1"; }

# sec2time lua non-terminating error
$ sed -n '1,12p' /home/othman/scripts/lua/sec2time.lua
if arg[1] == nil then os.execute("log-error 'Seconds must be provided'") end
local isShort = arg[2] ~= nil and (arg[2] == '-s' or arg[2] == '--short')
...
if seconds == nil then os.execute("log-error 'seconds must be a number'") end
seconds = math.floor(seconds or 0)

# no-dups trap / mv -i
$ sed -n '59,76p' /home/othman/scripts/no-dups
tmpfile="$(mktemp)"
trap 'rm -f $tmpfile' EXIT
  remove_duplicates <"${file}" >"${tmpfile}"
  if ${force}; then
    mv "${tmpfile}" "${file}"
  else
    mv -i "${tmpfile}" "${file}"
  fi

# make-caddy unsanitized Caddyfile
$ sed -n '33,45p' /home/othman/scripts/make-caddy
cmdarg "s:" "source" "The local endpoint (e.g. localhost:3000)" ""
cmdarg "t:" "target" "The target proxy url (e.g. local.dev)" ""
cat <<Caddyfile | sudo tee "/etc/caddy/sites/${target%.*}.caddy" >/dev/null
${target} {
  import common
  reverse_proxy ${source}

# ocrcp $1 vs argv
$ sed -n '27,31p' /home/othman/scripts/ocrcp
cmdarg_info "header" "$(get-desc "$0")"
cmdarg_parse "$@"
file="$1"
[[ -f "${file}" ]] || log-error "file '${file}' was not found!"

# pkg-files silent missing package
$ sed -n '33,48p' /home/othman/scripts/pkg-files
package="${argv[0]}"
showAll="${cmdarg_cfg[all]}"
showDirs="${cmdarg_cfg[directories]}"
while read -r entry; do
done < <(pacman -Ql "${package}" | cut -d' ' -f2-)

# clipcopy wl-copy arg vs pipe
$ sed -n '32,44p' /home/othman/scripts/clipcopy
str="$(input "${argv[@]}" | ansifilter)"
if [[ "${XDG_SESSION_TYPE}" == "x11" ]] && command -v xclip &>/dev/null; then
  echo -n "${str}" | xclip -selection clipboard
elif [[ "${XDG_SESSION_TYPE}" == "wayland" ]] && command -v wl-copy &>/dev/null; then
  wl-copy "${str}"

# cpu-usage unset usage
$ sed -n '54,58p' /home/othman/scripts/cpu-usage
if ((total_diff)); then
  usage=$(bc -l <<<"scale=2; (1 - ${idle_diff} / ${total_diff}) * 100")
fi
echo "${usage}"
```
