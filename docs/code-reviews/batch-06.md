# Batch Review: 06 of 22

**Scripts in this batch:** `piper-say`, `fix-arabic-fonts`, `include`, `print-args` (4 scripts)
**Batch composition:** large+fillers — `piper-say` (234) large + 3 small fillers (`fix-arabic-fonts` 26, `include` 26, `print-args` 29) pairing incidental, cap 4, budget 315. No shared pattern beyond line-budget packing.
**Reviewer:** subagent-06
**Date:** 2026-08-21

---

## House Style Reference (do not flag these as bugs)

Before reviewing, confirm you've internalized these repo conventions. Restate them here in one line each to prove the context loaded correctly:

- Dependency declaration format (`# - binary | binary2 (pkg-override)`) and how `checkDep` resolves it: deps between `DEPENDENCIES` and `END SIGNATURE` as `# - exe | alt (pkg)`; `checkDep` splits on `|`/`Trim`, `command -v` each alt in order — any found returns 0, else echoes `(pkg)` or bare exe for `installDep`.
- Logging convention: `log-*` wrapper scripts are primary, camelCase `log*` functions in `lib/helpers.sh` are fallback: standalone `log-debug`/`log-info`/`log-warning`/`log-error`/`log-success` + dispatcher `log.sh` (LEVEL_COLORS/LEVEL_OUTPUT → `colorOnlyPrefix`) are canonical; `lib/helpers.sh` `logDebug`/`logSuccess` etc. and `lib/loggers.sh` `printRed` etc. are in-process fallback, not dead code.
- `trap 'exit 1' SIGUSR1` + `kill -SIGUSR1 "${PPID}"` propagation chain purpose: every script traps SIGUSR1 to `exit 1`; only `log-error` sends `kill -SIGUSR1 "${PPID}"` guarded by `! isInteractiveShell && ! noKill` (`--no-kill`/`--no-error`/`--safe`) to propagate fatal error without explicit exit-code checks.
- `cmdarg.sh` argument-parsing pattern used across scripts: `source "$(include "lib/cmdarg.sh")"` → `cmdarg_info "header" "$(get-desc "$0")"` → pre-`declare -a arr`/`-A hash` for `[]`/`{}` → `cmdarg "v"` bool (`false`/`true` literal), `"m:"` required, `"o?"` optional, `"a?[]"`/`"H?{}"` arrays/hashes → `cmdarg_parse "$@"` → read `cmdarg_cfg`/`argv`/`argc`; `-h`/`--help` reserved.
- `get-desc` / `get-deps` signature-block parsing rules: both parse `# --- DESCRIPTION --- #` … `# --- DEPENDENCIES --- #` … `# --- END SIGNATURE --- #` via `sed`; missing DESCRIPTION or DEPENDENCIES is allowed (`x-none`/empty), `get-desc` stops on either terminator, `get-deps` does `sed '/\# - /p' | replace.sh '# - ' '' | grep -v " --- "`.
- `init.sh` / `hooks/path.sh` symlink and PATH-registration workflow: `init.sh` verifies `SCRIPTS_DIR` (`~/scripts`), ensures `fd` (prompts `fdfind→fd` symlink), checks `hooks/path.sh`, idempotently appends `[[ -s "${SCRIPTS_DIR}/hooks/path.sh" ]] && source …` to `~/.bashrc` (bash) or `${ZDOTDIR:-$HOME}/.zshrc` (zsh); `hooks/path.sh` (sourced at startup) caches `fd --strip-cwd-prefix=always --no-ignore-vcs -t x . --exclude …` to `/tmp/path-hook.cache`, rescans only when `find … -newer cache`, adds each exe dir once via `:...:` guard, then unsets temps.
- Reference pattern from `clangc` (what "correct" looks like in this repo): `set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `source "$(include "lib/cmdarg.sh")"` + `source "$(include "lib/compile.sh")"` + `source "$(include "check-deps")"` + `checkDeps "$0"` → `cmdarg_info`/`declare -a compiler_args`/`cmdarg "c"`/`"o?"`/`"a?[]"`/`"q"` → `cmdarg_parse "$@"` → literal `cmdarg_cfg` reads, `((argc<1)) && log-error`, arrays via namerefs to `compile_and_run`.

---

## Script Reviews

### `piper-say`

**Path:** `/home/othman/scripts/piper-say`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Text-to-speech script using Piper TTS and mpv; supports Pandoc input, Markdown/Word/PDF/HTML/URLs/raw text; can pipe live or save to WAV
**Declared dependencies:** `piper-tts (piper-tts-git) | piper-tts`, `aplay | mpv`, `b2sum (coreutils)`
**Verdict:** `Critical bug`

#### Critical bugs

- **What happens:** `checkCache` is called as a bare command (`piper-say:206: checkCache`) but returns `1` on every cache miss (`checkCache:103-152` multiple `return 1`). With `set -eo pipefail` (`piper-say:24`), a standalone non-zero return causes immediate exit — script never reaches `generateAudio`. It should have been `checkCache || true` or `if ! checkCache; then ...`.
- **Where:**

```bash
# piper-say:206
checkCache

