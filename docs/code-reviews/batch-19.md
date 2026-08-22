# Batch Review: 19 of 22

**Scripts in this batch:** vercel-status, gitsync, install-ext-online, mkconf, watch.sh, trim, tuckr-sync, install-ext, unsetenv, toggleKB
**Batch composition:** grab-bag — 10 scripts, 654 lines total, under 12-file cap, max vercel-status 118 lines. No single family; mix of vercel, gitsync, install-ext family (install-ext / install-ext-online), file/watch tooling (watch.sh, trim), tuckr family (mkconf, tuckr-sync), and small wrappers (unsetenv, toggleKB) as noted in header.
**Reviewer:** subagent-19
**Date:** 2026-08-21

---

## House Style Reference (do not flag these as bugs)

Before reviewing, confirm you've internalized these repo conventions. Restate them here in one line each to prove the context loaded correctly:

- Dependency declaration format (`# - binary | binary2 (pkg-override)`) and how `checkDep` resolves it: deps between `# --- DEPENDENCIES --- #` / `# --- END SIGNATURE --- #` as `# - exe | alt (pkg)`, `checkDep` splits on `|`, `Trim`s, tests `command -v` per bare exe and returns 0 if any exists, else echoes first exe or parenthesized pkg override for `installDep`.
- Logging convention: `log-*` wrapper scripts are primary, camelCase `log*` functions in `lib/helpers.sh` are fallback: standalone `log-debug`/`log-info`/etc. via `log.sh` dispatcher are what repo scripts call; `lib/helpers.sh` `logDebug`/`logSuccess` etc. and `lib/loggers.sh` `printRed`/`colorOnlyPrefix` are the in-process fallback layer, not dead code.
- `trap 'exit 1' SIGUSR1` + `kill -SIGUSR1 "${PPID}"` propagation chain purpose: every script sets `trap 'exit 1' SIGUSR1`; only `log-error` sends `kill -SIGUSR1 $PPID` (guarded by `isInteractiveShell`/`--no-kill`/`--safe`) to kill the parent without exit-code checks.
- `cmdarg.sh` argument-parsing pattern used across scripts: `source "$(include "lib/cmdarg.sh")"` → pre-declare `[]`/`{}` arrays, `cmdarg_info` + `cmdarg "v"`/`"m:"`/`"o?"`/`"a?[]"`/`"H?{}"` (`:` required, `?` optional) → `cmdarg_parse "$@"` → read `cmdarg_cfg`/`argv`/`argc`; booleans are literal `true`/`false` commands, `-h/--help` reserved.
- `get-desc` / `get-deps` signature-block parsing rules: both `sed -n` the `# --- DESCRIPTION --- #`→`# --- DEPENDENCIES --- #`/`# --- END SIGNATURE --- #` and `# --- DEPENDENCIES --- #`→`# --- END SIGNATURE --- #` blocks (extracting `# - ` lines, `x-none` if absent); missing DESCRIPTION or empty DEPENDENCIES block is allowed.
- `init.sh` / `hooks/path.sh` symlink and PATH-registration workflow: `init.sh` verifies `SCRIPTS_DIR`, ensures `fd`/`fdfind` symlink, idempotently appends sourcing `hooks/path.sh` to `~/.bashrc`/`~/.zshrc`; `hooks/path.sh` (sourced, not executed) caches executable dirs via `fd -t x` to `/tmp/path-hook.cache` and appends each to `PATH` once, rescanning only when dirs newer than cache.
- Reference pattern from `clangc` (what "correct" looks like in this repo): `set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `source "$(include "lib/cmdarg.sh")"` + `source "$(include "lib/compile.sh")"` + `source "$(include "check-deps")"` + `checkDeps "$0"` → `cmdarg_info "$(get-desc "$0")"` → pre-`declare -a` → `cmdarg` defs → `cmdarg_parse "$@"` → `cmdarg_cfg` reads → `((argc<1)) && log-error` validation → safe array handling with namerefs.

---

## Script Reviews

### `vercel-status`

**Path:** `/home/othman/scripts/vercel-status`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Shows the latest n deployments on Vercel
**Declared dependencies:** curl, jq, gum, nu (nushell)
**Verdict:** `Needs fixes`

#### Critical bugs

- **What happens:** Nushell invocation breaks (or injects code) when any Vercel field contains a single quote; `projectName`, `username`, or ANSI-laden `status` interpolated inside single quotes yields a syntax error or code injection inside `nu`.
- **Where:**

```bash
# vercel-status:107,110
n "echo '${arr}' | from json | update Status { |row| \$row.Status | str replace -a '\e' (char -u '001b') } | ansi link Url --text 'Inspect' | table --index false --expand"
n "echo '${arr}' | from json | update Status { |row| \$row.Status | str replace -a '\e' (char -u '001b') } | ansi link Url --text 'Inspect' | table --expand"
```

- **Why it's wrong:** `arr` is JSON containing user-controlled strings; `echo '${arr}'` inside `n "..."` expands `${arr}` then wraps it in single quotes for `nu` to parse. A `'` inside `arr` terminates the quoting: `echo '{"Project Name":"a'b"}'` → nu parse error. Should pass via stdin or `printenv arr | n "... --stdin"` or use `jq -R`/`--arg` style to avoid shell interpolation.
- **Fix:**

```bash
# Pass via pipe/arg instead of interpolating into single quotes
printf '%s' "${arr}" | n "from json | update Status { |row| \$row.Status | str replace -a '\e' (char -u '001b') } | ansi link Url --text 'Inspect' | table --index false --expand"
# or use nu's --arg if available; at minimum escape single quotes:
# safeArr=${arr//\'/\'\\\'\'}
```

#### Design issues

- **What happens:** Three external commands used without being declared, so `checkDeps` never prompts to install them; script fails under `set -e` with `command not found`.
- **Where:**

```bash
# vercel-status:45
AUTH_HEADER="Authorization: Bearer $(pass show vercel/token)"
# vercel-status:59
age=$(sec2time $((now - (readyAt / 1000))) --short | awk '{print $1}')
# vercel-status:64
status=$(echo "${record}" | jq -r '.state' | trim)
# vercel-status:107,110 (also mismatched name)
n "echo '${arr}' | from json | ..."
```

