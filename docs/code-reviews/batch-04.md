# Batch Review: 04 of 22

**Scripts in this batch:** `document-with-llm`, `c/release.sh`, `typescript/release.sh`, `rofi/rofi-askpass` (4 scripts, 343 lines)
**Batch composition:** large+fillers — `document-with-llm` (316) large + 3 tiny fillers (`c/release.sh` 7, `typescript/release.sh` 9, `rofi/rofi-askpass` 11) — pairing incidental, cap 4, budget 343. If the batch shares a real pattern, name it here: no shared pattern, fillers unrelated.
**Reviewer:** subagent-04
**Date:** 2026-08-21

---

## House Style Reference (do not flag these as bugs)

Before reviewing, confirm you've internalized these repo conventions. Restate them here in one line each to prove the context loaded correctly:

- Dependency declaration format (`# - binary | binary2 (pkg-override)`) and how `checkDep` resolves it: deps between `# --- DEPENDENCIES --- #` / `# --- END SIGNATURE --- #` as `# - exe | alt (pkg)`; `checkDep` splits on `|`, `Trim`s, takes first word per alternative, `command -v` each in order — if any found return 0 satisfied, else echoes `(pkg)` override or bare exe for `installDep`.
- Logging convention: `log-*` wrapper scripts are primary, camelCase `log*` functions in `lib/helpers.sh` are fallback: standalone `log-debug`/`log-info`/`log-warning`/`log-error`/`log-success` + dispatcher `log.sh` via `LEVEL_COLORS`/`LEVEL_OUTPUT`/`colorOnlyPrefix` are canonical CLI; `lib/helpers.sh` `logDebug`/`logSuccess` etc. and `lib/loggers.sh` `printRed`/`printer`/`supportsColor` are in-process fallback, not dead code.
- `trap 'exit 1' SIGUSR1` + `kill -SIGUSR1 "${PPID}"` propagation chain purpose: every script traps SIGUSR1 to `exit 1`; only `log-error` sends `kill -SIGUSR1 "${PPID}" &>/dev/null || true; wait ... || true` guarded by `! isInteractiveShell && ! noKill` (`--no-kill`/`--no-error`/`--safe`) to kill parent without explicit exit-code checks.
- `cmdarg.sh` argument-parsing pattern used across scripts: `source "$(include "lib/cmdarg.sh")"` then `cmdarg_info "header" "$(get-desc "$0")"`; pre-declare `declare -a`/`declare -A` for `[]`/`{}` types; `cmdarg "v"` bool defaults `false`/literal `true`, `"m:"` required string, `"o?"` optional string, `"a?[]"`/`"H?{}"` arrays/hashes; `cmdarg_parse "$@"` then read `cmdarg_cfg`/`argv`/`argc`; `-h`/`--help` reserved.
- `get-desc` / `get-deps` signature-block parsing rules: both parse `# --- DESCRIPTION --- #` … `# --- DEPENDENCIES --- #` … `# --- END SIGNATURE --- #` via `sed`; missing DESCRIPTION or DEPENDENCIES is allowed (`get-deps` prints `x-none`, `checkDeps` returns 0, `get-desc` tolerates either terminator), `replace.sh` + `grep -v " --- "` filtering.
- `init.sh` / `hooks/path.sh` symlink and PATH-registration workflow: `init.sh` verifies `SCRIPTS_DIR` (`~/scripts`), ensures `fd` (prompts symlink `fdfind->fd`), checks `hooks/path.sh`, idempotently appends `[[ -s "${SCRIPTS_DIR}/hooks/path.sh" ]] && source ...` to `~/.bashrc`/`.zshrc`; `hooks/path.sh` (sourced at startup) caches `fd --strip-cwd-prefix=always --no-ignore-vcs -t x . --exclude ...` to `/tmp/path-hook.cache`, rescans only when `find ... -newer cache`, adds each executable's dir once to `PATH` via `:...:` guard, then unsets temps.
- Reference pattern from `clangc` (what "correct" looks like in this repo): `set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `source "$(include "lib/cmdarg.sh")"` + `source "$(include "lib/compile.sh")"` + `source "$(include "check-deps")"` + `checkDeps "$0"` in order; `cmdarg_info`/`declare -a compiler_args`/`cmdarg "c"`/`"o?"`/`"a?[]"`/`"q"`/`cmdarg_parse "$@"`; literal `cmdarg_cfg` reads, `((argc <1)) && log-error`, array-safe `compile_and_run` with namerefs.

---

## Script Reviews

### `document-with-llm`

**Path:** `/home/othman/scripts/document-with-llm`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Documents non-bash scripts using an LLM to generate wiki pages
**Declared dependencies:** `opencode | pi | claude` , `xxh3sum (xxhash) | xxhsum (xxhash) | sha1sum (coreutils)`
**Verdict:** `Critical bug`

#### Critical bugs

- **What happens:** hash-based change detection is dead code — any existing wiki page is skipped even when source changed, unless `--force` is used, so incremental docs never auto-update.
- **Where:**

```bash
# document-with-llm:217-228
  hash="$(projectHash "${project_path}")"
  cache_file="${cacheDir}/${lang}-${project_name}.hash"
  if [[ -f "${output_file}" ]] && [[ -f "${cache_file}" ]] && [[ "$(<"${cache_file}")" == "${hash}" ]] && ! "${FORCE}"; then
    logVerbose "Skipping ${project_name} (unchanged)"
    return 0
  fi

  # Skip if exists and not forced
  if [[ -f "${output_file}" ]] && ! "${FORCE}"; then
    logVerbose "Skipping ${project_name} (exists)"
    return 0
  fi
