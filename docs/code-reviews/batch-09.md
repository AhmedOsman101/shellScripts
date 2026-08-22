# Batch Review: 09 of 22

**Scripts in this batch:** `git-commit` (191), `expandTilde` (32), `rustbook` (32), `font-search` (32) (4 scripts)
**Batch composition:** large+fillers — large standalone `git-commit` (191) plus 3 small fillers (`expandTilde` 32, `rustbook` 32, `font-search` 32) — pairing is incidental except git-commit vs expandTilde unrelated, cap 4, budget 287 lines.
**Reviewer:** subagent-09
**Date:** 2026-08-21

---

## House Style Reference (do not flag these as bugs)

Before reviewing, confirm you've internalized these repo conventions. Restate them here in one line each to prove the context loaded correctly:

- Dependency declaration format (`# - binary | binary2 (pkg-override)`) and how `checkDep` resolves it: deps live between `# --- DEPENDENCIES --- #` and `# --- END SIGNATURE --- #` as `# - exe | alt (pkg)`; `checkDep` splits on `|`, `Trim`s each alternative, `awk '{print $1}'`, `command -v` in order — any hit satisfies (return 0), else echoes first exe or `(parens)` package for `installDep`.
- Logging convention: `log-*` wrapper scripts are primary, camelCase `log*` functions in `lib/helpers.sh` are fallback: standalone `log-debug/info/warning/error/success` + dispatcher `log.sh` via `LEVEL_COLORS`/`LEVEL_OUTPUT`/`colorOnlyPrefix` are canonical CLI entry points; `lib/helpers.sh` `logInfo/logError/…` + `lib/loggers.sh` `printRed/hex_to_rgb/printer/stylePrint/supportsColor` (NO_COLOR/CI/TTY/TERM) are in-process fallback, not dead code, `log-success` vs `logSuccess` naming is both canonical.
- `trap 'exit 1' SIGUSR1` + `kill -SIGUSR1 "${PPID}"` propagation chain purpose: every script traps SIGUSR1 → `exit 1`; only `log-error` sends `kill -SIGUSR1 "${PPID}" &>/dev/null || true; wait` guarded by `! isInteractiveShell && ! noKill` (`--no-kill/--no-error/--safe`), propagating fatal errors up the caller chain without explicit exit-code checks.
- `cmdarg.sh` argument-parsing pattern used across scripts: `source "$(include "lib/cmdarg.sh")"` → `cmdarg_info "header" "$(get-desc "$0")"` → pre-`declare -a arr`/`declare -A hash` for `[]`/`{}` → `cmdarg "v"` boolean (`"false"`→`true`), `"m:"` required string, `"o?"` optional, `"a?[]"` array, `"H?{}"` hash → `cmdarg_parse "$@"` → read `cmdarg_cfg`/`argv`/`argc`; `-h/--help` reserved, `CMDARG_ERROR_BEHAVIOR=return`.
- `get-desc` / `get-deps` signature-block parsing rules: both `sed`-parse `# --- DESCRIPTION --- #` … `# --- DEPENDENCIES --- #` … `# --- END SIGNATURE --- #`; missing block is allowed (`get-deps` prints `x-none` and `checkDeps` returns 0, `get-desc` tolerates either terminator); extraction is `sed -n '/DEPENDENCIES/,/END SIGNATURE/{/\# - /p}'`.
- `init.sh` / `hooks/path.sh` symlink and PATH-registration workflow: `init.sh` verifies `SCRIPTS_DIR` (`~/scripts`), ensures `fd` (prompts `fdfind→fd` symlink), checks `hooks/path.sh`, idempotently appends `[[ -s "${SCRIPTS_DIR}/hooks/path.sh" ]] && source …` to `~/.bashrc`/`${ZDOTDIR:-$HOME}/.zshrc`; `hooks/path.sh` (sourced at startup, not executed) caches `fd --strip-cwd-prefix=always --no-ignore-vcs -t x . --exclude .git/.venv/...` to `/tmp/path-hook.cache`, rescans only when `find -type d -newer cache`, adds each exe dir once via `:":${PATH}:"` guard, then unsets temps.
- Reference pattern from `clangc` (what "correct" looks like in this repo): `set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `source "$(include "lib/cmdarg.sh")"` + `source "$(include "lib/compile.sh")"` + `source "$(include "check-deps")"` + `checkDeps "$0"` → `cmdarg_info "header" "$(get-desc "$0")"` → `declare -a compiler_args` before `cmdarg "a?[]"` → `cmdarg "c"`/`"o?"`/`"a?[]"`/`"q"` → `cmdarg_parse "$@"` → literal `cmdarg_cfg` reads → `((argc <1)) && log-error` → array-safe delegation via namerefs.

---

## Script Reviews

### `git-commit`

**Path:** `/home/othman/scripts/git-commit`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Adds a conventional commit message or generates one with AI
**Declared dependencies:** `git`, `rg (ripgrep)`, `gum`, `mdcat | lowdown`, `commit-sage`
**Verdict:** `Needs fixes`

#### Critical bugs

None found. — No crash-on-happy-path; staging/choice/commit flows work for the common `??` untracked case. The fragility in porcelain parsing is design (below), not a hard crash under `set -e` for the default path.

#### Design issues

- **What happens:** `git status --porcelain` parsing leaves the unstaged status character in the staged filename, so `git add "${repoPath}/${file}"` is called with `M foo` instead of `foo` and fails (or with `set -e` aborts) for the common ` M` modified-not-staged case; renames `R  old -> new` similarly produce `old -> new` rather than `new`.
- **Where:**

```bash
# git-commit:77-99
if ! git status --porcelain | rg '^[A-Z]' &>/dev/null; then
  output=$(
    git status --porcelain |
      rg -v '^[MAD]' |
      trim |
      gum choose \
        --no-limit \
        --header="Choose files to stage:" \
        --header.foreground="${U_GREEN}" \
        --select-if-one
  ) || terminate
  # Parse output to extract file names, preserving spaces
  declare -a files
  mapfile -t files < <(
    echo "${output}" |
      cut -d " " -f 2- |
      tr -d '"' |
      sed -E 's|^[?[:space:]]{3}||'
  ) || terminate
  for file in "${files[@]}"; do
    git add "${repoPath}/${file}"
  done