- **Why it's wrong:** Declared deps are `curl jq gum nu`, but script also requires `pass` (secret), `sec2time` (repo helper), `trim` (repo script), and invokes `n` while declaring `nu`. `checkDep` checks `command -v nu`, but runtime calls `n`; if only `nu` is on PATH and `n` is not symlinked, invocation fails despite dep check passing.
- **Fix:** Add missing deps to signature (`pass`, `sec2time`, `trim`) and align declared vs invoked nushell name: either `# - n (nushell) | nu (nushell)` or call `nu` not `n`; or ensure `n` wrapper exists and declare `# - n`.

- **What happens:** `limit` accepted from `cmdarg "l?"` with default `"1"` but never validated; non-numeric or negative value causes arithmetic error or silent no-op.
- **Where:**

```bash
# vercel-status:34,38,84
cmdarg "l?" "limit" "Limit the number of deployments to show, defaults to the latest deployment" "1"
limit=${cmdarg_cfg['limit']}
if ((limit > 0)); then
```

- **Why it's wrong:** `isPositiveInt` from `lib/helpers.sh` is not called. `limit="abc"` → `((limit > 0))` → bash arithmetic error `value too great for base` → `set -e` exits without `log-error` message. `limit="-1"` silently falls to `log-warning` branch.
- **Fix:**

```bash
limit=${cmdarg_cfg['limit']}
isPositiveInt "${limit}" || log-error "Limit must be a positive integer (got '${limit}')"
```

- **What happens:** `curl -sH` failure is hidden behind `gum spin`; API errors produce invalid `response` JSON, then `jq ".deployments[${i}]"` returns `null` per-iteration only after a warning, and final `log-error "No deployment data processed"` masks the root HTTP error.
- **Where:**

```bash
# vercel-status:47-51
response=$(
  gum spin \
    --title "Fetching..." \
    -- curl -sH "${AUTH_HEADER}" "https://api.vercel.com/v6/deployments?limit=${limit}"
)
```

- **Why it's wrong:** `curl -s` without `-f`/`--fail` returns 0 on HTTP 401/429; no status check, no `jq -e` validation of `.deployments` existence before loop. Empty/invalid token yields misleading "No deployments found at index 0".
- **Fix:** Use `curl -fsSL` or check `echo "${response}" | jq -e '.deployments' >/dev/null || log-error "Vercel API error: $(echo "${response}" | jq -r '.error.message // .')"` before loop; also propagate curl failures through `gum spin --` correctly.

#### Minor / style

- `parseJson()` leaks globals (`readyAt`, `age`, `projectName`, `inspectorUrl`, `username`, `status`) without `local`; will clobber similarly named locals in caller if refactored. Add `local` for each.
- `response` expanded unquoted inside `echo "${response}" | jq` is quoted here (correct), but `jq ".deployments[${i}]"` interpolates `i` without `--argjson`; safe because `i` is integer, but `--argjson idx "$i"` + `jq '.deployments[$idx]'` is more robust.
- `source` order: `helpers.sh` before `cmdarg.sh` before `check-deps` differs from `clangc` canonical (`cmdarg.sh` then `check-deps`); library layer itself (§3) makes order non-fatal but document divergence.

#### Confirmed correct (potential false positives)

- `set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `checkDeps "$0"` before `cmdarg_info`: matches house §4/§8 canonical.
- `cmdarg "l?" "limit" "..." "1"` optional string with default: house §5 `?` + default correctly makes optional string; use of `${cmdarg_cfg['limit']}` literal correct.
- `log-warning` inside loop for `null` deployments then `continue`: intentional per-iteration skip, not a silent failure.
- `printMagenta -n '●'` etc. for `QUEUED`/`BUILDING` etc.: correct use of `lib/loggers.sh` color helpers (§3).

---

### `gitsync`

**Path:** `/home/othman/scripts/gitsync`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Automates adding, committing with a timestamp, and pushing changes to a Git repository
**Declared dependencies:** git, gum
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **What happens:** External helpers `is-git-repo`, `git_current_branch`, `switch-branch`, `now` invoked without declaration or `command -v` guard; if `hooks/path.sh` not sourced or helper script renamed, script fails with `command not found` under `set -e`.
- **Where:**

```bash
# gitsync:39,45,53,67,70
is-git-repo
currentBranch="$(git_current_branch)"
if switch-branch "${branch}" &>/dev/null; then
msg="${msg} $(now)"
msg="Updated Files $(now)"
```

- **Why it's wrong:** Declared deps list only `git`/`gum`; repo helpers are not in DEPENDENCIES but rely on `hooks/path.sh` PATH injection (house §7). For auditability/checkDeps prompting, any non-builtin should be listed or guarded. Low severity on sourced interactive shell, but fragile in CI/`bash -c`.
- **Fix:** Document as repo-internal or add to DEPENDENCIES (e.g., `# - is-git-repo` if wrapper exists) and guard: `command -v now &>/dev/null || log-error "now helper not on PATH"`.

- **What happens:** Commit message may be empty if user aborts `gum write` (Ctrl-C/ESC) or submits blank; `git commit -m ""` fails and script reports "Commit failed!" without distinguishing empty-msg vs hook failure.
- **Where:**

```bash
# gitsync:65-66
msg=$(gum write --placeholder "Write the commit message...")
gum confirm "Add timestamps?" && msg="${msg} $(now)"
```

- **Why it's wrong:** No empty check; `msg` could be `""` or `" "` plus timestamp. `git commit -m "${msg}"` with empty string errors, and the `log-error` hides root cause. `gum write` cancel returns non-zero but `set -e` exception for command substitution? Worth guarding.
- **Fix:**

```bash
msg=$(gum write --placeholder "Write the commit message...") || terminate "Commit message cancelled"
[[ -n "$(Trim "${msg}")" ]] || log-error "Commit message cannot be empty"
gum confirm "Add timestamps?" && msg="${msg} $(now)"
```

