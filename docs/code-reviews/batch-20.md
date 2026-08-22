# Batch Review: 20 of 22

**Scripts in this batch:** `get-unique`, `rmbranch`, `fzf-preview`, `make-signature`, `down-ext-file`, `image-text`, `pkg-install`, `trunc`, `tabs2spaces`, `editwhich`
**Batch composition:** grab-bag (small-grab) — 10 scripts, 654 lines, under 12 cap. No single family; mix of `get-unique`, `rmbranch`, `fzf-preview`, `make-signature`, `down-ext-file` and others — header note grab-bag.
**Reviewer:** subagent-20
**Date:** 2026-08-21

---

## House Style Reference (do not flag these as bugs)

Before reviewing, confirm you've internalized these repo conventions. Restate them here in one line each to prove the context loaded correctly:

- Dependency declaration format (`# - binary | binary2 (pkg-override)`) and how `checkDep` resolves it: Dependencies live between `# --- DEPENDENCIES --- #` / `# --- END SIGNATURE --- #` as `# - exe | alt (pkg)`; `checkDep` in `check-deps:21` splits on `|`, trims, `command -v` each alt in order and returns 0 if any found, else echoes parens-override or first exe for `installDep`/`getPackageManager`.
- Logging convention: `log-*` wrapper scripts are primary, camelCase `log*` functions in `lib/helpers.sh` are fallback: `log.sh:28` dispatches `log-debug|info|warning|error|success` via `LEVEL_COLORS`/`LEVEL_OUTPUT` to `colorOnlyPrefix`; `lib/helpers.sh:34` camelCase `logDebug`/`logSuccess` etc. are in-process fallback fork-free — `log-success` calling `logSuccess` is not dead code.
- `trap 'exit 1' SIGUSR1` + `kill -SIGUSR1 "${PPID}"` propagation chain purpose: Every script sets `set -eo pipefail` + `trap 'exit 1' SIGUSR1`; only `log-error` (guarded by `! isInteractiveShell` and `--no-kill`/`--safe`) does `kill -SIGUSR1 "${PPID}"` to propagate fatal up the call chain without exit-code checks — trap alone is not suspicious.
- `cmdarg.sh` argument-parsing pattern used across scripts: `source "$(include "lib/cmdarg.sh")"` then `cmdarg_info "header" "$(get-desc "$0")"` + pre-declare `declare -a arr; declare -A hash` before `cmdarg "v" "verbose" ...` / `cmdarg "m:"` required / `cmdarg "o?"` optional / `[]` array / `{}` hash, then `cmdarg_parse "$@"` and read `cmdarg_cfg['key']` (booleans literally `true`/`false` usable as `if ${cmdarg_cfg['x']}; then`) and positionals via `argv`/`argc`.
- `get-desc` / `get-deps` signature-block parsing rules: Both `sed -n` the comment block `# --- DESCRIPTION --- #` … `# --- DEPENDENCIES --- #` … `# --- END SIGNATURE --- #`; `get-desc` tolerates either terminator and `get-deps` does `sed 's|# - ||g'` + `replace.sh` + `grep -v " --- "` or `x-none`; missing sections are allowed — empty dependency block is correct.
- `init.sh` / `hooks/path.sh` symlink and PATH-registration workflow: `init.sh:63` verifies `SCRIPTS_DIR`/`fd`/`hooks/path.sh` then idempotently appends `[[ -s "${SCRIPTS_DIR}/hooks/path.sh" ]] && source ...` to `~/.bashrc`/`${ZDOTDIR:-$HOME}/.zshrc`; `hooks/path.sh:21` is sourced at shell startup, caches `fd -t x` executable list to `/tmp/path-hook.cache`, rescans only when `find ... -newer cache`, then appends each exe's dir to `PATH` once — scripts do not manage PATH themselves.
- Reference pattern from `clangc` (what "correct" looks like in this repo): `clangc:21` canonical order `set -eo pipefail` + `trap` + `source "$(include "lib/cmdarg.sh")"` + `source "$(include "lib/compile.sh")"` + `source "$(include "check-deps")"` + `checkDeps "$0"` then `cmdarg_info` + pre-declare array + `cmdarg "c"`/`"o?"`/`"a?[]"`/`"q"` + `cmdarg_parse "$@"` + `${cmdarg_cfg[...]}` reads + `((argc <1)) && log-error` + safe array building + nameref delegation.

---

## Script Reviews

### `get-unique`