fi
```

- **Why it's wrong:** `git status --porcelain` format is `XY<space>path` with `XY` two-column status. `cut -d " " -f 2-` treats the status columns as space-delimited fields, so ` M foo` (space+M+space) → fields `""`, `M`, `foo` → `cut -f 2-` → `M foo`, and `sed 's|^[?[:space:]]{3}||'` only strips `?`/space (not `M`/`A`/`D`/`R`), so the `M` prefix survives. `trim` (default `" "` strip) also does not remove `M`. For renames `R  old -> new`, result is `old -> new` (not just `new`). `git add` then fails with `pathspec 'M foo' did not match`.
- **Fix:** use the standard 3-char strip plus proper rename handling; also prefer `argv`-style quoting and avoid `repoPath` prefix when `git status` is already cwd-relative:

```bash
mapfile -t files < <(
  printf '%s\n' "${output}" |
    sed -E 's/^.{3}//' |
    sed -E 's/^"//; s/"$//' |
    # for renames, keep destination: "old -> new" → "new"
    sed -E 's/.* -> //'
)
for file in "${files[@]}"; do
  [[ -z "${file}" ]] && continue
  git add -- "${file}"
done
# or git add -- "${repoPath}/${file}" only if file is repo-relative; prefer plain "${file}"
```

- **What happens:** `cleanup()` is installed as `trap 'cleanup' EXIT` but references `SPINNER_PID` and `logFile` which are only defined inside the `if "${useAi}"` branch; on early `terminate "Nothing to commit"` or on non-AI paths the trap calls `killwait ""` and `rm -f ""` (harmless under `set -e` as `rm -f ""` returns 0) but is noisy and `killwait` is an internal repo script whose PATH availability depends on `hooks/path.sh` hook state.
- **Where:**

```bash
# git-commit:66-76
declare -a files
cleanup() {
  killwait "${SPINNER_PID}"
  rm -f "${logFile}"
}
trap 'cleanup' EXIT
[[ -z "$(git status --porcelain)" ]] && terminate "Nothing to commit"
# ...
if "${useAi}"; then
  logFile="$(mktemp -t commit-sage-XXXXX.log)"
  spinner.sh 1>&2 &
  SPINNER_PID=$!
