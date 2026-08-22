# Batch Review: 03 of 22

**Scripts in this batch:** `android-specs`, `echopass`, `updateSpicetify`, `cpp/release.sh` (4 scripts)
**Batch composition:** large+fillers — large standalone `android-specs` (320 lines) plus 3 tiny fillers as incidental line-budget fillers (`echopass` 3 lines, `updateSpicetify` 5 lines, `cpp/release.sh` 7 lines) — pairing is incidental, not a shared pattern. Budget 335 lines, cap 4 (large >150).
**Reviewer:** subagent-03
**Date:** 2026-08-21

---

## House Style Reference (do not flag these as bugs)

Before reviewing, confirm you've internalized these repo conventions. Restate them here in one line each to prove the context loaded correctly:

- Dependency declaration format (`# - binary | binary2 (pkg-override)`) and how `checkDep` resolves it: deps live between `# --- DEPENDENCIES --- #` and `# --- END SIGNATURE --- #` as `# - exe | alt (pkg)`; `checkDep` splits on `|`, `Trim`s, takes first word per alternative and `command -v` checks each in order — any hit returns 0 satisfied, else echoes `(parens)` package or first exe for `installDep`.
- Logging convention: `log-*` wrapper scripts are primary, camelCase `log*` functions in `lib/helpers.sh` are fallback: standalone `log-debug/info/warning/error/success` plus dispatcher `log.sh` via `LEVEL_COLORS`/`LEVEL_OUTPUT`/`colorOnlyPrefix` are CLI entry points; `lib/helpers.sh` camelCase + `lib/loggers.sh` `printRed`/`hex_to_rgb` are in-process fallback, not dead code, and `log-success` vs `logSuccess` naming is both canonical.
- `trap 'exit 1' SIGUSR1` + `kill -SIGUSR1 "${PPID}"` propagation chain purpose: every script traps SIGUSR1 to `exit 1`; only `log-error` sends `kill -SIGUSR1 "${PPID}"` + `wait` (guarded by `! isInteractiveShell && ! noKill`, suppressed with `|| true`) to kill its parent up the chain without explicit exit-code checks.
- `cmdarg.sh` argument-parsing pattern used across scripts: `source "$(include "lib/cmdarg.sh")"` then `cmdarg_info "header" "$(get-desc "$0")"`; pre-declare `declare -a arr`/`declare -A hash` for `[]`/`{}` types; `cmdarg "v"` boolean defaults `"false"`/literal `true` (`if ${cfg['v']}; then`), `"m:"` required string, `"o?"` optional string, `"a?[]"`/`"H?{}"` array/hash; then `cmdarg_parse "$@"` and read `cmdarg_cfg`/`argv`/`argc`; `-h`/`--help` reserved.
- `get-desc` / `get-deps` signature-block parsing rules: both `sed`-parse `# --- DESCRIPTION --- #` … `# --- DEPENDENCIES --- #` … `# --- END SIGNATURE --- #`; missing block is allowed (`get-deps` prints `x-none`, `checkDeps` returns 0, `get-desc` tolerates either terminator); `get-deps` extraction via `sed -n '/DEPENDENCIES/,/END SIGNATURE/{/\# - /p}'` | `replace.sh`.
- `init.sh` / `hooks/path.sh` symlink and PATH-registration workflow: `init.sh` verifies `SCRIPTS_DIR` (`~/scripts`), ensures `fd` (prompts `fdfind->fd` symlink), checks `hooks/path.sh`, idempotently appends `[[ -s "${SCRIPTS_DIR}/hooks/path.sh" ]] && source ...` to `~/.bashrc`/`.zshrc`; `hooks/path.sh` (sourced at startup) caches `fd --strip-cwd-prefix=always --no-ignore-vcs -t x . --exclude .git/.venv/...` to `/tmp/path-hook.cache`, rescans only when `find -newer cache`, adds each executable's dir once via `:":${PATH}:"` guard, then unsets temps.
- Reference pattern from `clangc` (what "correct" looks like in this repo): `set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `source "$(include "lib/cmdarg.sh")"` + `source "$(include "lib/compile.sh")"` + `source "$(include "check-deps")"` + `checkDeps "$0"` in order; `cmdarg_info`/`declare -a compiler_args`/`cmdarg "c"`/`"o?"`/`"a?[]"`/`"q"`/`cmdarg_parse "$@"`; literal `cmdarg_cfg` reads, `((argc <1)) && log-error`, array-safe delegation via namerefs.

---

## Script Reviews

### `android-specs`

**Path:** `/home/othman/scripts/android-specs`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Prints out the specs of the connected android device using adb.
**Declared dependencies:** `adb (android-tools)`, `rg (ripgrep)`
**Verdict:** `Needs fixes`

#### Critical bugs

- **What happens:** `--short` filter regex matches almost none of the intended essential lines, and with `set -o pipefail` a non-matching `rg` exit 1 triggers `set -e` to kill the script.
- **Where:**

```bash
# android-specs:315
echo "${output}" | rg "^(Model|Android|API|RAM|Storage|Resolution):"
```

- **Why it's wrong:** The host output contains `API Level:`, `Total RAM:`, `Available RAM:`, `Internal Storage:`, `Available Storage:` — none start with `^API:`, `^RAM:`, `^Storage:` (they have prefixes/suffixes or spaces before `:`). So `--short` currently shows only `Model:`, `Android:`, `Resolution:` and silently drops RAM/Storage/API Level. Additionally `set -eo pipefail` is active (`android-specs:21`); `rg` returns 1 when zero lines match, making the pipeline exit 1 and `set -e` terminates the script instead of printing an empty filtered result.
- **Fix:**

```bash
# broader regex that matches intended essentials, and suppress rg's no-match exit 1
echo "${output}" | rg "^(Model|Android|API Level|.*RAM|.*Storage|Resolution):" || true
# or explicitly:
echo "${output}" | rg -E "^(Model:|Android:|API Level:|.*RAM:|.*Storage:|Resolution:)" || true
```

#### Design issues

- **What happens:** Device-side `Max Frequency`/`Min Frequency` produce empty values when `/sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_*_freq` is missing, unlike every other getter that falls back to `Unknown`.
- **Where:**

```bash
# android-specs:271-272 (inside cmd() heredoc)
echo Max Frequency: $(cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq | awk '{print $1/1000000" GHz"}')
echo Min Frequency: $(cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_min_freq | awk '{print $1/1000000" GHz"}')
```

- **Why it's wrong:** Many devices hide cpufreq (permission or kernel config); `cat` then feeds empty input to `awk`, printing `Max Frequency: ` with no value, inconsistent with `getProcessor`/`getRefreshRate`/`getBatteryStatus` which `printf '%s\n' 'Unknown'` on fallback. Fragile but not a crash (device side has no `set -e`).
- **Fix:**

```bash
freq="$(cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq 2>/dev/null | awk '{print $1/1000000" GHz"}')"
echo Max Frequency: ${freq:-Unknown}
# same for cpuinfo_min_freq
```

- **What happens:** Multiple `dumpsys battery | grep -m1 "level:"` etc. calls re-invoke `dumpsys` 6+ times; `getBatteryValue` already abstracts single `dumpsys battery | awk -F': *'` parsing, but Level/Health/Temperature/Voltage/Technology bypass it.
- **Where:**

```bash
# android-specs:293-297
echo Level: $(dumpsys battery | grep -m1 "level:" | cut -d: -f2)%$(dumpsys battery | grep -m1 "scale:" | cut -d: -f2 | awk '{print " / "$1}')
echo Health: $(dumpsys battery | grep -m1 "health:" | cut -d: -f2 | sed 's/ 1/Unknown/;s/ 2/Good/;s/ 3/Overheat/;s/ 4/Dead/;s/ 5/Over voltage/;s/ 6/Unspecifie
d failure/;s/ 7/Cold/' | tr -d ' ')
```

- **Why it's wrong:** Inefficient and duplicates parsing logic; inconsistent with `getBatteryStatus`'s single-call approach. Not a correctness bug, just fragile/distro-specific (`dumpsys` format varies).
- **Fix:** Reuse `getBatteryValue` for each key, or capture `dumpsys battery` once: `bat="$(dumpsys battery 2>/dev/null)"; echo "$bat" | awk ...`.

- **What happens:** No explicit check that an adb device is connected before `adb "${argv[@]}" shell "$(cmd)"`; if no device or `more than one device` error, `output` is empty and the script still prints empty (or `short` pipeline exits via pipefail) with no `log-error`.
- **Where:**

```bash
# android-specs:312
output="$(adb "${argv[@]}" shell "$(cmd)")"
```

- **Why it's wrong:** `adb` failure is silently captured; with `set -e` the failing command substitution in an assignment does NOT reliably trigger `set -e` (POSIX `set -e` ignores failures in assignments), so the script continues with empty output instead of a loud error. Other scripts validate `((argc <1)) && log-error` explicitly.
- **Fix:** Check adb exit status or pre-flight:

```bash
output="$(adb "${argv[@]}" shell "$(cmd)")" || log-error "adb failed — no device connected or multiple devices (use adb -s SERIAL)"
[[ -z "${output}" ]] && log-warning "empty output — device may be offline"
```

#### Minor / style

- Device-side `echo Model: $(getprop ro.product.model)` etc. (`android-specs:249-254,257-262,280-282`) use unquoted `$(getprop ...)` without outer quotes. `echo` will join word-split args with single spaces, so `Pixel 7` still prints `Model: Pixel 7`, but glob characters (`*`, `?`) could undergo filename expansion on the device shell. Prefer `echo "Model: $(getprop ro.product.model)"` for correctness; low severity (device shell is `mksh`/`toybox`, values rarely contain globs).
- `grep -m1 '^Hardware'` / `'^CPU implementer'` / `'^CPU part'` inside device script assume GNU `grep -m1`; Android toybox `grep` supports `-m` on modern devices but not guaranteed on older builds. Consider `grep | head -1` fallback for portability. Not critical.
- `IFS='` newline `'` literal newline swap in `getProcessor` (`android-specs:126-144`) is correct but relies on `for partCode in $partCodes` word-splitting on newline only; works because `partCodes` are hex codes without spaces, but document the assumption.
- `android-specs:263` fingerprint truncation `sed 's/.*\(........\)$/\1/'` discards all but last 8 chars; intentional obfuscation but undocumented.

#### Confirmed correct (potential false positives)

- `set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `source "$(include "lib/cmdarg.sh")"` + `source "$(include "lib/helpers.sh")"` + `source "$(include "check-deps")"` + `checkDeps "$0"` + `cmdarg_info "header" "$(get-desc "$0")"` + `cmdarg "s" "short"` + `cmdarg_parse "$@"` + `short="${cmdarg_cfg['short']}"` + `if "${short}"; then` matches `clangc` reference; boolean `if "${short}"` (quoted `true`/`false` literal) is canonical `cmdarg.sh` boolean handling, not a quoting bug.
- `# - adb (android-tools)` and `# - rg (ripgrep)` pipe-free single-exe with `(pkg-override)` is correct per `house-style-brief.md` §2; `checkDep` correctly extracts `adb`/`rg` and `android-tools`/`ripgrep` via `grep -oP '\(\K[^)]*(?=\))'` — not a syntax error.
- `cmd() { cat <<'EOF' ... EOF }` quoted heredoc prevents host-side expansion of device-side `$`, `` ` ``, and `$(...)`; `adb "${argv[@]}" shell "$(cmd)"` correctly forwards positional argv as adb device selector (e.g. `android-specs -s -- -s SERIAL`) via `"${argv[@]}"`.
- `source "$(include "...")"` indirection via `realpath -m` is intentional house-style path resolution, not fragile.

---

### `echopass`

**Path:** `/home/othman/scripts/echopass`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): none declared — file contains only `#!/usr/bin/env bash` + `echo "root"` (no signature block; `get-desc` would return empty, `get-deps` would return `x-none`)
**Declared dependencies:** none declared (no `DEPENDENCIES` block; `checkDeps` would return 0 via `x-none`)
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **What happens:** hardcoded credential `echo "root"` is used as a password provider (likely for `SUDO_ASKPASS` / `getAskPass` testing).
- **Where:**

```bash
# echopass:3
echo "root"
```

- **Why it's wrong:** Committing a hardcoded password, even for a test askpass helper, is insecure and will be picked up by secret scanning; `check-deps:68-118` `getAskPass` already creates a proper `zenity`/`kdialog`/`whiptail` askpass that prompts the user, not a static echo. If `echopass` is intentionally a test stub, it should be documented or gated behind a test flag.
- **Fix:** Either remove `echopass` and rely on `check-deps:106-118` `getAskPass` path that writes a real prompt to `askpass`, or guard with a comment and make it opt-in:

```bash
#!/usr/bin/env bash
# test helper only — do not use as SUDO_ASKPASS in production
echo "root"
```

Low severity if the repo owner intends this as a local test helper; escalate to confirm intent.

#### Minor / style

- No `set -eo pipefail` / `trap 'exit 1' SIGUSR1` / signature block, unlike `clangc` reference. This is acceptable for a 3-line `echo` shim — the shim delegates no error handling and `get-deps` correctly returns `x-none`, `checkDeps` would be a no-op. Adding a full header would add no signal, consistent with `batch-02`'s handling of 3-line `runpy` shims (verdict `Clean` despite missing header). Keep as-is or add minimal `set -eo pipefail` for consistency; not a bug.

#### Confirmed correct (potential false positives)

- Missing `# --- DESCRIPTION --- #` / `# --- DEPENDENCIES --- #` block is allowed per `house-style-brief.md` §6; `get-desc` tolerates either `DEPENDENCIES` or `END SIGNATURE` as terminator and `get-deps` prints `x-none` with `checkDeps` returning 0 — not missing deps.
- No `source "$(include ...)"` / `checkDeps` is correct for a trivial echo stub; it has no external deps to verify (unlike `android-specs` which needs `adb`/`rg`).

---

### `updateSpicetify`

**Path:** `/home/othman/scripts/updateSpicetify`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): none declared — file contains `spicetify update` + `spicetify restore backup apply` (no signature block)
**Declared dependencies:** none declared (no `DEPENDENCIES` block)
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **What happens:** second command runs even if `spicetify update` fails, because script lacks `set -eo pipefail`.
- **Where:**

