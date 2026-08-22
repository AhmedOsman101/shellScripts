# Batch Review: 07 of 22

**Scripts in this batch:** `readtime` (233), `selcp` (30), `pnpm-ls` (30), `now` (30)
**Batch composition:** large-tool-plus-fillers — `readtime` is the large tool; `selcp`, `pnpm-ls`, `now` are 3 small unrelated fillers paired incidentally to fill the 323-line budget (cap 4). No shared name-family or directory group.
**Reviewer:** subagent-07
**Date:** 2026-08-21

---

## House Style Reference (do not flag these as bugs)

Before reviewing, confirm you've internalized these repo conventions. Restate them here in one line each to prove the context loaded correctly:

- Dependency declaration format (`# - binary | binary2 (pkg-override)`) and how `checkDep` resolves it: deps between `DEPENDENCIES`/`END SIGNATURE` as `# - exe | alt (pkg)`, `checkDep` splits on `|` and `Trim`s then `command -v` each alt in order — any hit returns 0, only if none found it extracts `pkg` from `(parens)` via `grep -oP` else first exe for install.
- Logging convention: `log-*` wrapper scripts are primary, camelCase `log*` functions in `lib/helpers.sh` are fallback: standalone `log-debug`/`log-warning`/`log-error`/etc. dispatch via `log.sh`+`LEVEL_COLORS`/`LEVEL_OUTPUT`/`colorOnlyPrefix`; `lib/helpers.sh` `logWarning`/`logError` are in-process fallback, not dead code.
- `trap 'exit 1' SIGUSR1` + `kill -SIGUSR1 "${PPID}"` propagation chain purpose: every script traps SIGUSR1 → exit 1; only `log-error` sends `kill -SIGUSR1 $PPID` (guarded by `! isInteractiveShell && ! noKill`) to kill the parent without exit-code checks — deliberate.
- `cmdarg.sh` argument-parsing pattern used across scripts: `source include "lib/cmdarg.sh"` → `cmdarg_info "header" "$(get-desc "$0")"` → pre-declare `declare -a/ -A` for `[]`/`{}` → `cmdarg "x:"`/`"x?"`/`"x"` (+ `[]`/`{}`) → `cmdarg_parse "$@"` → read `cmdarg_cfg['key']` (boolean literal `true`/`false`) and `argv`/`argc`; `-h/--help` reserved.
- `get-desc` / `get-deps` signature-block parsing rules: both `sed -n` between `# --- DESCRIPTION/DEPENDENCIES --- #` and `# --- END SIGNATURE --- #`; missing block allowed, prints `x-none`, `checkDeps` returns 0; `get-desc` terminates on either `DEPENDENCIES` or `END SIGNATURE`.
- `init.sh` / `hooks/path.sh` symlink and PATH-registration workflow: `init.sh` verifies `SCRIPTS_DIR`/`fd`/`hooks/path.sh` then idempotently appends `source hooks/path.sh` to `.bashrc`/`.zshrc`; `hooks/path.sh` (sourced at startup) caches `fd -t x` executables to `/tmp/path-hook.cache` and adds each dir once to `PATH` guarded by `:":$PATH:"`.
- Reference pattern from `clangc` (what "correct" looks like in this repo): `set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `source include "lib/cmdarg.sh"` + `source include "lib/compile.sh"` + `source include "check-deps"` + `checkDeps "$0"` → `cmdarg_info` → pre-declare array → `cmdarg "c"`/`"o?"`/`"a?[]"`/`"q"` → `cmdarg_parse "$@"` → literal `cmdarg_cfg` reads → `((argc<1)) && log-error` → arrays + nameref delegate.

---

## Script Reviews

### `readtime`

**Path:** `/home/othman/scripts/readtime`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Accepts file(s) or raw text and outputs how long it takes to read in minutes.
**Declared dependencies:** `pandoc`, `pdftotext (poppler)`, `wc`
**Verdict:** `Needs fixes`

#### Critical bugs

None found — no unconditional crash on the default file/stdin path. The failures below are either dead-code or produce silently wrong totals / resource leaks rather than hard crashes, so classified under Design.

#### Design issues

- **What happens:** Dead code + undefined callee; if ever re-enabled the script crashes.
- **Where:**
```bash
# readtime:47-51
hasStdinRedirected() {
  local stdin_source
  stdin_source=$(readlink /proc/self/fd/0 2>/dev/null || echo "")
  [[ "${stdin_source}" != "/dev/null" ]]
}
# ... never called