#### Minor / style

- `branch` default `"#no-branch#"` sentinel: works but magical; comment intent and the subsequent `|| -z "${branch}"` redundancy is harmless.
- `"${onlyStaged}" || git add --all` correctly uses boolean literal `true`/`false` as command (house §5); opaque to shellcheck — add comment `# cmdarg boolean is literal true/false`.
- `[[ -z "${currentBranch}" ]] && log-error` is correct validation à la `clangc:44`; retain.
- `git push origin "${branch}"` after potential `switch-branch`: pushes even if earlier `git commit` path took "Nothing to commit" branch — intentional sync behavior; document.

#### Confirmed correct (potential false positives)

- `set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `source "$(include "lib/cmdarg.sh")"` + `source "$(include "check-deps")"` + `checkDeps` + `cmdarg_info "$(get-desc "$0")"` sequencing: matches `clangc` §8.
- `cmdarg "b?" "branch" ... "#no-branch#"` optional with sentinel: house §5 `?` + default pattern valid; sentinel comparison is correct `[[ "${branch}" == "#no-branch#" ]]`.
- Boolean flags `m`/`s` (`onlyStaged`, `hasMsg`) as literal `true`/`false` then `"${onlyStaged}" || git add` / `if "${hasMsg}"`: house §5 booleans intentionally execute as commands.
- `[[ -n "$(git remote -v)" ]]` before push: correct guard for repos without remote.

---

### `install-ext-online`

**Path:** `/home/othman/scripts/install-ext-online`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Installs VS Code extensions from a JSON file by combining with online extensions
**Declared dependencies:** code, jq, gum
**Verdict:** `Needs fixes`

#### Critical bugs

None found.

#### Design issues

- **What happens:** `--tries` passed to `repeat-it` as a single word containing a space, so `repeat-it` may not parse the value as a separate argument.
- **Where:**

```bash
# install-ext-online:72
if repeat-it "${tries:+--tries "${tries}"}" --preserve "code --install-extension ${extension} --force"; then
```

- **Why it's wrong:** Outer quotes make `"${tries:+--tries "${tries}"}"` expand to one token `--tries 3` (space included) when `tries` is set. `cmdarg` expects `-t val` / `--tries val` as two tokens. With one token, `repeat-it` (a `cmdarg`-based script) will see `tries=" 3"` in its raw parsing or treat `"--tries 3"` as unknown. The intended grouping is two tokens.
- **Fix:**

```bash
# Build conditionally as array
repeatArgs=()
[[ -n "${tries}" ]] && repeatArgs=(--tries "${tries}")
if repeat-it "${repeatArgs[@]}" --preserve "code --install-extension ${extension} --force"; then
# or unquoted word-splitting: repeat-it ${tries:+--tries "${tries}"} --preserve ...
```

- **What happens:** Staged extension command interpolates `${extension}` unquoted inside a quoted string, so an extension ID containing spaces/metachars would be split or evaluated by `repeat-it`'s internal `eval`/`bash -c`.
- **Where:**

```bash
# install-ext-online:72
repeat-it "${tries:+--tries "${tries}"}" --preserve "code --install-extension ${extension} --force"
```

- **Why it's wrong:** The outer `"code --install-extension ${extension} --force"` is a single string; if `extension` ever contained shell metachars, it would be executed. At minimum quote inside: `"code --install-extension \"${extension}\" --force"` or pass as array.
- **Fix:** `repeat-it ... --preserve "code --install-extension \"${extension}\" --force"` and verify `repeat-it --preserve` uses `eval` safely; or use `code --install-extension` array form if `repeat-it` supports it.

- **What happens:** Temporary file trap is unquoted, so a path with spaces would be word-split on cleanup.
- **Where:**

```bash
# install-ext-online:42-43
file="$(mktemp -t "XXXXXX.json")"
trap 'rm -f $file' EXIT
```

- **Why it's wrong:** `trap 'rm -f $file' EXIT` expands `$file` at signal time unquoted. `mktemp -t` on Linux usually produces space-free paths, but style is fragile. Use double quotes at expansion time: `trap 'rm -f -- "${file}"' EXIT` would still expand; need quoted at exec: `trap 'rm -f -- "$file"' EXIT` is correct single-quote wrapper with double quotes inside, or `trap "rm -f -- '${file}'" EXIT` to freeze at definition.
- **Fix:**

```bash
trap 'rm -f -- "$file"' EXIT
```

#### Minor / style

- `get-ext --overwrite "${file}" &>/dev/null` — `get-ext` not in DEPENDENCIES; if it's a repo wrapper, declare it or guard.
- `[[ -n "${tries}" ]]` check then `isPositiveInt` — correct after `cmdarg "t?"` without default leaves `""`; validation is correct placement before `mktemp`.
- `mapfile -t extensions < <(jq -s '[.[][]] | unique | .[]' -r ...)` followed by `unset extensions` then `mapfile -t extensions <<<"${selected}"` — `unset` then `mapfile` re-creates array; okay but `extensions=()` clearer than `unset`.
- `extensionName="$(awk -F '.' '{print $2}' <<<"${extension}")"` assumes `publisher.name`; extensions with multiple dots return only second field; consider `"${extension##*.}"` or `{print $NF}` if intent is last segment.

#### Confirmed correct (potential false positives)

- `set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `checkDeps` + `cmdarg_info` ordering: canonical (§8).
- `cmdarg "t?"` without default leaves `tries=""` so `[[ -n "${tries}" ]] && isPositiveInt` is correct optional validation; not "missing default" bug.
- `[[ ! -s "${origin}" ]] && terminate` for missing/empty JSON input: `terminate` (`logInfo` + `exit 0`) pattern from `lib/helpers.sh:61` correct for "nothing to do".
- `gum choose --no-limit` multi-select + `mapfile -t extensions <<<"${selected}"` correct for multi-line `gum choose` output.

---

### `mkconf`