```bash
# updateSpicetify:3-5
spicetify update

spicetify restore backup apply
```

- **Why it's wrong:** Diverges from `clangc` reference (`set -eo pipefail` + `trap`) and from repo convention that failures should abort; a failed update followed by `restore backup apply` can leave spicetify in a partially restored state with no error surfaced.
- **Fix:**

```bash
#!/usr/bin/env bash
set -eo pipefail
trap 'exit 1' SIGUSR1
spicetify update
spicetify restore backup apply
# or explicitly: spicetify update && spicetify restore backup apply
```

- **What happens:** `spicetify` binary not declared in a `DEPENDENCIES` block, so `checkDeps` would never prompt to install it.
- **Where:** missing block between `# --- DESCRIPTION --- #` and `# --- END SIGNATURE --- #`.
- **Why it's wrong:** Other scripts declare `adb`/`rg`/`fd | fdfind` so `checkDeps` can auto-install via `getPackageManager`; `updateSpicetify` silently assumes `spicetify` is on PATH.
- **Fix:**

```bash
# --- DEPENDENCIES --- #
# - spicetify
# --- END SIGNATURE --- #
```

Low severity; keep empty deps only if `spicetify` is considered a manual external install (document it).

#### Minor / style

- No `source "$(include "lib/cmdarg.sh")"` / `cmdarg_info` / `checkDeps` — acceptable for a 2-command sequential script with no flags, but then `get-desc` returns empty and wiki indexing (`create-wiki`) will skip it via `head -1` shebang filter. Add a minimal DESCRIPTION if wiki visibility is desired.