```

- **Why it's wrong:** second condition is a superset of the first — when `output_file` exists and `FORCE=false`, it returns regardless of whether hash matches. Intent was `if exists && hash matches skip unchanged else regenerate`, but current code always skips existing files, defeating `projectHash`/`cacheDir` logic entirely. Silent incorrect behavior.
- **Fix:**

```bash
  hash="$(projectHash "${project_path}")"
  cache_file="${cacheDir}/${lang}-${project_name}.hash"
  if [[ -f "${output_file}" ]] && [[ -f "${cache_file}" ]] && [[ "$(<"${cache_file}")" == "${hash}" ]] && ! "${FORCE}"; then
    logVerbose "Skipping ${project_name} (unchanged)"
    return 0
  fi
  # Remove the second blanket exists-check, or gate it on hash equality.
  # If you want a “skip if exists” fallback only when cache missing:
  # if [[ -f "${output_file}" ]] && [[ ! -f "${cache_file}" ]] && ! "${FORCE}"; then ...
```

- **What happens:** `claude` provider ignores user-supplied `--model` and always invokes `opus`.
- **Where:**

```bash
# document-with-llm:272-283
  claude)
    cd "${run_dir}" || exit
    if [[ -n "${MODEL}" ]]; then
      ANTHROPIC_DEFAULT_FABLE_MODEL="${MODEL:-}" \
        ANTHROPIC_DEFAULT_OPUS_MODEL="${MODEL:-}" \
        ANTHROPIC_DEFAULT_SONNET_MODEL="${MODEL:-}" \
        ANTHROPIC_DEFAULT_HAIKU_MODEL="${MODEL:-}" \
        claude --model "opus" "$(full_prompt)"
    else
      claude "$(full_prompt)"
    fi
```

- **Why it's wrong:** `MODEL` is validated but never forwarded — `claude --model "opus"` is hardcoded. User passing `-m sonnet` or `-m haiku` still gets opus. Also env var `ANTHROPIC_DEFAULT_FABLE_MODEL` is a typo (should be `FABLE`? standard vars are `ANTHROPIC_DEFAULT_HAIKU`/`SONNET`/`OPUS`, FABLE does not exist).
- **Fix:**

```bash
  claude)
    cd "${run_dir}" || return 1
    if [[ -n "${MODEL}" ]]; then
      ANTHROPIC_DEFAULT_HAIKU_MODEL="${MODEL}" \
        ANTHROPIC_DEFAULT_SONNET_MODEL="${MODEL}" \
        ANTHROPIC_DEFAULT_OPUS_MODEL="${MODEL}" \
        claude --model "${MODEL}" "$(full_prompt)"
    else
      claude "$(full_prompt)"
    fi