# readtime:148-172
processStdinFromPeek() {
  local data
  local words

  if data=$(hasStdinWithData); then
```

- **Why it's wrong:** `hasStdinRedirected` is defined but never used. `processStdinFromPeek` is never called (main calls `processStdin` for `! -t 0`), and it calls `hasStdinWithData` which is not defined anywhere in the repo. Any future caller hits `command not found` under `set -e`. Also `hasStdinRedirected` is Linux-only (`/proc/self/fd/0` + `readlink`) and non-portable.
- **Fix:** Delete both dead functions, or if stdin-peek is wanted wire it correctly and define `hasStdinWithData` (e.g. `[[ ! -t 0 ]] && IFS= read -r -t 0.1 peek` or keep `processStdin` only).
```bash
# delete hasStdinRedirected and processStdinFromPeek entirely
```

- **What happens:** Inconsistent `processed`/`total` accounting and dual global/local counters give silently wrong totals.
- **Where:**
```bash
# readtime:40-41  globals
TOTAL=0
PROCESSED=0
# readtime:200-203 locals that shadow them
main() {
  local total=0
  local processed=0
  local failed=0
# readtime:102-127 processFile increments processed on empty, and failed on unreadable
  if [[ -z "${words}" || "${words}" -eq 0 ]]; then
    log-warning "No readable content: ${file}"
    processed=$((processed + 1))
    return 0
  fi
# readtime:174-198 processMultipleInputs does NOT increment processed on empty
    if [[ -z "${words}" || "${words}" -eq 0 ]]; then
      log-warning "No readable content: ${file}"
      continue
    fi
# readtime:219-220 late promotion
  TOTAL="${total}"
  PROCESSED="${processed}"
```

- **Why it's wrong:** `processFile` counts empty files toward `processed`; `processMultipleInputs` silently `continue`s without. `TOTAL`/`PROCESSED` globals duplicate `total`/`processed` locals and are only promoted after `main` — dynamic-scope reliance (`processed` in callees resolves to `main`'s local) works but is fragile and shellcheck-hostile. `outputTotal` reads the globals, so a future refactor that moves promotion breaks it.
- **Fix:** Normalize: either count empties consistently (increment `processed` in both) or don't count them at all; promote immediately or eliminate globals and have `outputTotal` take args.
```bash
# in processMultipleInputs, add the missing increment (or remove it from processFile — pick one)
    if [[ -z "${words}" || "${words}" -eq 0 ]]; then
      log-warning "No readable content: ${file}"
      processed=$((processed + 1))
      continue
    fi
# consider removing TOTAL/PROCESSED globals and passing total/processed to outputTotal
```

- **What happens:** PDF temp file leaked and `mdclean` failure aborts whole script under `pipefail`.
- **Where:**
```bash
# readtime:57-67
countWordsFromFile() {
  local temp
  if [[ "$(file --mime-type --brief "${file}")" == "application/pdf" ]]; then
    temp="$(mktemp)"
    pdftotext -enc UTF-8 -eol unix -q "${file}" "${temp}"
    mdclean -q "${temp}"
    pandoc "${temp}" -t plain 2>/dev/null | wc -w | trim
  else
    pandoc "${file}" -t plain 2>/dev/null | wc -w | trim
  fi
}
```

- **Why it's wrong:** `mktemp` file never `rm`'d (trap or `rm -f`). `mdclean -q` can fail (needs `sponge`/`perl`/`parallel`); under `set -eo pipefail` a failing `mdclean` aborts the `$(countWordsFromFile)` substitution, losing the word count for that file with no warning.
- **Fix:**
```bash
countWordsFromFile() {
  local temp
  if [[ "$(file --mime-type --brief "${file}")" == "application/pdf" ]]; then
    temp="$(mktemp)"; trap 'rm -f "${temp}"' RETURN
    pdftotext -enc UTF-8 -eol unix -q "${file}" "${temp}"
    mdclean -q "${temp}" || true
    pandoc "${temp}" -t plain 2>/dev/null | wc -w | trim
  else
    pandoc "${file}" -t plain 2>/dev/null | wc -w | trim
  fi
}
```

- **What happens:** Sorting + total race via `sleep 0.1`.
- **Where:**
```bash
# readtime:227-233
case "${sortMode}" in
asc) main "$@" > >(sort -h) ;;
desc) main "$@" > >(sort -hr) ;;
? | *) main "$@" ;;
esac