#### Confirmed correct (potential false positives)

- Two bare `spicetify` invocations without `source "$(include ...)"` is not a missing-include bug per `house-style-brief.md` §6 — missing DESCRIPTION/DEPENDENCIES is allowed and `get-deps` correctly yields `x-none`.
- No `log-*` usage to flag; script is intentionally a straight imperative sequence, not a `clangc`-style tool with flags.

---

### `cpp/release.sh`

**Path:** `/home/othman/scripts/cpp/release.sh`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): none declared — 7-line release helper (no signature block)
**Declared dependencies:** none declared (no `DEPENDENCIES` block; `checkDeps` would return `x-none`)
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **What happens:** `cppc --compile "$@"` failure does not abort the script; `mkdir` and `fd.sh ... mv` still run and can move stale `*.out` from a previous successful build, reporting false success.
- **Where:**

```bash
# cpp/release.sh:3
cppc --compile "$@"

mkdir "${SCRIPTS_DIR}/bin" &>/dev/null

fd.sh --no-ignore -e out --exec mv {} "${SCRIPTS_DIR}/bin/{/.}"
```

- **Why it's wrong:** Lacks `set -eo pipefail` + `trap 'exit 1' SIGUSR1` that `clangc` reference mandates; `cppc` itself uses `((argc <1)) && log-error` + `kill -SIGUSR1 "${PPID}"` to propagate errors, but without a trap the parent (`cpp/release.sh`) would terminate via default SIGUSR1 action rather than `exit 1`, and without `set -e` a non-SIGUSR1 failure (e.g. clang error) would be ignored.
- **Fix:**