**Path:** `/home/othman/scripts/get-unique`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Filters unique lines that appear once in a file or stdin, with options for backup and array output
**Declared dependencies:** `awk`
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **Stdin vs file branching hides missing-file vs empty-file distinction, and `mv -i` can hang non-interactively:**

  ```bash
  # get-unique:74,90-93
  if [[ -z "${file}" || "${file}" == "-" ]]; then
    remove_duplicates
  # ...
      if "${force}"; then
        mv "${tmpfile}" "${file}"
      else
        mv -i "${tmpfile}" "${file}"
      fi
  ```

  - **Why:** `mv -i` prompts on overwrite (stdin) and blocks in CI/headless; `set -eo pipefail` means no prompt handler. Forceless path should either be explicit or use `mv -f` after user confirmation via `gum`/`yesNo` like other scripts, or document interactive-only.
  - **Fix:** Keep `mv -i` only when `isInteractiveShell`, else `mv -f`, or gate with explicit confirmation flag.

- **Array mode via `tr ' ' '\n'` splits on single spaces only and collapses quoted strings:**

  ```bash
  # get-unique:47
  tr ' ' '\n' |
  ```

  - **Why:** Input `foo "bar baz"` becomes 3 tokens, not 2; downstream `paste -sd " "` re-joins with single space, not valid Bash array syntax (`declare -a`). Works for simple word lists but fragile.
  - **Fix:** If true Bash array output needed, emit `printf '%q '` or `declare -p`; otherwise document as word-list mode.

#### Minor / style

- **Unquoted `$tmpfile` in trap** — `get-unique:79` `trap 'rm -f $tmpfile' EXIT` relies on single-quoted deferred expansion (correct per house style for deferred) but `rm -f $tmpfile` word-splits if path contains spaces; mktemp is safe but `rm -f "${tmpfile}"` via `trap "rm -f \"${tmpfile}\""` or `trap 'rm -f "${tmpfile}"' EXIT` would be tighter. Low risk.
- **Duplicated `awk` program** — `get-unique:48-58` vs `60-70` identical except pipe prefix; could be single `awk` with conditional `paste` — cosmetic.
- **Backup silently overwrites** — `get-unique:83` `cp "${file}" "${file}.bak"` overwrites existing `.bak` without check.

#### Confirmed correct (potential false positives)

- `set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `source "$(include "lib/cmdarg.sh")"` + `checkDeps "$0"` follows house style — not flagged.
- `cmdarg "b"`/`"f"`/`"a"`/`"q"` boolean flags defaulting to literal `false` and tested as `if "${useArray}"; then` — correct per `cmdarg.sh:86` (`true`/`false` as commands).
- Dependency `awk` alone — `tr`/`paste` not declared is fine per house brief (coreutils excluded).
- `get-desc`/`get-deps` optional block handling — empty-deps case not present, but declaration format matches checkDep spec.

---

### `rmbranch`

**Path:** `/home/othman/scripts/rmbranch`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Removes a branch locally and remotely
**Declared dependencies:** `git`
**Verdict:** `Critical bug`

#### Critical bugs

- **Remote deletion uses local tracking-branch delete, not remote delete:**

  ```bash
  # rmbranch:85-86
  if [[ "${deleteRemote}" == "true" ]]; then
    git branch -D --remote "origin/${branch}" 2>/dev/null ||
      log-warning "Branch '${branch}' doesn't have a remote"
  fi
  ```

  - **What happens:** `git branch -D --remote` (alias `-D -r`) deletes the local remote-tracking ref `origin/<branch>`, never contacts the remote. The remote branch remains on `origin`.
  - **Why it's wrong:** User confirms "Delete remote as well?" but branch persists remotely; subsequent fetch restores tracking branch.
  - **Fix:**

  ```bash
  if [[ "${deleteRemote}" == "true" ]]; then
    git push origin --delete "${branch}" 2>/dev/null ||
      log-warning "Branch '${branch}' doesn't have a remote or push failed"
  fi
  ```

- **Positional read via `$1` after `cmdarg_parse` instead of `argv`** — `rmbranch:54` `if [[ -n "$1" ]]; then targetBranches=("$1")` bypasses `cmdarg` contract (house brief §5: use `argv`/`argc`, `$@` consumed). Inside function `cmdarg_parse` shifts its own `$@`, not caller's `$1`, but caller `$1` is stale and breaks bare `-` / `--` handling and multi-arg cases.

  ```bash
  # rmbranch:54-55
  if [[ -n "$1" ]]; then
    targetBranches=("$1")
  ```

  - **Why:** If user passes `rmbranch -- origin/foo` or `rmbranch -` (pos sentinel), `argv` contains correct positional, `$1` is `--` or original flag. Capacity for multiple branches also lost (`"$1"` single).
  - **Fix:**

  ```bash
  if ((argc > 0)); then
    targetBranches=("${argv[@]}")
  ```

#### Design issues

- **Undeclared external dependencies** — uses `rg` (`rmbranch:50,73`), `gum` (`rmbranch:57,79`), plus repo-internal `no-dups`/`trim`/`remove-blanks`/`replace.sh`/`is-git-repo`/`git_current_branch` but only declares `git`. `rg`/`gum` will not be auto-installed via `checkDep`; script fails with `command not found` on minimal hosts.

  ```bash
  # rmbranch:17-18 declares only git, but:
  branchesString="$(printf '%s\n' "${branchList}" | rg -v "${currentBranch}")"
  output=$(gum choose --no-limit "${branches[@]}")
  targetBranches[i]=$(echo "${targetBranches[${i}]}" | replace.sh "origin/" '' | trim)
  ```

  - **Fix:** Extend block to `# - rg (ripgrep)` `# - gum` (and optionally note internal scripts are PATH-supplied via hook, not checkDeps).