```

- **What happens:** `projectHash` for an empty directory hangs waiting on stdin.
- **Where:**

```bash
# document-with-llm:180-192
projectHash() {
  local project_path="$1"
  local -a files

  if [[ -d "${project_path}" ]]; then
    mapfile -t files < <(fd.sh . "${project_path}" --type f | sort)
  else
    files=("${project_path}")
  fi

  cat "${files[@]}" 2>/dev/null | hasher | awk '{print $1}'
}
```

- **Why it's wrong:** when `files` is empty, `cat` with zero args reads stdin (script's stdin/tty) and blocks indefinitely. Empty typescript/python project or filtered directory would hang the whole run. `hasher` reads stdin when given no args, so cat should be guarded.
- **Fix:**

```bash
  if ((${#files[@]} == 0)); then
    printf '' | hasher | awk '{print $1}'
  else
    cat "${files[@]}" 2>/dev/null | hasher | awk '{print $1}'
  fi
```

#### Design issues

- **What happens:** `set -eo pipefail` is commented out, deviating from house invariant.
- **Where:**

```bash
# document-with-llm:21-22
# set -eo pipefail
trap 'exit 1' SIGUSR1
```

- **Why it's wrong:** every repo script per `house-style-brief.md` §4 and `clangc` reference starts with `set -eo pipefail` for fail-fast; here failures in `mkdir -p`, `cat template`, `collectContext`, `fd.sh`, `hasher` will not abort and empty context may generate empty wiki pages. Kill chain via `log-error` still traps SIGUSR1, but other errors are silent.
- **Fix:** uncomment `set -eo pipefail` (or `set -euo pipefail` if desired) and adjust `logVerbose` to not trigger `set -e` (see Minor). Alternatively document why pipefail is intentionally disabled.

- **What happens:** `cd "${run_dir}" || exit` permanently changes cwd and `exit` terminates entire script, not just current project.
- **Where:**

```bash
# document-with-llm:268-271
  pi)
    cd "${run_dir}" || exit
    pi ${MODEL:+--model "${MODEL}"} "$(full_prompt)"
    ;;
  claude)
    cd "${run_dir}" || exit
```

- **Why it's wrong:** `generateWithLLM` is called in a loop over many projects; `cd` without `pushd`/`popd` or subshell leaves process in first project's directory for all subsequent iterations. `|| exit` kills whole batch if one project's dir is missing, rather than skipping. `opencode` path correctly avoids `cd` and passes `run_dir` as arg.
- **Fix:**

```bash
  pi)
    ( cd "${run_dir}" || { log-warning "cannot cd ${run_dir}"; return 1; }
      pi ${MODEL:+--model "${MODEL}"} "$(full_prompt)" )
    ;;
  claude)
    ( cd "${run_dir}" || { log-warning "cannot cd ${run_dir}"; return 1; }
      # ... claude invocation ...)
    ;;
```

Or use `pushd`/`popd` with `return` not `exit`.

- **What happens:** hash concatenation via `cat "${files[@]}"` introduces collision risk — `file1="ab" + file2="c"` hashes same as `file1="a" + file2="bc"`.
- **Where:** `cat "${files[@]}" 2>/dev/null | hasher` in `projectHash`.
- **Why it's wrong:** `lib/compile.sh:generate_cache_key` correctly uses `printf '%s\0'` null separators to avoid ambiguity; this function drops that safety for wikidocs. Low severity but worth noting.
- **Fix:** stream with null separators: `printf '%s\0' "${files[@]}"` and include separators between file contents: `{ for f in "${files[@]}"; do printf '%s\0' "$f"; cat -- "$f"; printf '\0'; done; } | hasher`.

- **What happens:** `collectContext` for typescript only includes first `*.ts` file (`head -1`).
- **Where:**

```bash
# document-with-llm:128-137
    local ts_file
    ts_file=$(find "${project_path}" -maxdepth 1 -name "*.ts" -type f | head -1)
    if [[ -n "${ts_file}" ]]; then
      context+="## $(basename "${ts_file}")"
      context+=$'\n\n'
      context+='```typescript'
      context+=$'\n'
      context+="$(cat "${ts_file}")"
```

- **Why it's wrong:** project with multiple entry points (e.g., `typescript/mediactl` has `mediactl.ts` plus others) will have incomplete LLM context; not incorrect but fragile and undocumented.
- **Fix:** loop over all `*.ts` files or document that only first file is used; or pick `main.ts`/`index.ts` convention.

#### Minor / style

- `logVerbose() { "${VERBOSE}" && logInfo "$1"; }` uses `"${VERBOSE}" &&` direct execution; house idiom is `if ${cmdarg_cfg['verbose']}; then` — works because booleans are literal `true`/`false` commands, but `if`-form is clearer and matches `clangc` style. Under `set -e` it's safe (part of `&&` list), but `if` form is preferred for consistency.
- `prompt() { cat "${SCRIPTS_DIR}/templates/document-with-llm/prompt.md"; }` has no existence check — `cat` failure is silent when `set -e` disabled; add `[[ -f ... ]] || log-warning ...`.
- Double `!` negation `[[ "$(<"${cache_file}")" == "${hash}" ]] && ! "${FORCE}"` is correct per boolean literal contract (`! false` succeeds), but quoting `"${FORCE}"` as command is subtle; house style uses `if ${FORCE}; then` or `${FORCE} ||` — keep but note.
- `full_prompt()` defined inside `generateWithLLM` leaks global function redefined each iteration — move outside as `buildPrompt <output_file> <context>` or use local `prompt_text` variable instead of nested function.
- Template path `${SCRIPTS_DIR}/templates/document-with-llm/prompt.md` assumes `SCRIPTS_DIR` set — correctly defaulted at line 23 `SCRIPTS_DIR="${SCRIPTS_DIR:-${HOME}/scripts}"`, unlike `c/release.sh` fillers.

#### Confirmed correct (potential false positives)

- `# - opencode | pi | claude` and `# - xxh3sum (xxhash) | xxhsum (xxhash) | sha1sum (coreutils)` pipe + parens syntax is correct per `house-style-brief.md` §2; `checkDep` splits on `|` and checks `command -v` for each alternative in order, extracting `(pkg)` override only if none found — not a syntax error.
- `source "$(include "lib/cmdarg.sh")"` / `lib/helpers.sh` / `check-deps` + `checkDeps "$0"` indirection via `include` (`realpath -m`) is intentional house-style path resolution, not fragile.
- `trap 'exit 1' SIGUSR1` without matching `kill` in this file is intentional — only `log-error` sends SIGUSR1 per brief §4; every script must trap even if not sender.
- `cmdarg "d?"` optional string with default `"${SCRIPTS_DIR}/wiki"`, `cmdarg "p?"` with default `pi`, `cmdarg "m?"` optional no default, `cmdarg "f"`/`"v"` booleans default `false` — correctly matches `cmdarg.sh` contract (§5) with `declare -a` not needed for scalar flags, `cmdarg_parse "$@"` exactly.
- `WIKI_DIR="${cmdarg_cfg['dir']}"` / `PROVIDER` / `FORCE` / `VERBOSE` literal reads and boolean tests via `"${FORCE}"`/`"${VERBOSE}"` executing `true`/`false` commands are canonical.
- `checkDeps` returns 0 when deps are `x-none` (empty block) — empty deps in other fillers are allowed per §6, not missing deps.
- `getProjects` using `find "${SCRIPTS_DIR}/typescript" -mindepth 1 -maxdepth 1 -type d ! -name '.*'` and similar for `python`/`c`/`cpp`/`lua` correctly mirrors repo layout; `mapfile -t projects < <(getProjects ...)` + `((${#projects[@]})) || continue` correctly handles empty results.
- `PROJECT OUTPUT FILE` line in prompt and `hasher`/`cat` pipeline for hash are not reinventing stdlib — reuse existing `hasher` from `lib/helpers.sh`.
- `log-error --no-kill "Unknown provider: ${PROVIDER}"` correctly uses `--no-kill` guard from `log-error:30` to avoid SIGUSR1 propagation for usage errors.

---

### `c/release.sh`

**Path:** `/home/othman/scripts/c/release.sh`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): none — file has no `# --- DESCRIPTION --- #` / `# --- DEPENDENCIES --- #` signature block (allowed per house-style §6, but this is a tiny filler)
**Declared dependencies:** none (no block → `get-deps` yields `x-none`, `checkDeps` would return 0 if called)
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **What happens:** `SCRIPTS_DIR` used without fallback; when env var is unset, expands to `/bin`.
- **Where:**