```bash
#!/usr/bin/env bash
set -eo pipefail
trap 'exit 1' SIGUSR1
cppc --compile "$@"
mkdir -p "${SCRIPTS_DIR}/bin" &>/dev/null
fd.sh --no-ignore -e out --exec mv {} "${SCRIPTS_DIR}/bin/{/.}"
```

- **What happens:** `mkdir "${SCRIPTS_DIR}/bin"` without `-p` diverges from sibling `c/release.sh:5` which correctly uses `mkdir -p`; if `${SCRIPTS_DIR}/bin` already exists (normal case), `mkdir` exits 1 but `&>/dev/null` hides the error, and the script continues. Functional today but inconsistent and fragile.
- **Where:**

```bash
# cpp/release.sh:5 vs c/release.sh:5
mkdir "${SCRIPTS_DIR}/bin" &>/dev/null   # cpp — missing -p
mkdir -p "${SCRIPTS_DIR}/bin" &>/dev/null # c — correct
```

- **Why it's wrong:** Copy-paste drift; `mkdir` without `-p` fails on existing dir and would trigger `set -e` if the fix above is applied, breaking the script. Add `-p` for idempotency.
- **Fix:** `mkdir -p "${SCRIPTS_DIR}/bin" &>/dev/null`

- **What happens:** `${SCRIPTS_DIR}` is used unguarded; if unset or empty, `mkdir "${SCRIPTS_DIR}/bin"` becomes `mkdir "/bin"` (permission denied, suppressed) and `fd.sh ... "${SCRIPTS_DIR}/bin/{/.}"` becomes `mv ... "/bin/{/.}"`.
- **Where:** `cpp/release.sh:5,7` (and `c/release.sh:7` same).
- **Why it's wrong:** Fragile; `init.sh` and `hooks/path.sh` treat `SCRIPTS_DIR` as `~/scripts` default, but `cpp/release.sh` is invoked directly, not via the hook. Should default or check: `: "${SCRIPTS_DIR:=${HOME}/scripts}"` or guard with `[[ -d "${SCRIPTS_DIR}" ]] || log-error`.
- **Fix:** Add `: "${SCRIPTS_DIR:=${HOME}/scripts}"` after `set`/`trap`, or check existence before `mkdir`.