- **Unsafe `rg` pattern from branch name (regex injection)** — `rmbranch:50` `rg -v "${currentBranch}"` and `rmbranch:73` `rg -qx "${branch}"` interpret branch names as regex. Branches like `fix/foo+bar` or `feat[1]` will mismatch or error. Should be fixed-string.

  - **Fix:** `rg -F -v -- "${currentBranch}"` and `rg -F -qx -- "${branch}"`, or use `grep -Fxv`.

- **No quoting of branch array expansion in `gum choose`** — `rmbranch:57` `gum choose --no-limit "${branches[@]}"` is correctly quoted, but `mapfile -t targetBranches <<<"${output}"` splits on newlines; `gum choose --no-limit` with spaces in branch names (allowed via `git branch`? unlikely but legal) would still be okay, but worth noting.

#### Minor / style

- `deleteRemote="false"` string boolean then `[[ "${deleteRemote}" == "true" ]]` — works but diverges from `cmdarg` literal `true`/`false` command pattern; consistent with repo's ad-hoc booleans.
- `branchList` constructed via two `git branch` calls concatenated without separator then re-split via `printf '%s\n'` — redundant but functional.
- Exit code 0 at end masks prior `log-warning` branches; fine.

#### Confirmed correct (potential false positives)

- `set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `source "$(include "lib/helpers.sh")"` + `source "$(include "lib/cmdarg.sh")"` + `checkDeps "$0"` + `is-git-repo` / `git_current_branch` call order — matches house style / `clangc` reference, not flagged.
- `checkDep` pipe syntax not present but `git` alone is valid; missing `DESCRIPTION` not an error per house brief §6.
- `source "$(include ...)"` indirection via `realpath -m` — intentional per house brief §1.

---

### `fzf-preview`

**Path:** `/home/othman/scripts/fzf-preview`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Script for previewing files in Ctrl-t menu
**Declared dependencies:** `eza`, `fd`, `mdcat | glow`, `bat`, `kitty | catimg | ffprobe (ffmpeg)`
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **Unquoted / unchecked `target` can abort preview via `set -e`:**

  ```bash
  # fzf-preview:32-33
  target="$(printf '%s\n' "$1" | head -n 1)"
  mime=$(file --mime-type -Lb "${target}")
  ```

  - **Why:** If `$1` empty or file missing, `file --mime-type -Lb ""` exits non-zero; under `set -eo pipefail` the script exits non-zero and fzf shows nothing instead of graceful fallback to `file "${target}"`. Also uses `$1` not `argv`; preview is invoked as `fzf-preview {}` single arg so works, but inconsistent with `cmdarg` contract.
  - **Fix:**

  ```bash
  target="$(printf '%s\n' "${1:-}" | head -n 1)"
  [[ -z "${target}" ]] && exit 0
  mime=$(file --mime-type -Lb "${target}" 2>/dev/null || echo "unknown")
  ```

- **TERM exact match for kitty** — `fzf-preview:59` `[[ "${TERM}" == xterm-kitty ]]` misses `xterm-kitty` variants via `TERM` override or `KITTY_WINDOW_ID` detection; `[[ -n "${KITTY_WINDOW_ID}" ]] || [[ "${TERM}" == xterm-kitty* ]]` would be more robust, but current is acceptable for declared fallback chain (`catimg`/`ffprobe`/`file`).

#### Minor / style

- `head -n 500` hard limit for md/text previews — adequate but not configurable.
- `eza --ignore-glob="node_modules|..."` — string glob not regex; eza docs accept `|` as separator? Works but fragile.
- Declared `fd` dependency but script does not call `fd` directly (relies on fzf's `FZF_DEFAULT_COMMAND`); declaration is precautionary for hook, not a bug.

#### Confirmed correct (potential false positives)

- `set -eo pipefail` + `trap` + dual `source` + `checkDeps` order — correct per `clangc`.
- Dependency alternations `mdcat | glow` and `kitty | catimg | ffprobe (ffmpeg)` correctly declare fallback via `|` and package override `(ffmpeg)` — valid per house brief §2, not flagged as syntax errors.
- Logging via house style not used — preview writes directly to stdout for fzf, intentional.
- `command -v mdcat` / `glow` / `bat` probing in order — correct `checkDep` semantics reproduced inline.

---

### `make-signature`

**Path:** `/home/othman/scripts/make-signature`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Generates a standardized script signature block with ASCII title, description, and dependency list using toilet
**Declared dependencies:** `toilet`, `sed`
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **Unquoted `${deps}` word-splits and breaks pipe/parens dependencies:**

  ```bash
  # make-signature:50
  for dep in ${deps}; do
    echo "# - ${dep}"
  done
  ```

  - **Why:** Caller `make-signature "mytool" "desc" "fd | fdfind (fd-find)"` — `${deps}` splits on `|` and `()` into 4 words, emitting 4 broken lines `# - fd`, `# - |`, `# - fdfind`, `# - (fd-find)`. Should iterate line-wise or preserve quoted input.
  - **Fix:**

  ```bash
  for dep in "${deps[@]}"; do # if passed as array, or:
  printf '%s\n' "${deps}" | while IFS= read -r dep; do echo "# - ${dep}"; done
  ```

  Or change interface to `deps="${argv[2]}"` loop with `while IFS= read -r` after splitting on `,`.