```bash
# c/release.sh:5-7
mkdir -p "${SCRIPTS_DIR}/bin" &>/dev/null

fd.sh --no-ignore -e out --exec mv {} "${SCRIPTS_DIR}/bin/{/.}"
```

- **Why it's wrong:** other scripts default via `${SCRIPTS_DIR:-${HOME}/scripts}` or `: "${SCRIPTS_DIR:=${HOME}/scripts}"` (see `document-with-llm:23`, `init.sh:65`, `clangc` via `include` fallback). Here bare `${SCRIPTS_DIR}` with no default means: if user runs `c/release.sh` from fresh shell without `SCRIPTS_DIR` exported, `mkdir -p "/bin"` succeeds (already exists) and `fd.sh ... --exec mv {} "/bin/{/.}"` would attempt to move build artifacts into system `/bin` (fails without sudo, or pollutes `/bin` with sudo). Inconsistent with `typescript/release.sh:3` which uses `${SCRIPTS_DIR:-..}` fallback, and with `hooks/path.sh` which checks `[[ -n "${SCRIPTS_DIR}" ]] || return`.
- **Fix:**

```bash
: "${SCRIPTS_DIR:=${HOME}/scripts}"
mkdir -p "${SCRIPTS_DIR}/bin"
fd.sh --no-ignore -e out --exec mv {} "${SCRIPTS_DIR}/bin/{/.}"
```