```

- **Why it's wrong:** EXIT trap runs on every exit, including `terminate` (which is `logInfo + exit 0`). With no guard, `killwait` is invoked with empty arg; `killwait:16-20` does `kill "" 2>/dev/null || true; wait "" 2>/dev/null || true` so it survives, but the intent is unclear and `SPINNER_PID` is unbound until the spinner is started. The trap also overwrites the process-wide EXIT handling without restoring previous state; `rm -f` with empty string is a no-op in this repo’s `rm` but semantically fragile.
- **Fix:** guard the cleanup:

```bash
cleanup() {
  [[ -n "${SPINNER_PID:-}" ]] && killwait "${SPINNER_PID}" 2>/dev/null || true
  [[ -n "${logFile:-}" ]] && rm -f "${logFile}" 2>/dev/null || true
}
# or initialise at top:
SPINNER_PID=""; logFile=""
```

- **What happens:** `details` in non-edit AI-off path is produced without `|| terminate` guard while `type` and `details=$(gum write…)` have guards; cancelling `gum input` leaves `summary` empty but script continues to `git commit -m "" -m ""`.
- **Where:**

```bash
# git-commit:138-148
    summary=$(
      gum input \
        --value "${type}: " \
        --placeholder "Summary of this change"
    )
    details=$(gum write --placeholder "Details of this change") || terminate
```

- **Why it's wrong:** `gum input` returns non-zero on Esc/Ctrl-C; without `|| terminate` the empty `summary` flows into commit preview and `git commit -m ""` (git then errors via `log-error "Commit failed!"` but the preview already rendered).
- **Fix:**

```bash
    summary=$(
      gum input --value "${type}: " --placeholder "Summary of this change"
    ) || terminate