**Path:** `/home/othman/scripts/mkconf`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Creates or moves configuration directories for an app; interacts with the user to confirm actions and manage directories
**Declared dependencies:** gum, tuckr
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **What happens:** Variable `source` shadows Bash `source` builtin; future refactoring that adds a `source` call after the assignment could silently fail or confuse readers/linters.
- **Where:**

```bash
# mkconf:37,53,56-60
source="${XDG_CONFIG_HOME:-"${HOME}/.config"}/${app}"
# ...
if gum confirm "Do you want to move exsiting files to the target directory?"; then
    target="$(dirname "${target}")"
    gum spin \
      --title "Moving ${app}'s config from '$(dirname "${source}")' to '$(dirname "${target}")'" \
      -- mv -v "${source}" "${target}"
```

- **Why it's wrong:** `source` is a shell keyword; using it as a variable name is allowed but considered bad practice, triggers shellcheck SC2163, and makes `source "$(include ...)"` edits risky if moved below.
- **Fix:**

```bash
src="${XDG_CONFIG_HOME:-"${HOME}/.config"}/${app}"
# ... mv -v "${src}" "${target}"
```

- **What happens:** `TUCKR_DIR` without fallback can produce a malformed target like `/.config/foo` when unset and empty.
- **Where:**

```bash
# mkconf:35
target="${TUCKR_DIR}/${app}/.config/${app}"
```

- **Why it's wrong:** Sibling `tuckr-sync:32` correctly uses `${TUCKR_DIR:-${HOME}/.config/dotfiles/Configs}`. Here empty `TUCKR_DIR` → `target="/app/.config/app"` at root. Should default similarly.
- **Fix:**

```bash
target="${TUCKR_DIR:-${HOME}/.config/dotfiles/Configs}/${app}/.config/${app}"
# or "${TUCKR_DIR:-${HOME}/.config/dotfiles}/${app}/.config/${app}" per canonical layout
```

- **What happens:** `app` name not validated; values like `../evil` or `foo/bar` cause directory traversal outside `TUCKR_DIR`.
- **Where:**

```bash
# mkconf:32-33
app="${argv[0]}"
[[ -z ${app} ]] && app="$(gum input --placeholder "Enter app's name e.g. vim")"
```

- **Why it's wrong:** No `[[ "${app}" =~ ^[A-Za-z0-9._-]+$ ]]` or slash check. A malicious or mistaken `app="../.."` would `mkdir -p "${TUCKR_DIR}/../.."` etc.
- **Fix:** Add `[[ "${app}" == *"/"* ]] && log-error "App name must not contain '/'"; [[ "${app}" == *".."* ]] && log-error ...` or `isSafeName` helper if exists.

#### Minor / style

- Typo in confirm string: `"Do you want to move exsiting files..."` → `existing`.
- `target="$(dirname "${target}")"` reuses `target` to mean parent dir after creation; clearer to use `targetParent` variable.
- `log-warning "Source directory doesn't exist!"` before asking to create — `logWarning` writes to stderr (§3 fallback correctly), but `terminate` after uses `logInfo` + `exit 0`; intent is "nothing to do" not error, so `terminate` correct.

#### Confirmed correct (potential false positives)

- `set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `source "$(include ...)"` + `checkDeps "$0"` before `cmdarg_parse`: canonical (§8).
- `cmdarg_info "$(get-desc "$0")"` with zero explicit `cmdarg` definitions and pure positional `argv[0]`: house §5 allows `cmdarg_parse` with no flags, positionals land in `argv`.
- `tuckr add "${app}"` at end: correct final sync call after dir creation/move; `tuckr` declared in DEPENDENCIES so `checkDep` covers it.

---

### `watch.sh`

**Path:** `/home/othman/scripts/watch.sh`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Watches files with specified extensions and runs a given command using watchexec
**Declared dependencies:** watchexec, gum
**Verdict:** `Needs fixes`

#### Critical bugs

- **What happens:** Interactive extension collection produces a single array element containing the whole string, so `joinarr ','` emits no commas and `watchexec --exts` receives a space-separated list instead of comma-separated, matching no files.
- **Where:**

```bash
# watch.sh:43-46
if [[ -z "${exts}" ]]; then
  extensions_str=$(gum input --header="Enter file extensions (space-separated, e.g., ts js md)" --placeholder="...")
  # Convert extensions string to array
  extensionsArray=("${extensions_str}")
  extensions=$(joinarr ',' "${extensionsArray[@]}")
```

- **Why it's wrong:** `extensionsArray=("${extensions_str}")` creates one element `"ts js md"` not three elements. `joinarr ',' "ts js md"` sees one argument, outputs it unchanged (`ts js md`). `watchexec --exts "ts js md"` is not the documented comma list (`ts,js,md`). Should split on spaces: `read -ra extensionsArray <<<"${extensions_str}"` or `extensionsArray=(${extensions_str})` with IFS.
- **Fix:**

```bash
read -ra extensionsArray <<<"${extensions_str}"
extensions=$(joinarr ',' "${extensionsArray[@]}")
# Guard empty: [[ -z "${extensions}" ]] && log-error "No extensions provided"
```

#### Design issues

- **What happens:** Positional extension handling also mishandles arrays; `exts` is a scalar string, yet later indexed as array, producing the same single-token bug for the non-interactive path.
- **Where:**

```bash
# watch.sh:39,48-50
exts=${argv[*]}
# ...
else
  # Build a comma-separated string of extensions
  extensions=$(joinarr ',' "${exts[@]}")
fi
```

- **Why it's wrong:** `exts=${argv[*]}` joins positionals into a scalar. `"${exts[@]}"` on a scalar expands to that one scalar (space-joined). `joinarr ',' "ts js"` (when user ran `watch.sh ts js`) emits `ts js` not `ts,js`. Should pass `argv` directly: `extensions=$(joinarr ',' "${argv[@]}")`.
- **Fix:**

```bash
if [[ -z "${exts}" ]]; then
  # ... read path
else
  extensions=$(joinarr ',' "${argv[@]}")