#### Minor / style

- No `# --- DESCRIPTION --- #` / `# --- DEPENDENCIES --- #` block, so `get-deps` yields `x-none` and `checkDeps` is a no-op. For a release helper that depends on `cppc` (repo script, not external package) and `fd.sh` (`fd | fdfind (fd-find)`), a DEPENDENCIES block would be documentation-only; omission is allowed per house-style-brief §6 but consider adding `# - fd | fdfind (fd-find)` for consistency.
- `&>/dev/null` suppression of `mkdir` hides real permission errors; with `mkdir -p` the suppression is mostly harmless, but keep or replace with `mkdir -p ... 2>/dev/null || true` for explicit `set -e` compatibility.
- `fd.sh --no-ignore -e out --exec mv {} "${SCRIPTS_DIR}/bin/{/.}"` placeholder `"{/.}"` inside double quotes is correctly handled by `fd --exec` (replacement occurs before shell word-splitting), but quoting is unnecessary; `fd.sh ... --exec mv {} ${SCRIPTS_DIR}/bin/{/.}` would also work. Not a bug.

#### Confirmed correct (potential false positives)

- `fd.sh` call is not a typo for `fd`; `fd.sh:1-43` is the repo's wrapper that invokes `/usr/bin/fd --hidden --exclude .git/node_modules/...` then appends `"$@"`, so `fd.sh --no-ignore -e out --exec mv ...` is the canonical way to find `*.out` in this repo (used identically in `c/release.sh:7`), not a missing-`fd` bug.
- `cppc --compile "$@"` with quoted `"$@"` correctly forwards all args; `cppc` itself follows the `clangc` reference pattern (`set -eo pipefail` + `trap` + `cmdarg` + `compile_and_run`), so the delegation is sound.
- Missing `source "$(include ...)"` / `checkDeps` is allowed for a 7-line shim; like `batch-02`'s 3-line `runpy` shims, adding a full `clangc` header to a trivial release mover would add no signal — flagged as Design, not Critical, and house-style-brief §7 confirms `hooks/path.sh` handles PATH, not per-script concern.