- **No validation of required positionals** — `make-signature:33-35` `name="${argv[0]}"` `desc="${argv[1]}"` `deps="${argv[2]}"` silently produce empty `toilet` call if `argc <2`; `toilet` then reads stdin or errors under `set -e`.

  ```bash
  # make-signature:33
  name="${argv[0]}"
  desc="${argv[1]}"
  ```

  - **Fix:** `((argc >= 2)) || log-error "Usage: make-signature <name> <desc> [deps]"` before generation.

#### Minor / style

- `toilet --font mono12 --termwidth --width 190` — hard-coded 190 cols may overflow terminal; acceptable for signature generation.
- Hard-coded output template includes `source "$(include "lib/cmdarg.sh")"` etc. even when generated script may not need `helpers.sh` — over-includes but consistent with `clangc` reference.
- Uses `sed` in pipeline `toilet ... | sed 's|^|# |'` — declared dependency `sed` correct per house brief (redundant but not harmful).

#### Confirmed correct (potential false positives)

- `set -eo pipefail` + `trap` + `source "$(include ...)"` + `checkDeps` — house style compliant.
- `cmdarg_info "header" "$(get-desc "$0")"` with no `cmdarg` definitions — allowed (helper script with raw `argv` access), not flagged as missing flags.
- `get-desc`/`get-deps` block parsing optional — declares both DESCRIPTION and DEPENDENCIES, parsed correctly by `include`/`checkDeps`.

---

### `down-ext-file`

**Path:** `/home/othman/scripts/down-ext-file`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Downloads VS Code extensions as .vsix files from a JSON file
**Declared dependencies:** `jq`, `wget`
**Verdict:** `Minor issues`

#### Critical bugs

None found — no silent data loss; failure paths log via `log-error` (SIGUSR1).

#### Design issues

- **Assumes flat JSON array, incompatible with standard VS Code `extensions.json` (`{ "recommendations": [...] }`):**

  ```bash
  # down-ext-file:35
  mapfile -t extensions < <(jq -r '.[]' "${file}" 2>/dev/null) || log-error "Failed to parse '${file}'"
  ```

  - **Why:** Typical `extensions.json` is object, `jq -r '.[]'` yields object values (array) not extension IDs, resulting in `publisher.cut` parsing garbage.
  - **Fix:** Probe both shapes:

  ```bash
  mapfile -t extensions < <(jq -r 'if type=="array" then .[] elif .recommendations then .recommendations[] else .[] end' "${file}" 2>/dev/null) || log-error "Failed to parse '${file}'"
  ```

- **Fragile `cut -d '.' -f 2` for extension name (multi-dot or missing dot):**

  ```bash
  # down-ext-file:45-46
  publisher=$(echo "${extension}" | cut -d '.' -f 1)
  extensionName=$(echo "${extension}" | cut -d '.' -f 2)
  ```

  - **Why:** `publisher.extension.extra` loses `.extra`; `noDotExtension` yields `extensionName=""` then `filename=".vsix"` and malformed URL.
  - **Fix:**

  ```bash
  publisher="${extension%%.*}"
  extensionName="${extension#*.}"
  [[ "${publisher}" == "${extension}" ]] && log-warning "Skipping malformed id: ${extension}" && continue
  ```

- **Redundant `$(pwd)/extensions` and unquoted directory creation check** — `down-ext-file:53` `[[ -f "$(pwd)/extensions/${filename}" ]]` — `$(pwd)` unnecessary (relative `extensions/` sufficient) and `[[ ! -d "extensions" ]] && mkdir -p` should be unconditional `mkdir -p`.