Or `mkdir -p "${SCRIPTS_DIR:-${HOME}/scripts}/bin"` inline.

- **What happens:** no `set -eo pipefail`, `trap`, `source "$(include ...)"`, `checkDeps`.
- **Where:** entire file — only 3 commands, no header.
- **Why it's wrong:** diverges from `clangc` reference pattern (`set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `checkDeps`). As a filler release helper this is arguably intentional minimal wrapper, but it means `clangc --compile "$@"` failures do not abort, and `mkdir`/`fd.sh` errors are suppressed by `&>/dev/null`. Not a crash, but drift from house invariant.
- **Fix:** optional for tiny filler — either add `set -eo pipefail; trap 'exit 1' SIGUSR1` and `source "$(include "check-deps")"; checkDeps "$0"` if you want strict, or document that minimalism is intentional (fillers are exempt).

- **What happens:** `clangc --compile "$@"` result ignored — `mkdir`/`mv` run even if compilation failed.
- **Where:** `clangc --compile "$@"` followed unconditionally by `fd.sh ... mv`.
- **Why it's wrong:** stale `*.out` from previous successful build could be moved to bin even after a failed compile, giving false success. Should gate on clangc exit.
- **Fix:**

```bash
clangc --compile "$@" || exit $?
# or
clangc --compile "$@" && fd.sh --no-ignore -e out --exec mv {} "${SCRIPTS_DIR}/bin/{/.}"
```

#### Minor / style

- `&>/dev/null` on `mkdir -p` hides real errors (permission denied, disk full) — consider `mkdir -p "${SCRIPTS_DIR}/bin"` without suppression or `|| log-warning ...`.
- `fd.sh --no-ignore -e out --exec mv {} "${SCRIPTS_DIR}/bin/{/.}"` relies on fd's `{/.}` placeholder (basename without extension) — correct but assumes fd version supports it (it does since sharkdp/fd 8+); could note version requirement.
- No deps block: house brief §6 says missing DEPENDENCIES is allowed, so not flagging as bug, but for discoverability a `# - clang` / `# - fd` block would help `get-deps`.

#### Confirmed correct (potential false positives)

- Absence of `# --- SCRIPT SIGNATURE --- #` block is **allowed** per `house-style-brief.md` §6 — `get-deps` prints `x-none`, `checkDeps` returns 0; not a bug.
- Using `fd.sh --no-ignore` without explicit pattern defaults to `"."` (match all) — valid `fd.sh` usage per `load-fonts`/`ls-colors` examples; `--no-ignore -e out` correctly finds `*.out` files ignoring `.gitignore`.
- `clangc --compile "$@"` delegation with `"$@"` quoted correctly forwards caller args as separate words — not a word-splitting bug (unlike `typescript/release.sh` unquoted `$(fd.sh ...)`).
- `${SCRIPTS_DIR}/bin/{/.}` placeholder is intentional `fd.sh` + `fd` `--exec` syntax, not a shell brace expansion bug.

---

### `typescript/release.sh`

**Path:** `/home/othman/scripts/typescript/release.sh`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): none — no signature block (allowed)
**Declared dependencies:** none (no block → `x-none`)
**Verdict:** `Needs fixes`

#### Critical bugs

None found. (Word-splitting below is listed as Design rather than Critical because script still works for typical no-space filenames, but it is the closest to Critical in this batch.)

#### Design issues