---

## Batch Summary

- **Scripts reviewed:** 4 / 4
- **Critical bugs:** `android-specs` — `--short` `rg "^(Model|Android|API|RAM|Storage|Resolution):"` matches only 3 of ~8 intended lines (drops `API Level:`, `Total RAM:`, `Available RAM:`, `Internal/Available Storage:`) and with `set -o pipefail` a zero-match `rg` exit 1 triggers `set -e` termination instead of empty filtered output.
- **Design issues worth escalating:** `android-specs` — (1) `Max/Min Frequency` empty fallback vs `Unknown` for other getters, (2) 6+ redundant `dumpsys battery | grep` calls bypassing `getBatteryValue`, (3) no adb device-connected check (empty output silently continues); `cpp/release.sh` — missing `set -eo pipefail`/`trap` lets failed `cppc` still move stale `*.out`, `mkdir` without `-p` drifts from `c/release.sh`, unguarded `${SCRIPTS_DIR}`; `updateSpicetify` — missing `set -e` lets `restore` run after failed `update`, undeclared `spicetify` dep; `echopass` — hardcoded `echo "root"` credential helper should be documented as test-only or replaced by `check-deps:getAskPass` prompt.
- **Cross-cutting patterns observed in this batch** (same bug/pattern repeated across multiple scripts in this batch only; batch-level, not repo-wide):
  - The three fillers (`echopass`, `updateSpicetify`, `cpp/release.sh`) are all sub-10-line scripts that intentionally omit `# --- DESCRIPTION --- #`/`# --- DEPENDENCIES --- #`/`set -eo pipefail`/`trap`/`cmdarg` — like `batch-02`'s `runpy` shims, the omission is intentional minimalism for trivial helpers, not a per-script oversight, but the batch shows inconsistent rigor within the same omission (e.g. `cpp/release.sh` needs `set -e` for correctness while `echopass` does not).
  - Both `c/release.sh` and `cpp/release.sh` share the identical `fd.sh --no-ignore -e out --exec mv {} "${SCRIPTS_DIR}/bin/{/.}"` move pattern; `cpp` drifts by omitting `mkdir -p` (`mkdir` vs `mkdir -p`), showing copy-paste divergence within an otherwise identical release helper family.
  - No batch-wide `checkDep` pipe/parens misuse — `android-specs`'s `adb (android-tools)` and `rg (ripgrep)` correctly use the single-exe `(pkg-override)` form per house-style-brief §2, and the fillers correctly yield `x-none`; there is no repeated `checkDep` anti-pattern to fix at batch level.