sleep 0.1 && outputTotal
```

- **Why it's wrong:** `> >(sort)` is async; `sleep 0.1` is a best-effort wait for `sort` to flush. Under load the total prints before `sort` finishes or interleaves. Also `main "$@"` is semantic noise — after `cmdarg_parse`, `$@` is empty, `main` reads global `argv`/`argc` anyway. Sorting via `sort -h` on strings like `"5 min read \"file\""` works by accident (numeric prefix) but sorts the human-quote suffix lexicographically as tie-breaker.
- **Fix:** Group synchronously:
```bash
case "${sortMode}" in
asc)  { main; outputTotal; } | sort -h | { cat; } ;;  # or split: main > >(sort) then wait
desc) { main; outputTotal; } | sort -hr ;;
*)    main; outputTotal ;;
esac
# or keep total unsorted: tmp=$(mktemp); main >"$tmp"; sort <"$tmp"; outputTotal
```

- **What happens:** No validation of `--wpm`; `--wpm 0` or non-integer crashes `calculateMinutes`.
- **Where:**
```bash
# readtime:39
WPM="${cmdarg_cfg[wpm]}"
# readtime:69-74
calculateMinutes() {
  local words="$1"
  local minutes=$(((words + WPM - 1) / WPM))
  ((minutes < 1)) && minutes=1
  echo "${minutes}"
}
```

- **Why it's wrong:** `cmdarg 'w?' 'wpm' "" '150'` allows any string; `WPM=0` → division by zero (`set -e` aborts); `WPM=abc` → arithmetic error. `words` can be empty string (failed `wc`) → `(( "" + ... ))` error guarded earlier but not here if caller passes bad value.
- **Fix:** Validate after parse:
```bash
WPM="${cmdarg_cfg[wpm]}"
isPositiveInt "${WPM}" || log-error "--wpm must be a positive integer (got '${WPM}')"
(( WPM > 0 )) || log-error "--wpm must be > 0"
```

- **What happens:** Declared deps incomplete.
- **Where:**
```bash
# readtime:16-19
# --- DEPENDENCIES --- #
# - pandoc
# - pdftotext (poppler)
# - wc
```

- **Why it's wrong:** Script also requires `file` (mime check), `trim` (repo script forwarding to `sed`), `mdclean` (repo script, itself needs `sponge`/`perl`/`parallel`), and `sort` for `--sort`. `wc` is coreutils and per house brief could be omitted, but `file`/`mdclean`/`trim` should be listed so `checkDeps` can prompt.
- **Fix:** Expand block:
```bash
# --- DEPENDENCIES --- #
# - pandoc
# - pdftotext (poppler)
# - file
# - mdclean
# - trim
```

#### Minor / style

- `countWordsFromFile` ignores its `$1` and reads the caller's `local file` via bash dynamic scope (`pandoc "${file}"`). Works but couples caller/callee by name; pass explicitly `local file="$1"` inside callee. Same pattern repeated in `processMultipleInputs` loop variable `file` shadowing the callee's expectation — rename to be explicit.
- `quiet="${cmdarg_cfg[quiet]}"` without `:-false` default is safe because boolean defaults to `"false"`, but canonical style in `clangc` is `"${cmdarg_cfg['quiet']}"`; quoting/inner single-quotes difference is cosmetic — keep consistent.
- `wc -w | trim` forks the repo `trim` script (itself does `cmdarg_parse` + `checkDeps`) for each file. Cheaper to use `Trim "$(wc -w)"` helper or `xargs`/`sed 's/^[[:space:]]*//'`. Not a bug, but 100-file run forks 100× trim sub-shells.
- `outputTotal` ends with `return 0` masking any earlier failure status from the `sort` pipeline.

#### Confirmed correct (potential false positives)

- `set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `source "$(include "lib/cmdarg.sh")"` + `source "$(include "lib/helpers.sh")"` + `source "$(include "check-deps")"` + `checkDeps "$0"` order matches `clangc` reference.
- `log-warning` dispatcher is correct — `readtime` sources `lib/helpers.sh` but calls external `log-warning` script which forwards to `log.sh` → `colorOnlyPrefix printYellow "WARNING" ... 2`; the `logWarning` camelCase fallback in `lib/helpers.sh` is the same layer, not dead code per house style.
- `WPM="${cmdarg_cfg[wpm]}"` with unquoted key `wpm` is valid; `cmdarg` booleans as literal `true`/`false` commands used as `"${cmdarg_cfg[sort]}" && sortMode='asc'` works (quoted `"true"`/`"false"` still executes).
- `humanQuote "${label}"` is the correct helper per `lib/helpers.sh:356`; not a missing import.
- `file --mime-type --brief` usage for PDF detection is intentional; `file` is the binary, not the variable, and the `file` vs `file` shadowing is disambiguated by `local file="$1"` scoping in callers.

---

### `selcp`