- **What happens:** `for file in $(fd.sh --no-ignore -e ts)` word-splits on whitespace and globs filenames with spaces or newlines.
- **Where:**

```bash
# typescript/release.sh:5
for file in $(fd.sh --no-ignore -e ts); do
  output="$(strip-ext "${file}" ts)"
  deno compile -o "${SCRIPTS_DIR}/bin/${output}" --quiet -A "${file}" &&
    log-success "Compiled ${output} successfully!"
done
```

- **Why it's wrong:** `$(...)` unquoted in `for` header undergoes word splitting and globbing; a file `my project.ts` would be split into `my` and `project.ts`, and `strip-ext`/`deno compile` would be invoked on wrong fragments. Repo's other scripts use `mapfile -t` or `while IFS= read -r` to handle this (see `document-with-llm:186`, `load-fonts`, `ls-colors`). `fd.sh` can output paths with spaces from `typescript/` if project dirs contain them.
- **Fix:**

```bash
while IFS= read -r -d '' file; do
  output="$(strip-ext "${file}" ts)"
  deno compile -o "${SCRIPTS_DIR}/bin/${output}" --quiet -A "${file}" &&
    log-success "Compiled ${output} successfully!"
done < <(fd.sh --no-ignore -e ts --print0)
```

Or `mapfile -t files < <(fd.sh --no-ignore -e ts | sort); for file in "${files[@]}"; do ...; done`

- **What happens:** `SCRIPTS_DIR` fallback is inconsistent between `mkdir` and `deno compile` output path.
- **Where:**

```bash
# typescript/release.sh:3 vs 7
mkdir -p "${SCRIPTS_DIR:-..}/bin" &>/dev/null   # fallback ..

  deno compile -o "${SCRIPTS_DIR}/bin/${output}" --quiet -A "${file}"  # no fallback
```

- **Why it's wrong:** `mkdir` uses `${SCRIPTS_DIR:-..}` (relative `..` assuming cwd is `typescript/`), while compile output uses bare `${SCRIPTS_DIR}`. If `SCRIPTS_DIR` is unset: `mkdir` creates `../bin` (= `scripts/bin` when run from `typescript/`), but `deno compile -o "/bin/${output}"` tries to write to system `/bin` (fails without sudo). If run from repo root (`./typescript/release.sh`), `..` is parent of repo, so `mkdir` creates wrong dir `../bin` outside repo. `c/release.sh` and `document-with-llm` use `${HOME}/scripts` fallback consistently.
- **Fix:**

```bash
: "${SCRIPTS_DIR:=${HOME}/scripts}"
mkdir -p "${SCRIPTS_DIR}/bin"
deno compile -o "${SCRIPTS_DIR}/bin/${output}" ...
```

#### Minor / style

- `&>/dev/null` on `mkdir -p` hides errors as in `c/release.sh`; consider removing suppression.
- No `set -eo pipefail` / `trap` / `source "$(include ...)"` — same filler exemption as `c/release.sh`; not flagging as bug but noting drift from `clangc` reference.
- `strip-ext "${file}" ts` depends on `strip-ext` being on PATH via `hooks/path.sh`; without explicit `checkDeps` this is implicit — works when hook is sourced, but fragile if PATH not set. Could add `# - strip-ext` deps block.
- `log-success` invoked without prior `source` — relies on PATH hook; matches existing filler style.

#### Confirmed correct (potential false positives)

- Missing signature block is allowed per house-style §6 — not a bug; `get-desc`/`get-deps` gracefully handle absent block.
- `fd.sh --no-ignore -e ts` without explicit pattern is valid (pattern defaults to `.`) and `--no-ignore` correctly overrides `fd`'s gitignore filtering to find all `*.ts` including ignored `node_modules`? Actually `fd.sh` already excludes `node_modules` via its own `excludes` array (`fd.sh:27-34`), so `--no-ignore` does not re-include `node_modules` because `fd.sh` passes `--exclude node_modules` explicitly — correct layered behavior.
- `strip-ext "${file}" ts` usage matches `strip-ext` contract: `strip-ext <file> [ext1 ext2]` strips extensions via `basename -s` + `replace.sh`; second arg `"ts"` correctly strips `.ts`.
- `deno compile -o ... --quiet -A "${file}" && log-success ...` correctly only logs on success due to `&&`.
- `${SCRIPTS_DIR:-..}` fallback is not a syntax error — just inconsistent, not a shell expansion bug.

---