- **Open questions** (design intent unclear, needs the repo owner's input rather than a guess):
  - `android-specs --short` intended essentials: should the filter include `API Level`, `Total/Available RAM`, `Internal/Available Storage`, `ABI`, `Processor`, or is the current `Model|Android|API|RAM|Storage|Resolution` set intentional? The fix above assumes broader essentials — confirm the exact short-list.
  - `echopass` hardcoded `root`: is this a local test stub that should be kept (and documented as `test helper — do not use as SUDO_ASKPASS in prod`) or should it be deleted in favor of `check-deps:getAskPass`'s `zenity`/`kdialog`/`whiptail` prompt?
  - `cpp/release.sh` vs `c/release.sh`: should both gain `set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `: "${SCRIPTS_DIR:=${HOME}/scripts}"` + `mkdir -p`, or is the 7-line minimal form intentionally kept trap-free? Aligning them would be a one-line fix in `cpp`.
  - `updateSpicetify` dependency: is `spicetify` expected to be declared in `DEPENDENCIES` (`# - spicetify`) so `checkDeps` can auto-install, or is it intentionally left manual because it requires a custom install (e.g. `https://spicetify.app`)?
  - Device-side shell for `android-specs`: is `adb shell` guaranteed to be `bash`/`mksh` with `grep -m1`, `awk`, `getprop`, `dumpsys`, `wm` etc., or should the device script add `set -eu` and guard each `cat /sys/...` / `grep` with `2>/dev/null || echo Unknown` for older Android toybox builds?

---

## Evidence Appendix (optional)

- House style brief: `/home/othman/scripts/docs/code-reviews/house-style-brief.md:1-69`
- Core files read: `include:1-26`, `lib/cmdarg.sh:1-462`, `lib/loggers.sh:1-341`, `lib/helpers.sh:1-420`, `check-deps:1-175`, `log.sh:1-66`, `get-desc:1-53`, `get-deps:1-39`, `init.sh:1-158`, `hooks/path.sh:1-86`, `clangc:1-67`
- Batch scripts read: `android-specs:1-320`, `echopass:1-3`, `updateSpicetify:1-5`, `cpp/release.sh:1-7`
- Supporting reads: `c/release.sh:1-7`, `fd.sh:1-43`, `docs/templates/batch-review.md:1-85`, `docs/code-reviews/batch-01.md:1-385`, `docs/code-reviews/batch-02.md:1-212`
- Key verification: `rg "^(Model|Android|API|RAM|Storage|Resolution):"` tested against `Model:`, `Android:`, `API Level:`, `Total RAM:`, `Internal Storage:` — only 3 of 8 intended lines match; `mkdir "${SCRIPTS_DIR}/bin"` vs `mkdir -p` drift verified `cpp/release.sh:5` vs `c/release.sh:5` via `bash` `ls -la` and `cat`; `fd.sh` wrapper confirmed at `/home/othman/scripts/fd.sh:21` hardcodes `/usr/bin/fd` with `--hidden` + excludes.