**Path:** `/home/othman/scripts/selcp`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Copy selected text using xsel
**Declared dependencies:** `xsel`
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **What happens:** Second dep not declared; script fails on Wayland or minimal containers.
- **Where:**
```bash
# selcp:16-17
# - xsel
# selcp:30
xsel | clipcopy
```

- **Why it's wrong:** `clipcopy` is a repo script (needs `xclip | wl-copy | copyq` + `ansifilter` per its header) but is not listed. On Wayland where `xsel` may be missing but `wl-copy` exists, `checkDeps` would try to install `xsel` unnecessarily, and `clipcopy`'s own `checkDeps` would fail later with a confusing nested prompt. `xsel` itself is X11-only; `selcp` should declare the fallback chain.
- **Fix:**
```bash
# --- DEPENDENCIES --- #
# - xsel
# - clipcopy
# or more honestly:
# - xsel | wl-paste (wl-clipboard)
# - clipcopy
```

- **What happens:** No handling of empty selection; `clipcopy` then `log-error "No valid input was given"` under `set -e` kills parent via SIGUSR1.
- **Where:**
```bash
# selcp:30
xsel | clipcopy
```

- **Why it's wrong:** `xsel` with no selection blocks or returns empty; pipe to `clipcopy` which does `[[ -z "${str}" ]] && log-error ...` → `kill -SIGUSR1 $PPID` terminates `selcp` with exit 1 but no hint that the clipboard was simply empty. User sees a fatal error for a normal no-selection case.
- **Fix:** Guard or map to warning:
```bash
if ! sel=$(xsel 2>/dev/null); then sel=""; fi
[[ -z "${sel}" ]] && log-warning "No X selection to copy" && exit 0
printf '%s' "${sel}" | clipcopy
```

#### Minor / style

- No `get-desc`/`cmdarg_info` description beyond default; script takes no flags but declares none — `cmdarg_parse "$@"` handles `--help` correctly, but any positional args are silently ignored (should warn on `argc>0`).

#### Confirmed correct (potential false positives)

- `set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `source "$(include "lib/cmdarg.sh")"` + `source "$(include "check-deps")"` + `checkDeps "$0"` → `cmdarg_info` → `cmdarg_parse` matches `clangc` shape (helpers not needed since no `humanQuote`).
- `xsel | clipcopy` pipeline is intentional for the repo: `xsel` reads PRIMARY selection, `clipcopy` writes to CLIPBOARD via `xclip`/`wl-copy`/`copyq` — not a tautology.
- Dependency line `# - xsel` single-form is valid per `checkDep` (no pipe/parens needed); not a syntax error.

---

### `pnpm-ls`

**Path:** `/home/othman/scripts/pnpm-ls`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): List globally installed pnpm packages
**Declared dependencies:** `pnpm`
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **What happens:** Missing `jq` dependency causes hard failure when `jq` not installed; `checkDeps` won't install it.
- **Where:**
```bash
# pnpm-ls:16-17
# - pnpm
# pnpm-ls:30
pnpm ls -g --no-color --json | jq -r '.[0].dependencies | keys | sort | .[]'
```

- **Why it's wrong:** Pipeline assumes `jq` exists. Under `set -eo pipefail`, missing `jq` → `command not found` → exit 127, trap fires, no install prompt. `get-deps` extraction would have prompted if `jq` were listed.
- **Fix:**
```bash
# --- DEPENDENCIES --- #
# - pnpm
# - jq
```

- **What happens:** `null` dependencies crashes listing when no global packages installed.
- **Where:**
```bash
# pnpm-ls:30
pnpm ls -g --no-color --json | jq -r '.[0].dependencies | keys | sort | .[]'
```

- **Why it's wrong:** `pnpm ls -g --json` returns `[{"dependencies": null}]` when empty. `jq '.[0].dependencies | keys'` → `Cannot iterate over null (null)` → `jq` exits 5, pipeline fails, script exits via `set -e` with no output and no friendly message.
- **Fix:**
```bash
pnpm ls -g --no-color --json | jq -r '.[0].dependencies // {} | keys | sort | .[]'
# or handle empty: | jq -r '... // empty'
```

#### Minor / style

- `pnpm ls -g` lists transitive deps flattened; `keys | sort` re-sorts alphabetically — redundant with `sort` if `jq` already sorted, but harmless.
- No `--help` flags defined; fine for zero-flag tool — `cmdarg_parse "$@"` still correctly surfaces `-h`.

#### Confirmed correct (potential false positives)