### `rofi/rofi-askpass`

**Path:** `/home/othman/scripts/rofi/rofi-askpass`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): none — no signature block (allowed)
**Declared dependencies:** none (no block; runtime requires `rofi`)
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **What happens:** `RASI` path derived via `dirname "$0"` fails when script is invoked via PATH (hook `hooks/path.sh` adds `rofi/` to PATH).
- **Where:**

```bash
# rofi/rofi-askpass:4
RASI="$(dirname "$0")/askpass.rasi"
```

- **Why it's wrong:** when executed as `rofi-askpass` (found via `PATH` search), `$0` is `rofi-askpass` (or `rofi/rofi-askpass` without leading dir), `dirname` yields `.`, so `RASI="./askpass.rasi"` not found — `rofi -theme` fails or falls back to default theme silently. If invoked via absolute path (`~/scripts/rofi/rofi-askpass`) it works. `include` script solves this via `realpath -m` and `dirname -- "${BASH_SOURCE[0]}"`; similar `realpath` should be used.
- **Fix:**

```bash
RASI="$(dirname -- "$(realpath -m "$0")")/askpass.rasi"
# or
RASI="$(cd -- "$(dirname -- "$0")" && pwd)/askpass.rasi"
```

- **What happens:** no existence checks for `rofi` binary or `askpass.rasi` theme file.
- **Where:** entire file — directly execs `rofi -dmenu ... -theme "${RASI}"`.
- **Why it's wrong:** if `rofi` not installed or theme missing, rofi error goes to terminal with no `log-warning`/`log-error` handling; caller (`check-deps` askpass fallback) may expect a password prompt and hang. Tiny filler so not Critical, but worth noting.
- **Fix:** optional guard:

```bash
command -v rofi &>/dev/null || { echo "rofi not found" >&2; exit 1; }
[[ -f "${RASI}" ]] || RASI=""
[[ -n "${RASI}" ]] && theme_args=(-theme "${RASI}") || theme_args=()
rofi -dmenu -password -i -p "Root" "${theme_args[@]}"
```

- **What happens:** no signature block declaring `rofi` dependency.
- **Where:** file has only `#!/usr/bin/env bash` and comments, no `# --- DEPENDENCIES --- #`.
- **Why it's wrong:** `get-deps`/`checkDeps` would report `x-none`, so `check-deps` hook never prompts to install `rofi`. Not a runtime crash but reduces discoverability; other `rofi/` scripts (`rofi-music`, `rofi-list`) likely declare it.
- **Fix:** add:

```bash
# --- DEPENDENCIES --- #
# - rofi
# --- END SIGNATURE --- #
```

#### Minor / style

- Hardcoded prompt `-p "Root"` — correct for askpass use (sudo prompt), but not parameterized; fine.
- No `set -eo pipefail`/`trap` — acceptable for 5-line UI wrapper; adding would not change behavior.
- Theme import comment `# Import Current Theme` without explaining `askpass.rasi` vs `list.rasi`/`music.rasi` — cosmetic.

#### Confirmed correct (potential false positives)

- Missing signature block is allowed per `house-style-brief.md` §6 — not flagged as bug; `get-deps` `x-none` handling is intentional.
- `rofi -dmenu -password -i -p "Root" -theme "${RASI}"` flags are correct `rofi` dmenu password mode: `-password` masks input, `-i` case-insensitive, `-p` prompt, `-theme` path — not inventing flags.
- Not sourcing `include`/`lib/helpers.sh`/`check-deps` is not a bug for this ultra-minimal UI shim — it has no `cmdarg`/`log-*` needs, unlike `clangc` reference which is a compiled-tool wrapper.
- `"${RASI}"` quoted correctly preserves spaces in path; not unquoted.

---

## Batch Summary