```

- **What happens:** variable `local` shadows the `local` builtin; declared at top level as `local="${cmdarg_cfg['local']}"` then used as `if ! "${local}" && [[ -n "$(git remote -v)" ]]`.
- **Where:**

```bash
# git-commit:43-46,178
local="${cmdarg_cfg['local']}"
push="${cmdarg_cfg['push']}"
# ...
if ! "${local}" && [[ -n "$(git remote -v)" ]]; then
```

- **Why it's wrong:** not a runtime crash (`local=val` at top level is a plain assignment, not `local var` declaration, so bash allows it; `"false"`/`"true"` boolean trick (`if ! false` → true, `if ! true` → false) makes `! "${local}"` correctly mean "not --local"), but it shadows the builtin, confuses `shellcheck SC2164` and readers, and risks `local: can only be used in a function` if ever refactored to `local local=…` inside a function. `cmdarg` booleans are canonical as bare `if ${cfg['x']}; then`, not `local`.
- **Fix:** rename:

```bash
isLocal="${cmdarg_cfg['local']}"
# ...
if ! "${isLocal}" && [[ -n "$(git remote -v)" ]]; then
```

#### Minor / style

- `choices` array re-declared via `declare -a files` twice (line 66 top-level and line 91 inside `if` block) — redundant redeclaration in the same scope; second `declare -a files` is unnecessary (`files=()` would clear).
- `detail` parsing `details="$(tail -n +2 "${logFile}")"` retains `\r` from Windows line endings while `summary` is stripped with `${summary//$'\r'/}` — for consistency also strip `details`: `details="$(tail -n +2 "${logFile}" | tr -d '\r')"`.
- `git add "${repoPath}/${file}"` assumes `git status --porcelain` paths are repo-relative; `git status` actually emits cwd-relative paths, so `repoPath/` prefix duplicates when already at repo root (still works due to `realpath` tolerance) and breaks in subdirectories. Prefer `git add -- "${file}"` or resolve via `git rev-parse --show-prefix`.
- `spinner.sh 1>&2 &` + `SPINNER_PID=$!` is correct capture but no `shellcheck disable` comment; not a bug.
- `mdcat | lowdown` dependency uses `command -v mdcat &>/dev/null` fallback correctly (house §2), but `commit-sage generate >"${logFile}" 2>&1` channel mixes stdout/stderr into one log; `sed 's|\[ERROR\] ||'` cleanup is correct for `[ERROR]` lines.

#### Confirmed correct (potential false positives)

- `set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `source "$(include "lib/cmdarg.sh")"` + `source "$(include "lib/helpers.sh")"` + `source "$(include "check-deps")"` + `checkDeps "$0"` → `cmdarg_info` → `cmdarg "a"/"y"/"l"/"p"/"e"` → `cmdarg_parse "$@"` order matches `clangc:21-38` reference.
- `if "${useAi}"; then` / `if "${noConfirm}"; then` / `if ! "${local}"; then` boolean checks via literal `true`/`false` commands are canonical `cmdarg.sh` booleans per brief §5, not missing quotes.
- `trap 'exit 1' SIGUSR1` without a matching `kill` in this file is correct per brief §4 — only `log-error` sends `kill -SIGUSR1 "${PPID}"`; trap is for when this script is the parent.
- `trap 'cleanup' EXIT` coexisting with `trap 'exit 1' SIGUSR1` is correct — they trap different signals (EXIT vs SIGUSR1), not an overwrite.
- `is-git-repo`, `git-root`, `git_current_branch`, `killwait`, `spinner.sh`, `trim` not listed in `# --- DEPENDENCIES --- #` is correct — they are internal repo scripts exposed via `hooks/path.sh` PATH hook (brief §7), not external packages for `checkDep`/`installDep` (same rationale as `oc-manager` `trim`/`killwait` not being deps).
- `# - mdcat | lowdown` pipe is correct `checkDep` syntax per brief §2 (any alternative satisfies).
- `terminate "Nothing to commit"` via `lib/helpers.sh:61-65` (`logInfo + exit 0`) is intentional; error-path `log-error` vs info-path `terminate` distinction is correct.
- `logFile="$(mktemp -t commit-sage-XXXXX.log)"` correctly uses `mktemp`; `read -r summary <"${logFile}"` reading first line as subject matches `commit-sage` contract.

---

### `expandTilde`

**Path:** `/home/othman/scripts/expandTilde`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Exapnds a tilde ~ to the HOME directory
**Declared dependencies:** `sed`
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **What happens:** tilde expansion via `sed "s|^~|${HOME}|"` mishandles `HOME` values containing `&` or `\` (sed replacement meta-characters); e.g. `HOME=/home/a&b` → `~` expands to `/home/a~b` (`&` expands to the matched pattern).
- **Where:**

```bash
# expandTilde:32
sed "s|^~|${HOME}|" < <(input "$@")
```

- **Why it's wrong:** `&` in the replacement means "the whole match" (`~`), `\N` means backreference. `HOME` is not escaped, so any `&` or `\` corrupts output. `|` as delimiter protects `/` but not `&`/`\`. Edge case (rare for `$HOME`, but required for correctness).
- **Fix:** escape `HOME` for sed or avoid sed entirely (prefer bash prefix replacement):

```bash
# escape & and \ and | for sed
homeEsc=${HOME//\\/\\\\}; homeEsc=${homeEsc//&/\\&}; homeEsc=${homeEsc//|/\\|}
sed "s|^~|${homeEsc}|" < <(input "$@")
# — or simplest, pure bash (no sed needed):
str="$(input "$@")"; [[ "${str}" == "~"* ]] && printf '%s\n' "${HOME}${str:1}" || printf '%s\n' "${str}"
```

#### Minor / style

- Uses `input "$@"` (helpers `input:21-32` reads stdin or `"$*"`) after `cmdarg_parse "$@"`; canonical pattern post-`cmdarg_parse` is to read `argv`/`argc` (`"${argv[@]}"` / `input "${argv[@]}"`), not the original `"$@"` (which still holds the original args because `cmdarg_parse` shifts only its function-local copy). For this script (no flags defined) they coincide, but it diverges from `clangc` which iterates `"${argv[@]}"`. Prefer `input "${argv[@]}"` or `printf '%s\n' "${argv[*]}"` etc.
- Declared dependency `# - sed` is unnecessary — `sed` is a coreutils-adjacent baseline utility excluded per `AGENTS.md` dependency-declaration rules (exclude `grep/sed/awk/cut/tr/cat/echo`); not harmful, just noise.
- `# --- DESCRIPTION --- #` typo `Exapnds` — cosmetic.

#### Confirmed correct (potential false positives)

- `set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `source "$(include "lib/cmdarg.sh")"` + `source "$(include "lib/helpers.sh")"` + `source "$(include "check-deps")"` + `checkDeps "$0"` + `cmdarg_info "header" "$(get-desc "$0")"` + `cmdarg_parse "$@"` matches minimal `clangc` preamble; no boolean flags needed so no `declare -a` required.
- `source "$(include "lib/cmdarg.sh")"` before `check-deps` and `checkDeps "$0"` immediately after sourcing is per `clangc` reference (brief §8 says `lib/cmdarg.sh` + `lib/compile.sh` + `check-deps` + `checkDeps` in that order).
- `include` indirection `source "$(include "lib/helpers.sh")"` via `realpath -m` + `[[ -f ]] && echo` (include:24-26) is intentional, not fragile (brief §1).
- `sed` with `|` delimiter correctly protects `/` in `$HOME`; style is consistent with `trim:24` etc.
- No missing `DEPENDENCIES` handling needed — `checkDeps` with single `sed` line will `return 0` after `command -v sed` (brief §2).

---

### `rustbook`

**Path:** `/home/othman/scripts/rustbook`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Launch the rust book using vite
**Declared dependencies:** `vite`
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **What happens:** hard-coded toolchain path `stable-x86_64-unknown-linux-gnu` makes the script fail on `aarch64`, `stable-x86_64-unknown-linux-gnu` host-triple changes, or custom `rustup` installs (`~/.rustup` vs `~/.local/share/rustup`); also hard-coded vite config path `${HOME}/.config/vite/vite.config.js` assumes a user-maintained config that may not exist.
- **Where:**

```bash
# rustbook:30-32
cd "${HOME}/.local/share/rustup/toolchains/stable-x86_64-unknown-linux-gnu/share/doc/rust/html/book" || log-error "Cannot find the book"
vite --config "${HOME}/.config/vite/vite.config.js" --port 9001 --open
```

- **Why it's wrong:** `rustup` default home is `~/.rustup`, not `~/.local/share/rustup` (the latter is `~/.local/share/rustup` only when `RUSTUP_HOME` is set); host triple varies by arch. The script could discover the book via `rustup show home` or `rustup doc --book` or `find "${RUSTUP_HOME:-${HOME}/.rustup}/toolchains" -path "*/share/doc/rust/html/book" -type d -print -quit`. `vite` config flag is unnecessary if project has no `vite` config — `vite --port 9001 --open` already serves the static `book` directory with no config.
- **Fix:**

```bash
rustupHome="${RUSTUP_HOME:-${HOME}/.rustup}"
# prefer rustup's own discovery
bookDir="$(find "${rustupHome}/toolchains" -path "*/share/doc/rust/html/book" -type d -print -quit 2>/dev/null)"
bookDir="${bookDir:-${HOME}/.local/share/rustup/toolchains/stable-x86_64-unknown-linux-gnu/share/doc/rust/html/book}"
[[ -d "${bookDir}" ]] || log-error "Cannot find the book (checked ${bookDir})"
cd "${bookDir}" || log-error "Cannot find the book"
if [[ -f "${HOME}/.config/vite/vite.config.js" ]]; then
  vite --config "${HOME}/.config/vite/vite.config.js" --port 9001 --open
else
  vite --port 9001 --open
fi
```

- **What happens:** `vite` as a `DEPENDENCIES` entry will be treated by `checkDep` → `getPackageManager` as a system package (`apt/pacman/dnf` etc.), but `vite` is an npm binary (installed via `npm i -g vite` or `npx vite`), not a distro package; `checkDeps` install prompt will mis-suggest `sudo apt install vite` (wrong package).
- **Where:**

```bash
# rustbook:16-17
# --- DEPENDENCIES --- #
# - vite
```

- **Why it's wrong:** `check-deps:86-208` `getPackageManager` only knows distro managers, not npm. This is a pre-existing repo limitation, not script-specific, but declaring `vite` as a system dep will fail to install on most hosts. Same issue in other `npm:`-style tools (e.g. `vite` via `deno`/`npm:emoji-regex` elsewhere).
- **Fix:** either declare as `# - vite (vite)` if a distro `vite` package exists (not on Arch/Debian), or more usefully add a comment/guard: `command -v vite &>/dev/null || log-error "vite not found (install: npm i -g vite)"` and keep `# - vite` as documentation without expecting auto-install, or install via `npm` in `installDep` (out of scope for this batch, document as known limitation).

- **What happens:** script declares no positional/flag handling but allows arbitrary extra args to be silently ignored; `argc >0` is not validated.
- **Where:** `rustbook:27-28` (`cmdarg_parse "$@"` with no `cmdarg` definitions)
- **Why it's wrong:** per `clangc:44` reference, scripts should validate `((argc ==0))` or warn on extra args; bare `cmdarg_parse` with no definitions correctly rejects `-x` flags as unknown but silently accepts bare positional `rustbook foo` (treated as `argv[0]` unused). Low severity for a no-arg launcher but diverges from `get-desc`/`get-deps` which explicitly check `argc`.
- **Fix:** add `((argc == 0)) || log-error "rustbook takes no arguments"` after `cmdarg_parse`.

#### Minor / style

- `source "$(include "check-deps")"` without `source "$(include "lib/helpers.sh")"` is fine — `check-deps:18` sources `helpers` transitively, but explicit `lib/helpers.sh` sourcing (as in `expandTilde`/`git-commit`) is more readable; keep as-is or add for consistency with `clangc`.
- `set -eo pipefail` + `trap 'exit 1' SIGUSR1` present even though no pipeline fails except `cd`; still correct per house style (every script traps).

#### Confirmed correct (potential false positives)

- `set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `source "$(include "lib/cmdarg.sh")"` + `source "$(include "check-deps")"` + `checkDeps "$0"` + `cmdarg_info` + `cmdarg_parse` minimal preamble is the canonical zero-arg pattern (cf. `get-desc:20-28` with same sources).
- `cd "${dir}" || log-error "Cannot find the book"` propagation via `log-error` → `kill -SIGUSR1 "${PPID}"` → `trap 'exit 1'` is correct per brief §4 (only `log-error` kills).
- `vite --config … --port 9001 --open` arg forwarding is correct; `vite` being on PATH via `hooks/path.sh` (if locally installed) is covered by brief §7 (scripts do not handle own PATH).
- Missing `DESCRIPTION`/`DEPENDENCIES` terminator handling via `get-desc` tolerating either `DEPENDENCIES` or `END SIGNATURE` is per brief §6, but here both sections are present and correctly terminated.

---

### `font-search`

**Path:** `/home/othman/scripts/font-search`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Searches for a font in the list of installed fonts
**Declared dependencies:** `rg (ripgrep)`
**Verdict:** `Minor issues`

#### Critical bugs

None found. — Pipeline + `rg` exit path works for the happy-path single-quoted font name; unquoted multi-word pattern misbehavior is design, not crash.

#### Design issues

- **What happens:** `rg` is invoked as `rg -i "${argv[@]}"`; with multiple positional words (e.g. `font-search Fira Code` without quotes, `argv=(Fira Code)` length 2) this becomes `rg -i Fira Code` where `Code` is interpreted as a file path to search, not as part of the pattern, yielding `Code: No such file or directory` or only matching `Fira`.
- **Where:**

```bash
# font-search:30-32
fc-list |
  awk -F ':' '{print $2}' |
  rg -i "${argv[@]}" || log-error "Font '${argv[*]}' was not found"
```

- **Why it's wrong:** `fc-list | awk` pipeline already filters to family names; `rg` expects a single pattern. Expanding `argv` as multiple args splits the pattern. Canonical `cmdarg` handling for a free-text query is to join positionals: `"${argv[*]}"` (space-joined) or `"$*"` after `cmdarg_parse`. Error message correctly uses `"${argv[*]}"` joined, but the search does not.
- **Fix:**

```bash
pattern="${argv[*]}"
[[ -n "${pattern}" ]] || log-error "No font name given"
fc-list |
  awk -F ':' '{print $2}' |
  rg -i -- "${pattern}" || log-error "Font '${pattern}' was not found"
```

- **What happens:** no guard for empty `argv`; `rg -i` with no pattern errors (`rg: no pattern`) and is mapped to the same `log-error "Font '' was not found"` rather than a usage message. Also `fc-list` failure (missing `fontconfig`) is masked as "font not found".
- **Where:** same `30-32` pipeline with `set -eo pipefail`.
- **Why it's wrong:** `set -o pipefail` means any stage failure (including `fc-list` not found) returns non-zero and triggers the generic `log-error`. `fc-list` is from `fontconfig` and `awk` from `gawk` — neither is declared in `DEPENDENCIES`, so `checkDeps` cannot prompt to install, and the error is misleading.
- **Fix:** declare deps and guard:

```bash
# --- DEPENDENCIES --- #
# - rg (ripgrep)
# - fc-list (fontconfig)
# --- END SIGNATURE --- #
# and in logic:
((argc >= 1)) || log-error "Usage: font-search <font name>"
```

- **What happens:** `rg` pattern starting with `-` (e.g. `font-search "-foo"`) is parsed as a flag.
- **Where:** `rg -i "${argv[@]}"` without `--`.
- **Why it's wrong:** ripgrep follows GNU flag parsing; font names starting with `-` would be options.
- **Fix:** add `--` sentinel: `rg -i -- "${pattern}"`.

#### Minor / style

- `awk -F ':' '{print $2}'` picks the second field (family list) but `fc-list` format is `file : family,family : style`; families are comma-separated and have a leading space/tab — consider `awk -F ':' '{print $2}' | tr ',' '\n' | sed 's/^ *//'` for per-family search, or `fc-list : family` to query directly. Current behavior is acceptable for simple substring match but may match across comma boundaries.
- Dependencies list omits `fc-list` (`fontconfig`) and `awk`/`fc-list` is not coreutils; per `AGENTS.md` `awk` is not excluded (only `grep/sed/awk/cut/tr/cat/echo` are "basic commands" but `checkDep` can still list them if desired). For this batch we flag `fc-list` only, as `awk` is universally available; not requiring `awk` dep is acceptable.

#### Confirmed correct (potential false positives)

- `set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `source "$(include "lib/cmdarg.sh")"` + `source "$(include "check-deps")"` + `checkDeps "$0"` + `cmdarg_info "header" "$(get-desc "$0")"` + `cmdarg_parse "$@"` matches minimal `rustbook`/`font-search` pattern; no pre-`declare -a` needed as no `[]`/`{}` flags are used (brief §5 requires `declare` only for array/hash types).
- `rg (ripgrep)` declaration with ` (ripgrep)` package override is correct `checkDep` syntax per brief §2 (bare `rg` → package `ripgrep` on Debian).
- `rg -i` case-insensitive search is correct for font names; `log-error "Font '…' was not found"` after `||` correctly maps non-zero `rg` (no match under `pipefail`) to a user-visible error via SIGUSR1 chain.
- `include` indirection and `trap 'exit 1' SIGUSR1` without local `kill` are correct per brief §1/§4.

---

## Batch Summary

- **Scripts reviewed:** 4 / 4
- **Critical bugs:** None in this batch. Closest to critical is `git-commit` porcelain parsing (design, not hard crash) which causes `git add "M foo"` for ` M` unstaged files — no data loss under `set -e` but staging fails for the common modified-not-staged case.
- **Design issues worth escalating:** `git-commit` — porcelain `cut -d " " -f 2-` + `sed 's|^[? ]{3}||'` leaves `M` prefix on ` M` lines and mishandles rename `old -> new` destination; `cleanup` EXIT trap with unguarded `SPINNER_PID`/`logFile`; missing `|| terminate` on `gum input` for `summary`; `local` shadowing builtin. `expandTilde` — `sed "s|^~|${HOME}|"` with unescaped `&`/`\` in `$HOME`. `rustbook` — hard-coded `stable-x86_64-unknown-linux-gnu` + `~/.local/share/rustup` path not portable, hard-coded vite config, `vite` not a distro package for `checkDeps`, no `argc` validation. `font-search` — `rg -i "${argv[@]}"` multi-arg mis-expansion (should be `"${argv[*]}"`), missing `fc-list (fontconfig)` dep and `--` sentinel, no empty-argv guard (plus `pipefail` masking `fc-list` failures).
- **Cross-cutting patterns observed in this batch** (same bug/pattern repeated across multiple scripts in this batch only; batch-level, not repo-wide):
  - No batch-wide repeated bug — each script is a distinct family (large interactive `git-commit` vs single-line `expandTilde`/`rustbook`/`font-search` pipes). The only shared pattern is the consistent use of the `clangc` preamble (`set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `include` + `checkDeps` + `cmdarg_info/parse`) across all 4, which is correct.
  - `git-commit` and `font-search` both join/split `argv` incorrectly but for opposite reasons: `git-commit`'s `cut` mishandles porcelain’s `XY` prefix while `font-search`'s `rg "${argv[@]}"` splits a free-text pattern — both are instances of positional-arg joining, but root causes differ (format-specific parsing vs `rg` argv expansion). Worth fixing together for `argv[*]` vs `argv[@]` hygiene.
  - `expandTilde` and `font-search` both pipe `input`/`fc-list` into a filter (`sed`/`rg`) that is also a declared dep — `expandTilde` correctly declares `sed` (though excluded per AGENTS.md) while `font-search` omits `fc-list`; the inconsistency is not a shared bug, just small filler variance.
- **Open questions** (design intent unclear, needs the repo owner's input rather than a guess):
  - `git-commit` staging: should `gum choose` offer only untracked (`??`) files or also modified (` M`) / deleted (` D`) unstaged files? Current `rg -v '^[MAD]'` excludes staged `M/A/D` but includes ` M` — is the `M` prefix bug intentional to avoid offering staged files, or should the filter be `rg '^( \?| \?| M| D)'` style?
  - `git-commit` `repoPath` prefix: is `git add "${repoPath}/${file}"` intended to support running `git-commit` from a subdirectory (repo-relative), or should it be `git add -- "${file}"` cwd-relative? `git-root` already exists for discovery but `repoPath/` prefixing may be best-effort legacy.
  - `expandTilde` scope: should it handle `~user/path` expansion (via `eval` or `getent passwd`) or only leading `~/` / bare `~` as documented?
  - `rustbook` path discovery: should it prefer `rustup doc --book` (opens in `xdg-open`) vs custom `vite` serving, and is `~/.config/vite/vite.config.js` user global config or should it be `book` directory local?
  - `font-search` output field: `awk -F ':' '{print $2}'` returns comma-joined families (e.g. `Fira Code,Fira Code Light`); should search be per-family (`tr ',' '\n'`) or substring across the raw `fc-list : family` output?

---

## Evidence Appendix (optional)

- House style brief: `/home/othman/scripts/docs/code-reviews/house-style-brief.md:1-68`
- Core files read: `include:1-26`, `lib/cmdarg.sh:1-462`, `lib/loggers.sh:1-341`, `lib/helpers.sh:1-420`, `check-deps:1-175`, `log.sh:1-66`, `get-desc:1-53`, `get-deps:1-39`, `init.sh:1-158`, `hooks/path.sh:1-86`, `clangc:1-67`
- Batch scripts read: `git-commit:1-191`, `expandTilde:1-32`, `rustbook:1-32`, `font-search:1-32`
- Supporting reads: `killwait:1-27`, `is-git-repo:1-39`, `git-root:1-30`, `git_current_branch:1-28`, `spinner.sh:1-86`, `trim:1-57` (via grep), previous batch `batch-05.md:1-410` template reference
- Verification: `grep -R "killwait|spinner.sh|is-git-repo|git-root|trim" /home/othman/scripts --exclude-dir=bin --exclude-dir=.git` confirmed internal helpers exposed via `hooks/path.sh`; `bash -c 'rm -f ""; echo $?'` confirmed `rm -f ""` returns 0 (not a crash); `HOME=/home/a\&b bash -c 'sed s|...'` reproduced `&` replacement bug; `echo '?? "a b.txt"' | cut -d " " -f2-` vs `echo ' M foo' | cut -d " " -f2-` reproduced `M` prefix survival; `echo -e "a\nb" | rg -i Foo Bar` reproduced `rg` multi-arg file error.