#### Minor / style

- `${extension}` not validated against `^[a-z0-9-]+\.[a-z0-9-]+` — warning on malformed would clarify jq vs cut failure.
- `count` increment via `((++count))` correct but `log-success` with emoji `🚀` — diverges from `log.sh` plain ASCII but intentional for user feedback.

#### Confirmed correct (potential false positives)

- `set -eo pipefail` + `trap` + `source "$(include ...)"` + `checkDeps` — house style.
- `cmdarg_parse` with zero definitions then raw `argv[0]:-extensions.json` — valid per `cmdarg.sh` (positionals allowed without flag definitions).
- `jq`/`wget` declared correctly; `mkdir -p` not declared per house brief (coreutils excluded).
- `log-warning` vs `logWarning` naming — both layers canonical per house brief §3.

---

### `image-text`

**Path:** `/home/othman/scripts/image-text`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Generates a blank image with text on it
**Declared dependencies:** `magick (imagemagick)`
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **Success guard `&& log-success` suppresses `set -e` failure on magick error:**

  ```bash
  # image-text:50-59
  magick -size "${width}x${height}" \
    "xc:${background}" \
    ...
    "${name}.${extension}" &&
    log-success "Created image '${name}.${extension}' successfully"
  ```

  - **Why:** With `set -e`, a failing command in `A && B` does not trigger exit (Bash `set -e` exception for `&&`/`||` lists). If `magick` fails (bad color, missing font `Inter`, write permission), script exits 0 silently without error.
  - **Fix:**

  ```bash
  magick -size "${width}x${height}" "xc:${background}" ... "${name}.${extension}" || log-error "Failed to create image"
  log-success "Created image '${name}.${extension}' successfully"
  ```

- **Dead fallback `:-${argv[0]}` for name** — `image-text:48` `name="${cmdarg_cfg['name']:-${argv[0]}}"` — `cmdarg "n?"` defaults to `"blank"`, so `cmdarg_cfg['name']` is never empty/unset; `argv[0]` fallback never reached. If intent was `image-text myname -m "hello"` positional name, need `cmdarg "n?"` default `""` and `name="${cmdarg_cfg['name']:-${argv[0]:-blank}}"`.

#### Minor / style

- No validation that `width`/`height`/`font-size` are positive ints — `magick` will error, but early `isPositiveInt` check would give clearer message (consistent with `lib/helpers.sh:218`).
- `-family "Inter"` hard-coded; missing font falls back silently — could warn or make configurable.
- Declared dependency `magick (imagemagick)` correct per house brief package-override syntax.

#### Confirmed correct (potential false positives)

- `cmdarg "m:"` required message — correctly enforces via `cmdarg.sh:79` `CMDARG_REQUIRED` without default, not flagged as missing validator.
- `checkDep` `magick (imagemagick)` package override — correct parse per house brief §2.
- `trap`/`include`/`checkDeps` ordering matches `clangc` reference.

---

### `pkg-install`

**Path:** `/home/othman/scripts/pkg-install`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Install official packages interactively using fzf and pacman
**Declared dependencies:** `fzf`, `updatedb (plocate)`
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **`set -eo pipefail` aborts on fzf cancellation (ESC/CTRL-C) instead of graceful no-op:**

  ```bash
  # pkg-install:47
  mapfile -t pkgNames < <(pacman -Slq | fzf "${fzf_args[@]}")
  ```

  - **Why:** `fzf` exits 130 on ESC, 1 on no match; `pipefail` propagates non-zero, `set -e` exits script immediately (before the `if ((${#pkgNames[@]}))` guard), not via `terminate`. User expects cancel to be silent.
  - **Fix:**

  ```bash
  mapfile -t pkgNames < <(pacman -Slq | fzf "${fzf_args[@]}" || true)
  # or
  if ! mapfile -t pkgNames < <(pacman -Slq | fzf "${fzf_args[@]}"); then
    exit 0
  fi
  ```

- **Undeclared `pacman` / `sudo` runtime deps** — declares `fzf`/`updatedb` but invokes `pacman -Slq`/`sudo pacman -S`/`pacman -Sii` preview; on non-Arch or minimal container `checkDeps` will not prompt install and script fails with `pacman: not found`. For Arch-only tool this is acceptable but worth noting as `pacman` is distro-specific.

#### Minor / style

- `fzf_args` preview `pacman -Sii {1}` — `{1}` is first field (pkg name) but `pacman -Slq` outputs bare names without repo prefix, so preview is effectively `pacman -Sii <pkg>` correct; quoting inside `--preview` single quotes intentional.
- `sudo updatedb &>/dev/null || true` — swallows failure on systems without `plocate`/`mlocate`; fine per declared fallback `plocate`.

#### Confirmed correct (potential false positives)