- **Scripts reviewed:** 4 / 4
- **Critical bugs:** `document-with-llm` — (1) change-detection cache shadowing (`if exists skip` superset kills `hash==cached` check, docs never regenerate without `--force`), (2) `claude --model "opus"` hardcoded ignoring `-m`/`--model` (and `ANTHROPIC_DEFAULT_FABLE_MODEL` typo), (3) `projectHash` hangs on empty dir via `cat` with zero args reading stdin. The three fillers have no Critical bugs.
- **Design issues worth escalating:** `document-with-llm` — commented `set -eo pipefail` loses fail-fast, `cd "${run_dir}" || exit` permanently changes cwd and kills whole batch, hash concatenation without null separators (collision-prone vs `compile.sh`), `collectContext` only first `*.ts` file; `c/release.sh` — `SCRIPTS_DIR` without fallback risks `/bin` pollution and `clangc` failure not gated; `typescript/release.sh` — `for file in $(fd.sh ...)` word splitting, `SCRIPTS_DIR` fallback inconsistency (`${SCRIPTS_DIR:-..}` vs bare); `rofi/rofi-askpass` — `dirname "$0"` fails via PATH, no `rofi` dep check.
- **Cross-cutting patterns observed in this batch** (same bug/pattern repeated across multiple scripts in this batch only; batch-level, not repo-wide):
  - `c/release.sh` and `typescript/release.sh` both omit `SCRIPTS_DIR` default fallback (vs `document-with-llm:23` and `hooks/path.sh:21` which correctly default to `${HOME}/scripts`), leading to `/bin` or `../bin` mis-targets when env var unset — same inconsistency in two fillers.
  - `c/release.sh` and `typescript/release.sh` both suppress `mkdir -p` errors via `&>/dev/null` and omit `set -eo pipefail`/`trap`/`checkDeps` — consistent minimal filler style, not a bug per se but drift from `clangc` reference; worth documenting as intentional filler exemption.
  - `c/release.sh` correctly quotes `"$@"` while `typescript/release.sh` incorrectly uses unquoted `$(fd.sh ...)` — opposite quoting hygiene in same batch shows need for `mapfile`/`read -d ''` convention.
  - `document-with-llm` reuses `fd.sh` wrapper correctly (with excludes) while fillers use raw `fd.sh --no-ignore` — both valid but show two modes of `fd.sh` (filtered vs unfiltered) worth documenting.
- **Open questions** (design intent unclear, needs the repo owner's input rather than a guess):
  - Is `document-with-llm`'s commented `# set -eo pipefail` intentional to allow LLM provider failures to continue batch, or should it be re-enabled? Current `trap` without `set -e` still kills on `log-error` but other failures are silent.
  - Should `collectContext` for typescript include all `*.ts` files or is `head -1` intentional (single entry point convention)? Projects like `mediactl` have `mediactl.ts` plus `deno.json` only, but future projects may have multiple.
  - For `c/release.sh`/`typescript/release.sh`, is `SCRIPTS_DIR` expected to always be exported via `hooks/path.sh`/`init.sh`, making fallback unnecessary, or should they defensively default to `${HOME}/scripts` like the large tool does?
  - `rofi/rofi-askpass` via PATH: should RASI be resolved via `realpath` or should `rofi-askpass.rasi` be installed to `~/.config/rofi/` and referenced absolutely?

---

## Evidence Appendix (optional)

- House style brief: `/home/othman/scripts/docs/code-reviews/house-style-brief.md:1-69`
- Core files read: `include:1-26`, `lib/cmdarg.sh:1-462`, `lib/loggers.sh:1-341`, `lib/helpers.sh:1-420`, `check-deps:1-175`, `log.sh:1-66`, `get-desc:1-53`, `get-deps:1-39`, `init.sh:1-158`, `hooks/path.sh:1-86`, `clangc:1-67`
- Batch scripts read: `document-with-llm:1-316`, `c/release.sh:1-7`, `typescript/release.sh:1-9`, `rofi/rofi-askpass:1-11`
- Supporting reads: `fd.sh:1-43`, `replace.sh:1-81`, `no-dups:1-82`, `strip-ext:1-44`, `lib/compile.sh:1-193`, `log-error:1-67`, `templates/document-with-llm/prompt.md`
- Key reproducers:
  - `printf "a\n" | cat 2>/dev/null | od -c` vs `cat` with no args blocks on tty → empty dir hang.
  - `bash -c 'MODEL="my-model"; set -- pi ${MODEL:+--model "${MODEL}"} "p"; printf "[%s]\n" "$@"'` → correctly splits, but `claude --model "opus"` hardcodes.
  - `fd . /tmp/fdtest/dir --type f` vs `fd --type f . /path` both exit 0 — trailing `--type f` after path is tolerated by fd, not a bug.
  - `for file in $(fd.sh ...)` word splitting demo: `touch "/tmp/a b.ts"; fd.sh -e ts /tmp` → `for f in $(fd ...)` splits "a" "b.ts".