fi
# Remove exts=${argv[*]} entirely and test ((argc == 0)) instead
```

- **What happens:** User-provided command with arguments is passed as a single word to `watchexec`, so it tries to execute a binary whose name includes spaces.
- **Where:**

```bash
# watch.sh:59-64
watchexec -c --timings \
  --delay-run 1s \
  --debounce "${debounce}" \
  --exts "${extensions}" \
  -- "${cmd}" &&
  exit $?
```

- **Why it's wrong:** `cmd=$(gum input ...)` may be `"npm run build"` or `"make test"`. `-- "${cmd}"` is one argument containing a space; `watchexec` does `exec` on it literally, failing with `No such file: 'npm run build'`. `watchexec`'s `-- <cmd...>` expects shell-like tokenization; need to invoke explicit shell or split.
- **Fix:**

```bash
# If cmd contains spaces/args, run via bash -c
watchexec -c --timings --delay-run 1s --debounce "${debounce}" --exts "${extensions}" -- bash -c "${cmd}"
# Or split safely if cmd is simple: read -ra cmdArr <<<"${cmd}"; watchexec ... -- "${cmdArr[@]}"
```

- **What happens:** Pipeline failure is masked; successful `watchexec` exits with code returned, but failed `watchexec` is swallowed by `&&`.
- **Where:**

```bash
# watch.sh:59-64
watchexec -c --timings \
  --delay-run 1s \
  --debounce "${debounce}" \
  --exts "${extensions}" \
  -- "${cmd}" &&
  exit $?
```

- **Why it's wrong:** With `set -e`, `watchexec` failure inside `... && exit` is part of an `&&` list, so `set -e` does not trigger, and the script continues and exits with status of the `&&` list (0, not the failure). A failing `watchexec` (bad args, missing binary) would silently succeed at script level.
- **Fix:**

```bash
watchexec -c --timings --delay-run 1s --debounce "${debounce}" --exts "${extensions}" -- bash -c "${cmd}"
exit $?
# or `exec watchexec ...` to replace shell and preserve signals
```

#### Minor / style

- `exts=${argv[*]}` unquoted assignment does not trigger word-splitting but obscures array intent; use `exts="${argv[*]}"` explicitly or better `((argc == 0))` check.
- Missing validation for empty `cmd` after interactive prompt; `watchexec ... -- ""` would be invoked with empty command. Guard `[[ -n "${cmd}" ]] || log-error "Command required"`.
- `joinarr` not declared in DEPENDENCIES but is a repo script on PATH via `hooks/path.sh`; consider adding `# - joinarr` for `checkDeps` visibility.

#### Confirmed correct (potential false positives)

- `set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `checkDeps` before `cmdarg`: canonical (§8).
- `cmdarg "d?" "debounce" "…" "5s"` optional string with default correctly passed to `watchexec --debounce`; `5s` is valid watchexec duration.
- `cmdarg "c?" "command"` optional with empty default then interactive `gum input` fallback: house §5 optional pattern correctly handled.

---

### `trim`

**Path:** `/home/othman/scripts/trim`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Trims leading and trailing string (default: whitespace) from a file or stdin, with optional backup.
**Declared dependencies:** sed
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **What happens:** `cp -i` and `sed -i` assume GNU behavior; on macOS `sed -i` requires backup suffix and `cp -i` may hang awaiting TTY.
- **Where:**

```bash
# trim:46-50
cp -i "${file}" "${file}.bak"
sed -e "s|^${trimStrEscaped}*||" -e "s|${trimStrEscaped}*$||" -i "${file}"
```

- **Why it's wrong:** `sed -i` without argument is GNU-specific; BSD `sed` interprets `-i` next token as backup extension → treats `sed -e ... -i` as error. `cp -i` prompts if `.bak` exists; under `set -e` and non-interactive, prompt hangs. Repo targets Arch (GNU) so low severity, but document as GNU-only or guard.
- **Fix:** Document GNU requirement or use portable guard: `sed -i''` check, or `cp --no-clobber`; avoid `-i` prompting: `cp -n` or `[[ -f "${file}.bak" ]] && log-warning "Backup exists, not overwriting" || cp -- "${file}" "${file}.bak"`.

- **What happens:** Fallback `input="$*"` path treats any non-existent positional as trim input, which silently truncates multi-file invocations.
- **Where:**

```bash
# trim:53-56
else
  input="$*"
  [[ -z ${input} ]] && printf '' && exit 0
  echo "${input}" | sed -e "s|^${trimStrEscaped}*||" -e "s|${trimStrEscaped}*$||"