- `fzf` + `updatedb (plocate)` alternation/override — valid per house brief §2, not flagged.
- `set -eo pipefail` + `trap` + `source` + `checkDeps` — house style compliant.
- No `cmdarg` flags defined — allowed (pure positional interactive script), not flagged.

---

### `trunc`

**Path:** `/home/othman/scripts/trunc`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Truncates a string to a given length or adds elipses.
**Declared dependencies:** none
**Verdict:** `Clean`

#### Critical bugs

None found.

#### Design issues

None found.

#### Minor / style

- **Positional via `${argv[*]}` collapses args with IFS-space:**

  ```bash
  # trunc:34
  text="${argv[*]}"
  ```

  - **Why:** `trunc -l 10 "hello world" "foo"` joins with single space to `"hello world foo"`; if caller expects separate handling or preserves multiple spaces/newlines, they are normalized. For this utility (truncate a single string) it's reasonable but `text="${argv[*]}"` vs `text="${*}"` vs `text="$(printf '%s ' "${argv[@]}")"` all collapse. Acceptable, just noted.
  - **Fix if needed:** Document as "joins all positionals with space" or use `text="${argv[0]}"` for single-string mode.

- **Limit parsing via arithmetic expansion without validation:**

  ```bash
  # trunc:36
  limit=$((cmdarg_cfg['limit']))
  ```

  - **Why:** Non-numeric `limit` (e.g., `trunc -l foo "bar"`) fails with `bash: foo: unrecq...` under `set -e` — `cmdarg` could declare validator `isPositiveInt`.
  - **Fix:** `cmdarg "l:" "limit" "The limit to trunc the string" "" isPositiveInt` per house brief §5.

- **Ellipsis clamp logic** — `trunc:38` `((limit > ${#ellipsis})) || limit=${#ellipsis}` — intentional clamp to ellipsis length, but comment typo "elipses" in description.

#### Confirmed correct (potential false positives)

- `set -eo pipefail` + `trap` + `include` + `checkDeps` — correct.
- `cmdarg "l:"` required (no default) + `cmdarg "e?"` optional default `"..."` — correct `:` vs `?` semantics per house brief §5.
- `awk -v max="${limit}" -v ell="${ellipsis}"` quoted safely, `substr` handles `cut <0` guard — correct edge case handling.
- No dependency block — prints `x-none` and `checkDeps` returns 0 per house brief §2/§6, not flagged.

---

### `tabs2spaces`

**Path:** `/home/othman/scripts/tabs2spaces`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Converts tabs into 2 spaces
**Declared dependencies:** none
**Verdict:** `Needs fixes`

#### Critical bugs

None found.

#### Design issues

- **Bypasses `cmdarg` positional contract (`$#`/`$1` vs `argv`/`argc`) and mishandles `--`:**

  ```bash
  # tabs2spaces:30-35
  if [[ $# -eq 0 || $1 == "-" ]]; then
    str=$(cat)
  elif [[ -f "$1" ]]; then
    sed 's|\t|  |g' -i "$1"
    exit 0
  else
    str="$*"
  fi
  ```

  - **Why:** After `cmdarg_parse "$@"`, house style mandates `argv`/`argc` for positionals (supports `--` sentinel, bare `-` as positional). Here `$#` still holds original `"$@"` including parsed flags (none currently, but future flag would break), and `"$1"` is not `--`-aware. Example `tabs2spaces -- myfile` would treat `--` as file.
  - **Fix:**

  ```bash
  if ((argc == 0)) || [[ "${argv[0]}" == "-" ]]; then
    str=$(cat)
  elif [[ -f "${argv[0]}" ]]; then
    sed 's|\t|  |g' -i "${argv[0]}"
    exit 0
  else
    printf -v str '%s ' "${argv[@]}"; str=${str% }
  fi
  ```

- **`sed -i` without backup is GNU-only (fails on BSD/macOS):**

  ```bash
  # tabs2spaces:33
  sed 's|\t|  |g' -i "$1"
  ```

  - **Why:** BSD `sed -i` requires argument (`-i ''`). Script would error on macOS.
  - **Fix:** `sed -i.bak 's|\t|  |g' "$1" && rm -f "$1.bak"` or `perl -i -pe 's/\t/  /g'`.

- **Only first positional handled** — `tabs2spaces:32` tests `"$1"`/`"${argv[0]}"`; `tabs2spaces a b c` silently ignores `b c`. Should loop or error on `argc >1`.

#### Minor / style

- `${str//$'\t'/  }` expansion in `tabs2spaces:45` uses double-space literal; comment above references `sed` equivalence — correct but could use `${str//$'\t'/  }` is fine.
- `printf ""` in `tabs2spaces:40` — should be `printf ''` or `exit 0`.
- Empty input handling: `cat` without `2>/dev/null` may block; fine for filter semantics.