# piper-say:103-105
checkCache() {
  if [[ ! -s "${cacheFile}" || ! -f "${cacheFile}" || $(wc -l <"${cacheFile}") -ne 2 ]]; then
    return 1
  fi
```

- **Why it's wrong:** violates `set -e` exception rules — only `if`/`while`/`until`/`&&`/`||`/`!` suppress `set -e`. A bare failing function is fatal. Every first run (no cache) would exit 1 instead of generating audio. Reproducible in isolation: `bash -c 'set -eo pipefail; f(){ return 1; }; f; echo after'` exits before `after`.
- **Fix:**

```bash
checkCache || true
# or:
if ! checkCache; then
  : # cache miss, continue to generate
fi
```

---

- **What happens:** `viewlines` arguments are reversed — script calls `viewlines 1 "${cacheFile}"` but `viewlines` signature is `viewlines <file> <line>` (`viewlines:38-40: file="${argv[0]}"; start="${argv[1]}"`). Both reads in `checkCache` hit `log-error "File 1 doesn't exist"` and return 1, so cache check always fails (and would never hit even if previous bug fixed).
- **Where:**

```bash
# piper-say:108-112
  if ! cachedState[text]="$(viewlines 1 "${cacheFile}" 2>/dev/null)" || [[ -z "${cachedState[text]}" ]]; then
    return 1
  fi
  if ! cachedState[audio_file]="$(viewlines 2 "${cacheFile}" 2>/dev/null)" || [[ -z "${cachedState[audio_file]}" ]]; then
    return 1
  fi
```

- **Why it's wrong:** `viewlines:26` documents `viewlines filename 15` → filename first. Reversed call treats `1` as filename, always errors. Verified: `viewlines "$tmp" 1` → `line1`; `viewlines 1 "$tmp"` → `[ERROR] File 1 doesn't exist`, exit 1.
- **Fix:**

```bash
  if ! cachedState[text]="$(viewlines "${cacheFile}" 1 2>/dev/null)" || [[ -z "${cachedState[text]}" ]]; then
  if ! cachedState[audio_file]="$(viewlines "${cacheFile}" 2 2>/dev/null)" || [[ -z "${cachedState[audio_file]}" ]]; then
```

---

- **What happens:** `select_player` (`piper-say:86-92`) leaves `playerCmd` empty if neither `aplay` nor `mpv` found. Later `"${playerCmd[@]}" "${out_file}"` (`piper-say:147,222,231`) expands with empty array to just `"${out_file}"`, executing the WAV path as a command (`file.wav: command not found`, exit 127, `set -e` kills script). Declared `aplay | mpv` should guarantee one, but if both fail install or user removes them, failure is silent vs loud.
- **Where:**

```bash
# piper-say:86-92
select_player() {
  if command -v aplay &>/dev/null; then
    playerCmd=(aplay --quiet)
  elif command -v mpv &>/dev/null; then
    playerCmd=(mpv --no-terminal)
  fi
}
```

- **Why it's wrong:** no `else` → undefined array; call site doesn't guard `(( ${#playerCmd[@]} ))`.
- **Fix:**

```bash
select_player() {
  if command -v aplay &>/dev/null; then
    playerCmd=(aplay --quiet)
  elif command -v mpv &>/dev/null; then
    playerCmd=(mpv --no-terminal)
  else
    log-error "No audio player found (need aplay or mpv)"
  fi
}
```

#### Design issues

- **What happens:** `list_voices` (`piper-say:66-70`) uses `fd` but `fd | fdfind (fd-find)` not declared in DEPENDENCIES; `gum` (used in `confirmAction:83`, `gum confirm`, `gum choose:178`, `gum write:198`) also undeclared. `checkDeps` therefore never prompts to install them; script fails later with obscure `command not found`.
- **Where:**

```bash
# piper-say:19-22 # DEPENDENCIES
# - piper-tts (piper-tts-git) | piper-tts
# - aplay | mpv
# - b2sum (coreutils)
# missing: fd, gum, pandoc (via prepare-tts-text), etc.
# piper-say:67: fd '\.onnx$' "${PIPER_VOICES_DIR}"
# piper-say:83: gum confirm "${prompt}"
```

- **Why it's wrong:** `checkDep` per brief §2 only handles declared alts; undeclared externals bypass install prompt. `prepare-tts-text` itself needs `pandoc` but that dep lives in `prepare-tts-text:18`, not here — transitive deps not auto-checked.
- **Fix:** add to header:

```bash
# - fd | fdfind (fd-find)
# - gum
# (and consider: pandoc via prepare-tts-text transitive, or declare explicitly)
```

- **What happens:** `checkCache` line `[[ ! -s "${cacheFile}" || ! -f "${cacheFile}" || $(wc -l <"${cacheFile}") -ne 2 ]]` (`piper-say:103`) does `$(wc -l <"${cacheFile}")` unquoted and with leading spaces from `wc` (GNU pads). Inside `[[ ]]`, numeric compare with spaced string is fragile; also command substitution runs even when `! -s`/`! -f` already true, and if file missing, `wc` errors (suppressed only by `2>/dev/null` in caller, not here). More robust to trim or use `awk`.
- **Where:**

```bash
# piper-say:103
  if [[ ! -s "${cacheFile}" || ! -f "${cacheFile}" || $(wc -l <"${cacheFile}") -ne 2 ]]; then
```

- **Why it's wrong:** `wc -l` may output `" 2"`; `[[ " 2" -ne 2 ]]` works in bash but is sloppy; missing file case runs `wc` on nonexistent fd, error under `set -e` is suppressed only if inside `[[ ]]`? fragile.
- **Fix:**

```bash
  if [[ ! -s "${cacheFile}" || ! -f "${cacheFile}" ]] || [[ $(wc -l <"${cacheFile}" | tr -d ' ') -ne 2 ]]; then
  # or: lines=$(awk 'END{print NR}' "${cacheFile}" 2>/dev/null); [[ "${lines}" -ne 2 ]]
```

- **What happens:** `[[ -z "$(trim "${text}")" ]]` (`piper-say:201`) uses external `trim` script (expects file or stdin) with `"$text"` as positional filename. If text contains spaces/newlines and happens to be an existing file path, `trim` misclassifies; also `trim:44: [[ -f ${file} ]]` unquoted in `trim` itself is a latent bug. Should use `Trim` function (helpers) or stdin: `printf '%s' "${text}" | trim` or `Trim "${text}"`.
- **Where:**

```bash
# piper-say:201
[[ -z "$(trim "${text}")" ]] && terminate "Nothing to do!"
```

- **Why it's wrong:** diverges from `Trim` helper (capital T, line `lib/helpers.sh:210`, no fork, space-trim via `sed`). Using file-oriented `trim` script for in-memory string is fragile.
- **Fix:**

```bash
[[ -z "$(Trim "${text}")" ]] && terminate "Nothing to do!"
# or: [[ -z "$(printf '%s' "${text}" | trim)" ]]
```

- **What happens:** spinner trap `trap 'killwait $SPINNER_PID' EXIT` (`piper-say:214`) uses single-quoted `$SPINNER_PID` (correct for deferred expansion) but overwrites EXIT trap idempotently; also `killwait` + `sleep 0.25 && exit 0` (`killwait:27`) forces exit 0 inside trap, which may mask earlier non-zero exit. Less critical since SIGUSR1 trap remains distinct.
- **Where:**

```bash
# piper-say:212-214
spinner.sh "Generating..." &
SPINNER_PID=$!
trap 'killwait $SPINNER_PID' EXIT
```

- **Why it's wrong:** not a bug per se, but `trap` for EXIT overrides any prior EXIT trap (none here, so fine per brief §4). Document intention.
- **Fix:** consider `trap 'killwait "${SPINNER_PID:-}" 2>/dev/null || true' EXIT` to handle empty PID case; keep SIGUSR1 trap untouched.

#### Minor / style

- `hashedText="$(printf '%s:%s' "${model}" "${text}" | b2sum)"` (`piper-say:203`) relies on `b2sum` coreutils; output includes ` -` for stdin, stripped via `${hashedText%% *}` (`piper-say:204`) — correct but could use `b2sum -- | awk '{print $1}'` for clarity.
- `generateCache` (`piper-say:94-100`) writes `mkdir -p … &>/dev/null` and heredoc without quoting — hides mkdir errors; fine with `set -e` but `&>/dev/null` suppresses useful diagnostics. Keep or drop redirection.
- `log-warning` vs `logWarning`: script uses dash forms `log-warning` (`piper-say:184`) and `log-info` (`piper-say:55`) via wrappers, while helpers provide camelCase fallback — both canonical per brief §3, not a mismatch, but mixing within one file is inconsistent.
- `confirmAction "[WARNING] … exists, do you want to overwrite?" || terminate` (`piper-say:209`) uses `terminate` (helpers `logInfo + exit 0`) for user abort — exit 0 on abort may be intentional but hides cancellation vs success; consider exit 1 or `log-warning` + `exit 0`.
- `cleanup_old_cache` (`piper-say:60-64`) called unconditionally on every run (`piper-say:191`); `find … -mtime +7 -delete 2>/dev/null || true` is correct `|| true` guard for `set -e`.

#### Confirmed correct (potential false positives)

- `set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `source "$(include "lib/cmdarg.sh")"` + `source "$(include "lib/helpers.sh")"` + `source "$(include "check-deps")"` + `checkDeps "$0"` order matches `clangc` reference (`clangc:21-27`) and brief §8 — not boilerplate to remove.
- `cmdarg "v?" "voice" ""`, `"o?" "output" ""`, `"l"`/`"y"`/`"c"` boolean flags correctly use `?` optional + `""` default and literal `true`/`false` (`cmdarg.sh:86-87`); checked via `${cmdarg_cfg['voice']}` etc. and `if "${list}"; then` / `"${acceptAll}" && return 0` are correct boolean-as-command idiom per brief §5.
- `# - piper-tts (piper-tts-git) | piper-tts` and `# - aplay | mpv` pipe + parens syntax is correct `checkDep` (§2) — `awk -F "|"`, `Trim`, `command -v` per alternative, pkg override via `grep -oP '\(\K[^)]*(?=\))'`; not a syntax error.
- `source "$(include "lib/helpers.sh")"` indirection via `realpath -m` (`include:24`) is intentional path resolution per brief §1, not fragile.
- `log-error` kill chain (`log-error:60, trap SIGUSR1`) is not required in every script — only `log-error` sends `kill -SIGUSR1 "${PPID}"`; other scripts correctly only trap (§4).
- Empty handling for `out_file` (`if [[ -n "${out_file}" ]]`) correctly guards file-overwrite checks when `-o` not passed; `[[ -f "${out_file}" ]]` with empty string safely returns false.

---

### `fix-arabic-fonts`

**Path:** `/home/othman/scripts/fix-arabic-fonts`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Fixes the arabic fonts configuration
**Declared dependencies:** none (empty block)
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **What happens:** `sudo cp -f "${HOME}/.config/fontconfig/65-nonlatin.conf" "/etc/fonts/conf.d/65-nonlatin.conf"` (`fix-arabic-fonts:26`) overwrites system file without verifying source exists or backing up destination; if source missing, `cp` fails, `set -e` exits 1 with no friendly `log-error` message, and sudo may prompt for password non-interactively.
- **Where:**

```bash
# fix-arabic-fonts:26
sudo cp -f "${HOME}/.config/fontconfig/65-nonlatin.conf" "/etc/fonts/conf.d/65-nonlatin.conf"
```

- **Why it's wrong:** diverges from repo habit of guarding file ops (`load-fonts`, `clangc` validate `[[ -s … ]]`, `[[ -r … ]]`); silent `set -e` exit hides cause.
- **Fix:**

```bash
src="${HOME}/.config/fontconfig/65-nonlatin.conf"
dst="/etc/fonts/conf.d/65-nonlatin.conf"
[[ -s "${src}" ]] || log-error "Source not found: ${src}"
sudo cp -f "${src}" "${dst}" || log-error "Failed to copy to ${dst} (need sudo?)"
log-success "Arabic fonts config installed to ${dst}"
```

- **What happens:** script sources only `lib/cmdarg.sh` (`fix-arabic-fonts:22`) and does `cmdarg_parse "$@"` with zero declared flags (only `-h`/`--help` works). It skips `source "$(include "lib/helpers.sh")"` and `source "$(include "check-deps")"` + `checkDeps "$0"` that `clangc` reference includes. Since deps are `x-none`, `checkDeps` would be no-op, but omission diverges from invariant.
- **Where:**

```bash
# fix-arabic-fonts:22-24
source "$(include "lib/cmdarg.sh")"
cmdarg_info "header" "$(get-desc "$0")"
cmdarg_parse "$@"
```

- **Why it's wrong:** not a runtime bug, but breaks repo convention that every script (even with no deps) explicitly sources helpers and runs `checkDeps` for consistency and future dep additions.
- **Fix:** add, matching `clangc:24-27`:

```bash
source "$(include "lib/helpers.sh")"
source "$(include "check-deps")"
checkDeps "$0"
```

#### Minor / style

- Single hardcoded `cp` line could be extended with `install -Dm644` for correct perms, or `fc-cache -f` trigger after copy (common for font fixes) — out of scope unless intended.
- No `getDeps` block means `x-none` via `helpers.sh:getDeps:83` — correct per brief §6, but explicitly listing `# - sudo` or documenting why source path is user-local would clarify.

#### Confirmed correct (potential false positives)

- `set -eo pipefail` + `trap 'exit 1' SIGUSR1` present (`fix-arabic-fonts:19-20`) — matches brief §4 even though `log-error` kill path not used here; trap alone is not suspicious.
- Empty `DEPENDENCIES` block (`fix-arabic-fonts:15-17`) is allowed per brief §6 (`getDeps` prints `x-none`, `checkDeps` returns 0) — not missing deps.
- `source "$(include "lib/cmdarg.sh")"` + `cmdarg_info` + `cmdarg_parse "$@"` with no declared options is valid — `cmdarg.sh` handles zero flags (only `-h` reserved) per brief §5; not an incomplete parser.
- `include` indirection (`$(include "lib/cmdarg.sh")` → `realpath -m`) is intentional per brief §1, not fragile.
- No `get-desc` failure: `get-desc` terminates on `DEPENDENCIES` or `END SIGNATURE` (`get-desc:43-50`), so missing `DEPENDENCIES` heading would still parse — no bug here since block exists.

---

### `include`

**Path:** `/home/othman/scripts/include`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Utility script to include other bash files safely, path is relative to SCRIPTS_DIR
**Declared dependencies:** none (no `# --- DEPENDENCIES --- #` section; `get-deps` yields `x-none`)
**Verdict:** `Clean`

#### Critical bugs

None found.

#### Design issues

None found.

#### Minor / style

- No `set -eo pipefail` / `trap` / `checkDeps` — intentional: this is the path-resolver itself, not a consumer script; adding `set -e` would break `source "$(include …)"` callers that test existence. Current minimal shape (26 lines) is correct.
- Uses `realpath -m` (`include:24`) which tolerates non-existing components (`-m`); appropriate for `SCRIPTS_DIR` fallback per brief §1. Requires `realpath` (coreutils) — not declared, but coreutils is per `AGENTS.md` implicit (not a declared dep).
- `SCRIPTS_DIR="${HOME}/scripts"` hard fallback plus `[[ ! -d "${scripts_dir}" ]] && scripts_dir="$(dirname -- "${BASH_SOURCE[0]}")"` handles `HOME` missing or repo moved — correct per brief §1.

#### Confirmed correct (potential false positives)

- `SCRIPTS_DIR="${HOME}/scripts"`; fallback `scripts_dir="$(dirname -- "${BASH_SOURCE[0]}")"`; `script_dir="$(cd -- "${scripts_dir}" && pwd)"`; `file="$(realpath -m "${script_dir}/$1")"`; `[[ -f "${file}" ]] && echo "${file}"` exactly matches house-style-brief §1 — never flag `realpath -m` or `include` indirection as fragile.
- `source "$(include "lib/helpers.sh")"` usage in other scripts that calls this file is canonical per brief §1 — this file's existence proves pattern.
- Missing `DEPENDENCIES`/`DESCRIPTION` terminator handling per brief §6 is allowed — `get-deps`/`get-desc` tolerate absent block, so no deps header here is fine.
- `BASH_SOURCE[0]` vs `$0` correctly resolves when sourced vs executed.

---

### `print-args`

**Path:** `/home/othman/scripts/print-args`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Spits out all of its arguments
**Declared dependencies:** none (no `# --- DEPENDENCIES --- #` section; `x-none`)
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **What happens:** script bypasses `cmdarg.sh` entirely and does manual `if [[ $1 != '-q' ]]; then log-debug … else shift; fi` (`print-args:23-27`). This works but diverges from repo `cmdarg` contract (brief §5) for `-q`/`--help` handling; `--help` not supported, `-q` only as first arg, not `--quiet` long form, not composable.
- **Where:**

```bash
# print-args:21-27
source "$(include "lib/helpers.sh")"
# ---  Main script logic --- #
if [[ $1 != '-q' ]]; then
  log-debug "$# args"
else
  shift
fi

(($#)) && printf '[%s]\n' "$@"
```

- **Why it's wrong:** not a crash, but inconsistent with `clangc` reference pattern (`cmdarg "q" "quiet"`) and makes `-h`/`--help` inert. Acceptable for a 29-line debug helper, but worth documenting as intentional `cmdarg` skip.
- **Fix:** either keep minimal (document `cmdarg` intentionally skipped for brevity) or adopt:

```bash
source "$(include "lib/cmdarg.sh")"
source "$(include "check-deps")"
checkDeps "$0"
cmdarg_info "header" "$(get-desc "$0")"
cmdarg "q" "quiet" "Suppress debug line"
cmdarg_parse "$@"
${cmdarg_cfg['quiet']} || log-debug "${argc} args"
((argc)) && printf '[%s]\n' "${argv[@]}"
```

#### Minor / style

- `if [[ $1 != '-q' ]]` leaves `$1` unquoted (`print-args:23`); inside `[[ ]]` word-splitting is suppressed so `[[ $1 != '-q' ]]` with empty `$1` evaluates to `[[ "" != '-q' ]]` (true) without syntax error — not a runtime bug, but `[[ "$1" != '-q' ]]` or `[[ "${1:-}" != '-q' ]]` is shellcheck-clean. Similarly `log-debug "$# args"` is `"$# args"` → `"3 args"` correctly, but `log-debug "${#} args"` vs `"$# args"` is subtle; works as intended.
- `(($#)) && printf '[%s]\n' "$@"` relies on `(( $# ))`/`&&` `set -e` exception — correct per brief §4 (failure in `&&` list doesn't exit). Explicit `if (( $# )); then printf …; fi` is clearer but current is fine.
- Sources only `lib/helpers.sh` (`print-args:21`), not `lib/cmdarg.sh`/`check-deps` — ok since zero deps (`x-none`), but diverges from `clangc` triple-source. Harmless for this size.

#### Confirmed correct (potential false positives)

- `set -eo pipefail` + `trap 'exit 1' SIGUSR1` present (`print-args:18-19`) matches brief §4; trap alone without `kill` is intentional (only `log-error` sends SIGUSR1).
- `source "$(include "lib/helpers.sh")"` indirection via `realpath -m` is canonical per brief §1 — not flagged.
- No `DEPENDENCIES` block → `getDeps` returns `x-none` per `helpers.sh:83` — allowed per brief §6, not a missing header bug.
- `log-debug "$# args"` dispatching to `log-debug` → `log.sh "DEBUG"` (`log.sh:29`) is primary logging interface per brief §3, not a duplicate of `logDebug` function; both exist intentionally.
- `printf '[%s]\n' "$@"` correctly preserves each arg with `"$@"` and prints one per line; `(( $# ))` guard avoids empty `printf` call.

---

## Batch Summary

- **Scripts reviewed:** 4 / 4
- **Critical bugs:** `piper-say` — `checkCache` bare call + `set -e` causes exit on every cache miss (`:206`); `viewlines` args reversed (`:108,112` → always `File 1 doesn't exist`); `select_player` leaves `playerCmd` empty leading to `file.wav: command not found` (`:86-92` + `:147,222,231`)
- **Design issues worth escalating:** `piper-say` — missing `fd`/`gum` (and transitive `pandoc`) from DEPENDENCIES (`:19-22`), fragile `wc -l` + `[[ … || $(wc…) -ne 2 ]]` (`:103`), `trim` vs `Trim` misuse for string (`:201`); `fix-arabic-fonts` — no source existence/sudo failure guard (`:26`) and missing `helpers`/`check-deps` sourcing vs `clangc` reference; `print-args` — manual `-q` handling bypasses `cmdarg.sh` contract
- **Cross-cutting patterns observed in this batch** (same bug/pattern repeated across multiple scripts in this batch only; batch-level, not repo-wide):
  - `set -e` + bare failing function call without `|| true`/`if` guard: only `piper-say:206` hits it, but `fix-arabic-fonts:26` (`sudo cp` failure under `set -e` with no `|| log-error`) and `print-args:29` (`(( $# )) && …` correctly guarded) show inconsistent `set -e` handling in this batch — `piper-say` missing guard is the outlier.
  - Dependency declaration granularity drift: `piper-say` omits `fd`/`gum` while `fix-arabic-fonts`/`include`/`print-args` correctly have `x-none` (no external deps) — shows batch-internal inconsistency on when to list indirect deps (`prepare-tts-text`/viewlines vs direct).
  - `cmdarg` adoption is uneven: `piper-say` follows `clangc` reference fully, `fix-arabic-fonts` declares zero flags but keeps `cmdarg_parse`, `print-args` skips `cmdarg` entirely for a trivial flag, `include` (26 lines) intentionally has no `cmdarg`/`set -e` as it's the resolver — justifies per-script sizing.
  - Wrapper vs function logging mix: `piper-say` mixes dash wrappers (`log-info`, `log-warning`, `log-success` with `log.sh`) and one `terminate` (helpers `logInfo`); `print-args` uses `log-debug` wrapper; `fix-arabic-fonts` uses none. All correct per brief §3 dual-layer, but batch shows no single style enforced.
- **Open questions** (design intent unclear, needs the repo owner's input rather than a guess):
  - `piper-say` — should cache be keyed only on `b2sum(model+text)` (`:203-204`) or also on voice version / `piper-tts` version? If model updates, old WAV would be considered hit.
  - `piper-say` — is `gum` intended as hard dep (install via `checkDeps`) or graceful fallback (e.g., plain `read -p` when `gum` missing)? Current code assumes `gum` always available (`gum confirm`/`gum choose`/`gum write`) with no fallback.
  - `fix-arabic-fonts` — should it backup `/etc/fonts/conf.d/65-nonlatin.conf` before `cp -f` and run `fc-cache -f` after, matching `load-fonts` pattern? Or is raw `cp` intentional minimal fix?
  - `print-args` — is `-q` meant to be quiet flag only as first arg, or should it support `cmdarg`-style `print-args --quiet -- args` with `--` sentinel and `argv`? Current manual parse is first-arg-only.

---

## Evidence Appendix (optional)

- House style brief: `/home/othman/scripts/docs/code-reviews/house-style-brief.md:1-69`
- Core files read: `include:1-26`, `lib/cmdarg.sh:1-462`, `lib/loggers.sh:1-341`, `lib/helpers.sh:1-420`, `check-deps:1-175`, `log.sh:1-66`, `get-desc:1-53`, `get-deps:1-39`, `init.sh:1-158`, `hooks/path.sh:1-86`, `clangc:1-67`
- Batch scripts read: `piper-say:1-234`, `fix-arabic-fonts:1-26`, `include:1-26`, `print-args:1-29`
- Supporting reads: `trim:1-57`, `viewlines:1-65`, `prepare-tts-text:1-62`, `spinner.sh:1-86`, `killwait:1-27`, `log-error:1-67`
- Key reproducers:
  - `set -e` + bare `checkCache` exit: `bash -c 'set -eo pipefail; f(){ return 1; }; f; echo after'` → no `after`, exit 1; `f || true` → continues.
  - `viewlines` reversed: `tmp=$(mktemp); echo -e "a\nb" > $tmp; viewlines "$tmp" 1` → `a`, `viewlines 1 "$tmp"` → `[ERROR] File 1 doesn't exist`, exit 1.
  - Empty `playerCmd`: `playerCmd=(); printf "[%s] " "${playerCmd[@]}" "file.wav"` → `[file.wav]` then attempted exec → `file.wav: command not found`.
  - `viewlines` error inside `checkCache` assignment: `cachedState[text]="$(viewlines 1 "$tmp" 2>/dev/null)" || echo fail` → `assignment failed 1` (not parent kill, SIGUSR1 targets viewlines PID).