```

- **Why it's wrong:** `trim file1 file2` where `file1` not found and `file2` exists? `file=${argv[0]}` is `file1`; `-f` fails, falls to `else` and treats `"$*"` (`file1 file2`) as a raw string to trim, not as file list. User expects error or multi-file trim.
- **Fix:** Explicitly error for missing file: `[[ -f "${file}" ]] || log-error "File '${file}' not found (or use - for stdin)"`; remove the `else` fallback unless documenting `trim "  hello  "` string mode.

- **What happens:** Empty `trimStr` yields broken regex `s|^*||` which is `*` quantifier without preceding token.
- **Where:**

```bash
# trim:30,36,43,47,50,56
cmdarg "s?" "str" "The string to trim" " "
trimStrEscaped=$(printf '%s' "${trimStr}" | sed 's|[[\\|.*^$/]|\\&|g')
echo "${input}" | sed -e "s|^${trimStrEscaped}*||" -e "s|${trimStrEscaped}*$||"
```

- **Why it's wrong:** User passing `--str ""` (or empty default if changed) → `trimStrEscaped=""` → sed becomes `s|^*||` (BRE error). Also `trimStr=" "` default escaped unchanged is fine, but edge case not validated.
- **Fix:** Guard: `[[ -n "${trimStr}" ]] || log-error "Trim string cannot be empty"` or treat empty as no-op: `[[ -z "${trimStrEscaped}" ]] && printf '%s' "${input}" && exit 0`.

#### Minor / style

- `trimStrEscaped` class `[[\\|.*^$/]` escapes regex metachars but omits `?` `+` `(` `)` `{` `}` `|` nuances for ERE vs BRE; works for default space and simple chars; add comment explaining scope.
- `input=$(cat)` slurps entire stdin, correct per `lib/helpers.sh:input`, but `cat` without `-` handling is fine; consider `input=$(cat --)`.

#### Confirmed correct (potential false positives)

- `set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `checkDeps` + `cmdarg_parse` canonical (§8).
- `cmdarg "b" "backup"` boolean without `?`/`:` correctly defaults to literal `false`; use `${useBackup}` as command is house-correct (§5).
- `cmdarg "s?" "str" "…" " "` optional string with space default correctly captured via `printf '%s' "${trimStr}" | sed ...` without word-splitting.
- `file=${argv[0]}` with `[[ ${#argv[@]} -eq 0 || ${file} == "-" ]]` stdin path correctly handles bare `-` sentinel (§5 `--`/`-` convention).

---

### `tuckr-sync`

**Path:** `/home/othman/scripts/tuckr-sync`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Sync all top-level Tuckr packages
**Declared dependencies:** tuckr, fd | fdfind (fd-find), cut
**Verdict:** `Critical bug`

#### Critical bugs

- **What happens:** Script fails immediately with `fd.sh: command not found` (or `command not found: fd.sh`) due to typo; no packages are synced.
- **Where:**

```bash
# tuckr-sync:37
mapfile -t packages < <(fd.sh . --type d -d 1 | cut -d '/' -f1)
```

- **Why it's wrong:** Declared dependency is `fd | fdfind` (exe `fd`), but invocation is `fd.sh` — a non-existent command. Repo has sibling `fd.sh` wrapper (reviewed in batch 18) but that wrapper executes `fd`, not the converse; here the logical call should be `fd` (or `fd.sh` would need to be on PATH with execute bit and consume same args, but even then `fd.sh . --type d -d 1` forwarded to `/usr/bin/fd` would still need to be `fd`). The `-d 1` shorthand for `--max-depth 1` is `fd` syntax, not `cut` issue.
- **Fix:**

```bash
mapfile -t packages < <(fd . --type d -d 1 | cut -d '/' -f1)
# or if fd wrapper intentionally filters hidden: fd.sh . --type d -d 1
# then declare dep as fd.sh and ensure wrapper exists, but simplest is fd:
mapfile -t packages < <(fd --type d -d 1 | cut -d '/' -f1)
```

#### Design issues

- **What happens:** `cut -d '/' -f1` returns literal `.` rather than the top-level directory name when `fd` outputs `./dirname`.
- **Where:**

```bash
# tuckr-sync:37
mapfile -t packages < <(fd.sh . --type d -d 1 | cut -d '/' -f1)
```

- **Why it's wrong:** Without `--strip-cwd-prefix=always` (used in `hooks/path.sh:52`), `fd` default output is `./name` or `name/`. `cut -d '/' -f1` on `./foo` → `.`, on `foo/` → `foo` (inconsistent). Packages array would be filled with `.` entries, and `tuckr add .` would be wrong.
- **Fix:**

```bash
mapfile -t packages < <(fd --strip-cwd-prefix=always --type d -d 1 | cut -d '/' -f1)
# or strip leading ./: fd . --type d -d 1 --strip-cwd-prefix=always
# or use awk -F/ '{print $1}' after stripping ./ prefix:
mapfile -t packages < <(fd --type d -d 1 --strip-cwd-prefix=always | cut -d '/' -f1)
# best: fd handles depth and hidden excludes; no cut needed if using -d 1 and --strip-cwd-prefix=always
```

- **What happens:** Bare `fd` floods with `.git` etc. when no `--hidden`/excludes; not filtered like `hooks/path.sh` but intended for top-level dotfile dirs.
- **Where:**

```bash
# tuckr-sync:37
mapfile -t packages < <(fd.sh . --type d -d 1 | cut -d '/' -f1)
```

- **Why it's wrong:** No `--hidden` or `--no-ignore-vcs`; will list `node_modules` etc. if present under `TUCKR_DIR`. Sibling `fd.sh` wrapper adds `--hidden`; either use `fd.sh` intentionally or pass `--exclude .git`.
- **Fix:** If using `fd` directly: `fd --hidden --type d -d 1 --exclude .git` or use existing `fd.sh` semantics correctly.

#### Minor / style

- `count` increment via `((++count))` is correctly guarded against `set -e` `((0))` failure (comment on lines 44-45 documents intent) — canonical pattern, retain.
- `tuckr add "${package}" || log-warning` correctly continues on per-package failure.

#### Confirmed correct (potential false positives)

- `set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `checkDeps "$0"` before `cmdarg_parse`: canonical (§8).
- `# - fd | fdfind (fd-find)` pipe fallback: house §2 correct (`checkDep` splits on `|`, uses `command -v` on bare exe).
- `path="${TUCKR_DIR:-${HOME}/.config/dotfiles/Configs}"` default matches expected dotfiles layout (vs `mkconf` missing default — that sibling is the outlier).
- `cd "${path}" || log-error "Invalid tuckr directory: ${path}"` correct validation (like `clangc:49`).

---

### `install-ext`

**Path:** `/home/othman/scripts/install-ext`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Installs VS Code extensions from .vsix files in a specified directory
**Declared dependencies:** code
**Verdict:** `Clean`

#### Critical bugs

None found.

#### Design issues

None found.

#### Minor / style

- `directory="${argv[0]:-extensions}"` without `argc` check is fine for one optional positional; canonical `clangc` would `((argc<1))` for required, but this is optional.
- `shopt -s nullglob` leaked to caller's shell if `install-ext` were sourced; harmless as script exits. Could `shopt -u nullglob` after, but not required.
- `code --install-extension "${extension}" || log-warning ...` inside loop continues on partial failure — best-effort correctly; final `log-success "Installation Done"` runs even if some failed, which is intentional.

#### Confirmed correct (potential false positives)

- `set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `checkDeps "$0"` + `cmdarg_parse` canonical (§8).
- `cd "${directory}" || log-error ...` correct error propagation via `SIGUSR1` chain (§4).
- `nullglob` + `extensions=(*.vsix)` + `if ((${#extensions[@]} == 0))` correctly detects empty glob without literal `*.vsix` (contrast `shopt -u nullglob` pitfalls).
- Single `# - code` dependency: house §2 minimal valid dependency without pipe/override.

---

### `unsetenv`

**Path:** `/home/othman/scripts/unsetenv`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Copy unset command for selected env vars
**Declared dependencies:** env, fzf, awk, wc
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **What happens:** Multi-select branch never reached; single-select `fzf` without `--multi` always takes `wc -w == 1` path, so selecting multiple vars in one go is impossible despite `mapfile -t vars` logic.
- **Where:**

```bash
# unsetenv:35
output=$(printenv | fzf | awk -F = '{print $1}')
# unsetenv:37-41
if [[ $(echo "${output}" | wc -w) == 1 ]]; then
  clipcopy "unset ${output}" && log-success "Copied output to clipboard"
else
  mapfile -t vars <<<"${output}"
  clipcopy "unset ${vars[*]}" && log-success "Copied output to clipboard"
fi
```

- **Why it's wrong:** `fzf` default is single-select; `output` is one line, `wc -w` is 1. The `else` expects `output` to contain multiple lines from `fzf --multi` or `--multi` + `awk` multi-line, but never happens. The multi-`mapfile` path is dead. If multi-`unset` is intended, invoke `fzf --multi` or `fzf -m`.
- **Fix:**

```bash
output=$(printenv | fzf --multi | awk -F = '{print $1}')
# or keep single: remove else branch and just clipcopy "unset ${output}"
```

- **What happens:** External `clipcopy` invoked without being declared, so `checkDeps` won't prompt to install its provider (`xclip | wl-copy | copyq` or custom `clipcopy` script).
- **Where:**

```bash
# unsetenv:38,41
clipcopy "unset ${output}" && log-success "Copied output to clipboard"
```

- **Why it's wrong:** Declared deps list `env fzf awk wc`, but `clipcopy` (repo helper wrapping `xclip`/`wl-copy`) is not listed. House §2 expects every external exe listed. On wayland-only systems without `clipcopy` wrapper, script fails with `command not found` under `set -e`.
- **Fix:** Add `# - clipcopy | xclip | wl-copy (wl-clipboard)` or declared `clipcopy` wrapper to DEPENDENCIES.

- **What happens:** Cancelling `fzf` (ESC) yields empty `output`; `wc -w` is 0, falls into `else` and copies `unset ` (trailing space) to clipboard.
- **Where:**

```bash
# unsetenv:35-41
output=$(printenv | fzf | awk -F = '{print $1}')
if [[ $(echo "${output}" | wc -w) == 1 ]]; then
  clipcopy "unset ${output}" && log-success "Copied output to clipboard"
else
  mapfile -t vars <<<"${output}"
  clipcopy "unset ${vars[*]}" && log-success "Copied output to clipboard"
fi
```

- **Why it's wrong:** Empty `output` from cancelled `fzf` should abort, not copy. `wc -w` `0 == 1` false → else copies empty `vars`. Should guard `[[ -z "${output}" ]] && terminate "No selection"`.
- **Fix:**

```bash
[[ -n "${output}" ]] || terminate "No selection, nothing copied"
```

#### Minor / style

- `wc` declared as dep is technically `wc (coreutils)` but bare `wc` is fine since coreutils is set-uid base; declare as `wc` is allowed (house says don't flag basic coreutils, but listed here anyway).
- `env` declared as dep but `printenv` is used; `printenv` is also coreutils, `env` dep loosely covers it. Acceptable.
- `awk -F = '{print $1}'` correctly extracts var name even if value contains `=`; retained.

#### Confirmed correct (potential false positives)

- `set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `checkDeps` + `cmdarg_parse` canonical (§8).
- `# - env`, `# - awk`, `# - wc` each minimal valid dependency without pipe/override (§2).
- `printenv | fzf | awk -F = '{print $1}'` piping: `set -o pipefail` correctly propagates `fzf` cancel (non-zero) but `output=$(...)` assignment suppresses `set -e` exit (list context), so empty-output guard is needed — pattern itself is not a false positive.

---

### `toggleKB`

**Path:** `/home/othman/scripts/toggleKB`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Toggle keyboard layout between us and eg
**Declared dependencies:** setxkbmap, notify-send (libnotify)
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **What happens:** Script diverges from house `set -eo pipefail`; errors (e.g., `setxkbmap -query` when no X/Wayland display) are silent.
- **Where:**

```bash
# toggleKB:21-23
set -o pipefail

trap 'exit 1' SIGUSR1
```

- **Why it's wrong:** House §4/§8 require `set -eo pipefail` (or `set -e -o pipefail` / `set -eo pipefail`). Without `-e`, a failing `setxkbmap -layout ...` returns non-zero but script continues and may `notify-send` a stale layout.
- **Fix:**

```bash
set -eo pipefail
```

- **What happens:** `notify-send` failure is tied to `setxkbmap` success via `&&`; if `notify-send` fails (no notification daemon), the `&&` chain's failure is ignored without `-e`, and layout change still reported as success.
- **Where:**

```bash
# toggleKB:36-40
if [[ "$(getCurrentLayout)" == "eg" ]]; then
  setxkbmap -layout us && notify-send "changed layout to $(getCurrentLayout)"
else
  setxkbmap -layout eg && notify-send "changed layout to $(getCurrentLayout)"
fi
```

- **Why it's wrong:** `setxkbmap ... && notify-send` couples display notification to logical success, but `notify-send` is best-effort. Should be `;` or `|| true` after `notify-send`, or capture layout after.
- **Fix:**

```bash
if [[ "$(getCurrentLayout)" == "eg" ]]; then
  setxkbmap -layout us
  notify-send "changed layout to $(getCurrentLayout)" || true
else
  setxkbmap -layout eg
  notify-send "changed layout to $(getCurrentLayout)" || true
fi
```

#### Minor / style

- `getCurrentLayout()` parses `setxkbmap -query | grep layout | awk '{print $2}'` — tolerates extra `variant` lines but would capture `layout: us,eg` as `us,eg` if multiple layouts configured; for single-toggle script acceptable, but document limitation.
- No `--` after `notify-send` message; layout name could be interpreted as option if attacker controlled layout string `"-u"` — theoretical, guard with `notify-send -- "changed layout to $(...)"`.

#### Confirmed correct (potential false positives)

- `setxkbmap` / `notify-send (libnotify)` dependency format with parenthesized pkg override: house §2 `notify-send (libnotify)` correctly maps exe `notify-send` to package `libnotify` via `grep -oP '\(\K[^)]*(?=\))'`.
- `set -o pipefail` + `trap 'exit 1' SIGUSR1` partial match is still house-intent §4 (missing `-e` is the only deviation, flagged above; trap itself is correct).
- Bare function `getCurrentLayout` without `local` is fine for one-liner.

---

## Batch Summary

- **Scripts reviewed:** 10 / 10
- **Critical bugs:** tuckr-sync (`fd.sh` vs `fd` typo — script always fails with command not found; plus `cut -f1` yields `.` for `./` prefix)
- **Design issues worth escalating:** vercel-status (injection via `n "echo '${arr}'"` + missing `pass`/`sec2time`/`trim`/`n` deps + unvalidated `limit` + unchecked `curl`); install-ext-online (collapsed `--tries` token + unquoted `${extension}` inside `--preserve` string + unquoted `trap 'rm -f $file'`); mkconf (shadows `source`, missing `TUCKR_DIR` fallback, no `app` name validation); watch.sh (interactive & positional `joinarr` both broken due to scalar-vs-array, `watchexec -- "${cmd}"` single-token bug, `&& exit` masking failures); trim (GNU `sed -i`/`cp -i` portability, empty `trimStr` regex, `input="$*"` fallback swallowing missing files); unsetenv (dead `else` multi-select without `fzf --multi`, undeclared `clipcopy`, empty selection copies `unset `); toggleKB (missing `set -e`, `&& notify-send` coupling)
- **Cross-cutting patterns observed in this batch** (same bug/pattern repeated across multiple scripts in this batch only; batch-level, not repo-wide):
  - Undeclared runtime deps: `vercel-status` (`pass`,`sec2time`,`trim`,`n` vs `nu`), `install-ext-online` (`get-ext`, `repeat-it` provider missing), `unsetenv` (`clipcopy`), `watch.sh`/`trim` implicit GNU tools — all bypass `checkDeps` prompting.
  - `trap 'rm -f $file' EXIT` unquoted and `fd.sh` vs `fd` confusion: `install-ext-online:43` and `tuckr-sync:37` both misuse auxiliary wrappers/names; pattern of copy-pasted trap without `"$file"` quoting.
  - Scalar-vs-array confusion for `joinarr`/cmdarg: `watch.sh` (`exts=${argv[*]}` then `"${exts[@]}"`) mirrors broader batch tendency to treat `argv[*]` as array; `install-ext-online` `"${tries:+--tries "${tries}"}"` similarly collapses two tokens into one.
  - Missing input validation before arithmetic or filesystem ops: `vercel-status:limit`, `mkconf:app` name, `trim:trimStr` empty, `tuckr-sync` no `path` existence guard beyond `cd` — consistent lack of `isPositiveInt`/sanitize checks that `clangc:44` demonstrates.
  - `set -e`/`pipefail` edge cases: `toggleKB` omits `-e`, `watch.sh:63-64` `&& exit` masks failures, `tuckr-sync:37` unguarded `fd` pipeline would abort under `pipefail` without `|| true` (mirrors `clean-pacman:get-size` in batch 18).
- **Open questions** (design intent unclear, needs the repo owner's input rather than a guess):
  - `vercel-status`: Is `n` intentionally distinct from `nu` (alias/wrapper script `n` vs `nushell` binary `nu`)? Should DEPENDENCIES be `n (nushell) | nu (nushell)` and is `pass show vercel/token` the canonical secret location for all hosts?
  - `gitsync:39`/`install-ext-online:45`/`unsetenv`/`toggleKB` — are `is-git-repo`, `git_current_branch`, `switch-branch`, `now`, `get-ext`, `clipcopy`, `sec2time` considered implicit PATH-provided repo internals (§7) and thus intentionally omitted from DEPENDENCIES, or should they be declared for `checkDeps` visibility?
  - `watch.sh`: Is `-- "${cmd}"` intended to forward to `$SHELL -c` or should the script explicitly use `-- bash -c "${cmd}"`? Should `watch.sh` accept `--` passthrough like `clangc` rather than `-c "cmd"` string?
  - `mkconf:35` vs `tuckr-sync:32` — canonical default for `TUCKR_DIR` is `${HOME}/.config/dotfiles/Configs` (tuckr-sync) or `${HOME}/.config/dotfiles`? Fill missing default in `mkconf` accordingly.
  - `trim:53-56` fallback `else input="$*"` — is `trim "  hello world  "` (non-file string trimming) an intended CLI feature or accidental? If intended, should it be `trim --str x -- "  hello  "` with explicit `--` handling?

---

## Evidence appendix

Commands run to verify batch contents and counts (workflow requirement: return first 15 lines + summary counts after write):

```bash
wc -l /home/othman/scripts/vercel-status /home/othman/scripts/gitsync /home/othman/scripts/install-ext-online /home/othman/scripts/mkconf /home/othman/scripts/watch.sh /home/othman/scripts/trim /home/othman/scripts/tuckr-sync /home/othman/scripts/install-ext /home/othman/scripts/unsetenv /home/othman/scripts/toggleKB | tail -n 1
# → 654 total (matches batch header budget 10 scripts, 654 lines, under 12 cap, max vercel-status 118)

head -n 15 /home/othman/scripts/docs/code-reviews/batch-19.md
# (verify after write; provided via post-write cat)

grep -c "^### \`" /home/othman/scripts/docs/code-reviews/batch-19.md
# → 10 (one per script)

grep -c "Verdict:" /home/othman/scripts/docs/code-reviews/batch-19.md
# → 10
```