#### Confirmed correct (potential false positives)

- `set -eo pipefail` + `trap` + `source "$(include ...)"` + `checkDeps` — correct.
- No dependency block — allowed per house brief §6.
- Direct `sed 's|\t|  |g'` for tab replacement — `tr` alternative not required.

---

### `editwhich`

**Path:** `/home/othman/scripts/editwhich`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Opens a command's source file in the specified or default editor
**Declared dependencies:** `which`, `nano`
**Verdict:** `Critical bug`

#### Critical bugs

- **Positional mismatch: reads `argv[0]` for error message but resolves `"$1"` — breaks with any flags or `--` sentinel:**

  ```bash
  # editwhich:31-36
  file="${argv[0]}"
  [[ -z "${file}" ]] && log-error "No valid input was given!"

  EDITOR="${EDITOR:-nano}"

  if path="$(command -v "$1" 2>/dev/null)"; then
    cd "$(dirname "${path}")" || log-error "Failed to change directory"
    "${EDITOR}" "${path}"
  else
    log-error "Script ${file} doesn't exist!"
  fi
  ```

  - **What happens:** `editwhich -- ls` — `argv[0]="ls"` but `"$1"="--"` → `command -v "--"` fails, script reports `Script ls doesn't exist!` even though `ls` exists. With single arg `editwhich ls` it accidentally works because `"$1"=="ls"==argv[0]`, masking the bug.
  - **Why wrong:** Violates house brief §5 (`argv`/`argc` after `cmdarg_parse`), and `$1` bypasses `cmdarg` sentinel handling.
  - **Fix:**

  ```bash
  file="${argv[0]}"
  [[ -z "${file}" ]] && log-error "No valid input was given!"
  if path="$(command -v "${file}" 2>/dev/null)"; then
    "${EDITOR:-nano}" "${path}"
  else
    log-error "Script ${file} doesn't exist!"
  fi
  ```

#### Design issues

- **Unnecessary `cd "$(dirname "${path}")"` side effect before edit:**

  ```bash
  # editwhich:37
  cd "$(dirname "${path}")" || log-error "Failed to change directory"
  ```

  - **Why:** Changes script's CWD before invoking editor; editor's relative file dialogs/save-as start in exe's dir unexpectedly. Parent shell CWD unaffected (subshell), but if `EDITOR` is `code --wait` or `hx`, workspace detection may use CWD. Should just `exec "${EDITOR}" "${path}"` without `cd`.
  - **Fix:** Remove `cd` line entirely.

- **EDITOR with arguments fails due to quoting:**

  ```bash
  # editwhich:38
  "${EDITOR}" "${path}"
  ```

  - **Why:** `EDITOR="code --wait"` → Bash looks for binary literally named `code --wait`. Common editors pass args via `EDITOR`.
  - **Fix:** `eval "\"${EDITOR}\" \"\${path}\""` or `bash -c '"$1" "$2"' _ "${EDITOR}" "${path}"` or split: `read -ra editorArr <<<"${EDITOR}"` then `"${editorArr[@]}" "${path}"`. For minimal, document single-word only.

- **Declared dependency `which` unused (uses `command -v`)** — not harmful but `checkDep` will install `which` unnecessarily; should declare `which | command`? Actually `command -v` is builtin, `which` not needed. Remove or change to `# - which | command`.

#### Minor / style

- `log-error` vs `logError` mixing — standalone `log-error` correct per house brief §3, fine.
- No `--help` flag collides with filename `-h`? `cmdarg` reserves `-h`; `editwhich -h` would show usage not edit `h` binary — documented behavior.

#### Confirmed correct (potential false positives)

- `set -eo pipefail` + `trap` + `source "$(include ...)"` + `checkDeps` + `cmdarg_info` + `cmdarg_parse` — compliant with `clangc` reference order.
- `trap 'exit 1' SIGUSR1` not flagged as suspicious per house brief §4.
- `include` path resolution via `realpath -m` — intentional, not flagged.

---

## Batch Summary