- `set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `source "$(include "lib/cmdarg.sh")"` + `source "$(include "check-deps")"` + `checkDeps` + `cmdarg_info "$(get-desc "$0")"` + `cmdarg_parse "$@"` matches canonical `clangc` order; missing `lib/helpers.sh` is fine (no `humanQuote`/`log*` helpers needed inline).
- Declared dep `# - pnpm` single-entry form is correct per `checkDep` logic.
- `pnpm ls -g --no-color --json` → `jq` pipeline is the intended repo pattern for JSON filtering; not a useless-use-of-jq.

---

### `now`

**Path:** `/home/othman/scripts/now`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Prints the current date and time
**Declared dependencies:** `date`
**Verdict:** `Clean`

#### Critical bugs

None found.

#### Design issues

None found.

#### Minor / style

- Declared dep `date` (coreutils) is per AGENTS.md optional to omit (coreutils available everywhere); listing it is harmless but noisy — could be removed and `get-deps` would return `x-none`. Not a bug.
- Format `"%Y-%m-%d@%I:%M%p"` uses 12-hour clock without seconds or timezone; callers needing ISO-8601/sortable/UTC may want `"%Y-%m-%d@%H:%M:%S%z"` — intentional as described, only flag if requirements change.

#### Confirmed correct (potential false positives)

- `set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `source "$(include "lib/cmdarg.sh")"` + `source "$(include "check-deps")"` + `checkDeps` + `cmdarg_info` + `cmdarg_parse` follows `clangc`; missing `lib/helpers.sh` is correct (no helpers used).
- `checkDeps` with dependency `date` will always return 0 (found in coreutils) — not a failure mode.
- `date +"%Y-%m-%d@%I:%M%p"` quoting is correct; no word-splitting risk.

---

## Batch Summary

- **Scripts reviewed:** 4 / 4
- **Critical bugs:** none — `readtime` issues are design/silent-wrong-total/resource-leak class, not unconditional crashes on the happy path (dead `hasStdinWithData` is unreachable)
- **Design issues worth escalating:** `readtime` (5 items: dead `hasStdinWithData`/`hasStdinRedirected`, inconsistent empty-file counting + `TOTAL`/`PROCESSED` dual-state, PDF `mktemp` leak + `mdclean||true`, `sleep 0.1` async sort race, missing `file`/`mdclean`/`trim` deps + missing `--wpm` validation); `pnpm-ls` (missing `jq` dep + null-dependencies `jq` crash); `selcp` (missing `clipcopy` dep + empty-selection fatal error)
- **Cross-cutting patterns observed in this batch** (same bug/pattern repeated across multiple scripts in this batch only; batch-level, not repo-wide): incomplete dependency blocks (3/4 scripts omit transitive repo-script deps: `readtime` omits `file`/`trim`/`mdclean`, `selcp` omits `clipcopy`, `pnpm-ls` omits `jq`) — suggests copy-paste of minimal `# - single` block without auditing pipeline/conditional deps; and `set -eo pipefail` without `|| true` guards on expected-empty `jq`/`mdclean`/`pandoc` steps (seen in `readtime` and `pnpm-ls`).
- **Open questions** (design intent unclear, needs the repo owner's input rather than a guess): `readtime` — should empty files count toward `PROCESSED`? (single-file vs multi-file paths disagree); should `mdclean` run on PDF-extracted temp at all (plain text → markdown clean is no-op)?; should `--sort` include `TOTAL` line or keep it pinned last (current `sleep` hack suggests pinned, but spec doesn't say)?; `selcp` — intended to support Wayland (`wl-paste`) or strictly X11 `xsel`?; `now` — is `date` kept in deps intentionally for self-documentation or should coreutils deps be omitted per AGENTS.md?

## Evidence appendix

- `hasStdinWithData` undefined, only reference: `readtime:152  if data=$(hasStdinWithData); then` — grep `-rn hasStdinWithData` across repo yields only that line; `hasStdinRedirected` defined at `readtime:47` never called.
- `trim` is a repo script (`/home/othman/scripts/trim`, 57 lines, wraps `sed`), not `lib/helpers.sh:210 Trim()` — so `wc -w | trim` forks a full cmdarg-parsing script per file, works but heavy; `Trim()` exits on empty (`exit 0`) so script correctly uses external `trim`.
- `mdclean` header requires `sponge (moreutils) | perl | parallel` — transitive deps not surfaced through `readtime`'s `checkDeps`.
- `clipcopy` header requires `xclip | wl-copy (wl-clipboard) | copyq` + `ansifilter` — transitive deps not surfaced through `selcp`.
- `sort` pipeline race reproduced: `main > >(sort -h); sleep 0.1; outputTotal` — `sort` is async subprocess, `sleep` is arbitrary; `wait` or grouping needed for correctness.