- **Scripts reviewed:** 10 / 10
- **Critical bugs:** `rmbranch` (remote deletion no-op `git branch -D --remote`; also `$1` vs `argv` single-target loss), `editwhich` (resolves `$1` not `argv[0]`, breaks `--` sentinel; unnecessary `cd` is design but `$1` bug is critical)
- **Design issues worth escalating:** `tabs2spaces` (GNU-only `sed -i`, ignores `argv`/`argc` + `--`, only first file handled), `make-signature` (unquoted `${deps}` splits `|`/`()` deps), `down-ext-file` (flat-array `jq '.[]'` vs `{recommendations:[]}`, fragile `cut -d '.'`), `image-text` (`&& log-success` masks `set -e` on magick failure), `pkg-install` (`fzf` cancel aborts via `pipefail`/`set -e`)
- **Cross-cutting patterns observed in this batch** (same bug/pattern repeated across multiple scripts in this batch only; batch-level, not repo-wide):
  - **Positional anti-pattern (`$1`/`$#`/`$*` after `cmdarg_parse`)** — `rmbranch:54`, `fzf-preview:32`, `tabs2spaces:30-35`, `editwhich:36`, `trunc:34` (`${argv[*]}` is at least argv-aware but still joins) — 5/10 scripts bypass `argv`/`argc` contract (§5), losing `--` sentinel and bare `-` handling. Batch-wide fix: enforce `((argc ...))` / `"${argv[@]}"` / `"${argv[0]}"` exclusively after parse.
  - **Undeclared external viewers/filters** — `rmbranch` omits `rg`/`gum` (relies on PATH hook for repo internals but not externals), `fzf-preview` assumes `file`/`head` (coreutils-exempt) but `rmbranch` case is genuine. Pattern suggests template omits non-git tools.
  - **`set -e` + interactive pipe interaction** — `pkg-install:47` (`pacman | fzf` + `pipefail`), `fzf-preview:32` (`file` + `set -e`), `image-text:50` (`magick && log-success` suppresses `set -e`) all mishandle `set -eo pipefail` with cancellable/interactive commands.
  - **Brittle string splitting on `|`/`.`/space** — `make-signature:50` (`for dep in ${deps}`), `down-ext-file:45` (`cut -d '.'`), `get-unique:47` (`tr ' ' '\n'`) all assume single-delimiter without quoting/escaping.
  - **GNU-only `sed -i` / `mktemp` trap quoting** — `tabs2spaces:33` and `get-unique:79` show small portability/nits batch theme.
- **Open questions** (design intent unclear, needs the repo owner's input rather than a guess):
  - `rmbranch`: Intended remote deletion — `git push --delete` vs `git branch -d -r`? Confirm whether script should also prune after push (`git fetch --prune`) and whether `gum` is required or fallback to `yesNo`/`select` when `gum` absent?
  - `down-ext-file`: Should it support both plain array and `extensions.json` `{ "recommendations": [] }` shape, and should `publisher.extension` validation allow scoped names (e.g., `ms-vscode.cmake-tools` with hyphen)?
  - `make-signature`: Intended input format for `deps` — space-separated list vs comma-separated vs multiple `argv` entries? Determines fix for `for dep in ${deps}`.
  - `image-text`: Should `name` positional fallback be re-enabled (make `cmdarg "n?"` default `""` to allow `image-text myname -m "hi"`), or is positional form deprecated?
  - `tabs2spaces`: Should file-in-place mode support multiple files (`tabs2spaces a b`) or explicitly reject `argc >1`? And is BSD portability required or is GNU-only acceptable per repo's Arch focus?
  - `fzf-preview`: Should missing `target` be silent (`exit 0`) or show `file` fallback? Affects `set -e` guard choice.
  - `pkg-install`/`rmbranch`: On `fzf`/`gum` cancel, should script `exit 0` (clean cancel) or `log-warning`? Current `set -e` aborts with non-zero, which may be caught by caller trap.

---

## Evidence Appendix (optional — selected raw excerpts)

```bash
# rmbranch deps extraction (only git declared):
$ get-deps /home/othman/scripts/rmbranch
git

# rmbranch critical: remote delete is local tracking delete only
$ grep -n "branch -D --remote" /home/othman/scripts/rmbranch
86:    git branch -D --remote "origin/${branch}" 2>/dev/null ||

# editwhich positional bug:
$ sed -n '31,36p' /home/othman/scripts/editwhich
file="${argv[0]}"
[[ -z "${file}" ]] && log-error "No valid input was given!"
EDITOR="${EDITOR:-nano}"
if path="$(command -v "$1" 2>/dev/null)"; then

# tabs2spaces bypasses argv:
$ sed -n '30,35p' /home/othman/scripts/tabs2spaces
if [[ $# -eq 0 || $1 == "-" ]]; then

# image-text && masks set -e
$ sed -n '50,59p' /home/othman/scripts/image-text
magick -size "${width}x${height}" \
  "xc:${background}" \
  ...
  "${name}.${extension}" &&
  log-success "Created image '${name}.${extension}' successfully"

# pkg-install pipefail+f zf
$ sed -n '47p' /home/othman/scripts/pkg-install
mapfile -t pkgNames < <(pacman -Slq | fzf "${fzf_args[@]}")

# down-ext-file cut fragility
$ sed -n '45,46p' /home/othman/scripts/down-ext-file
  publisher=$(echo "${extension}" | cut -d '.' -f 1)
  extensionName=$(echo "${extension}" | cut -d '.' -f 2)
```
