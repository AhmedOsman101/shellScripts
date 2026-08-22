# Batch Review: 15 of 22

**Scripts in this batch:** `external/colortest`, `dotfiles.sh`, `renamefile`, `cppc`, `get-ext`, `daily.sh`, `banner`, `blank-image`, `lua/timewarp.lua`, `get-deps`
**Batch composition:** [small-grab] grab-bag (10 scripts, 655 lines, under 12 cap, no large >150 except colortest 131). Mix of external, dotfiles, renamefile, cppc, get-*, daily, banner — no single family, header note grab-bag.
**Reviewer:** subagent-15
**Date:** 2026-08-21

---

## House Style Reference (do not flag these as bugs)

Before reviewing, confirm you've internalized these repo conventions. Restate them here in one line each to prove the context loaded correctly:

- Dependency declaration format (`# - binary | binary2 (pkg-override)`) and how `checkDep` resolves it: Deps live between `# --- DEPENDENCIES --- #` and `# --- END SIGNATURE --- #` as `# - exe | alt (pkg-override)`; `checkDep` splits on `|`, `Trim`s, takes bare exe (`awk '{print $1}'`), tries `command -v` each alt in order and returns 0 if any found else echoes `(pkg-override)` if present else first exe for `getPackageManager`/`installDep`.
- Logging convention: `log-*` wrapper scripts are primary, camelCase `log*` functions in `lib/helpers.sh` are fallback: Executables `log-debug/info/warning/error/success` + dispatcher `log.sh` (LEVEL→printPurple/Magenta/Green/Yellow/Red via LEVEL_COLORS/LEVEL_OUTPUT + `colorOnlyPrefix`) are primary fork interface; `lib/helpers.sh` camelCase `logDebug/Success/Info/Warning/Error/SafeError` + `lib/loggers.sh` `print*`/`hex_to_rgb`/`supportsColor` (NO_COLOR/CI/TTY/TERM) are in-process fallback, both canonical.
- `trap 'exit 1' SIGUSR1` + `kill -SIGUSR1 "${PPID}"` propagation chain purpose: Every script `set -eo pipefail` + `trap 'exit 1' SIGUSR1`; only `log-error` sends `kill -SIGUSR1 "${PPID}" &>/dev/null || true; wait "${PPID}" &>/dev/null || true` guarded by `! isInteractiveShell && ! "${noKill:-false}"` (`--no-kill/--no-error/--safe`), propagating fatal up the call chain without parent exit-code checks.
- `cmdarg.sh` argument-parsing pattern used across scripts: `source "$(include "lib/cmdarg.sh")"` → `cmdarg_info "header" "$(get-desc "$0")"` → pre-`declare -a/ -A` for `[]/{}` → `cmdarg "v" "verbose" "desc"` (`:` required `?` optional `[]` array `{} `hash, `-h/--help` reserved) → `cmdarg_parse "$@"` → read `cmdarg_cfg['key']` (booleans literal `true`/`false` commands, use `if ${cfg['x']}; then`) and `argv`/`argc` positionals.
- `get-desc` / `get-deps` signature-block parsing rules: Both `sed`-parse `# --- DESCRIPTION --- #` … `# --- DEPENDENCIES --- #` … `# --- END SIGNATURE --- #`; `get-desc` loops `n` until DEPENDENCIES or END SIGNATURE printing `/# /p` then `s|# ||g`; `get-deps` `sed -n '/DEPENDENCIES/,/END SIGNATURE/{/# - /p; /END/q}' | sed 's|# - ||g'` (or `replace.sh` variant) `| grep -v " --- " || echo x-none`; missing sections allowed, not a bug.
- `init.sh` / `hooks/path.sh` symlink and PATH-registration workflow: `init.sh` verifies `SCRIPTS_DIR` (~/scripts), ensures `fd|fdfind` symlink, verifies `hooks/path.sh`, then idempotently appends `[[ -s "${SCRIPTS_DIR}/hooks/path.sh" ]] && source ...` to `~/.bashrc` or `${ZDOTDIR:-$HOME}/.zshrc` (or ` -s` array); `hooks/path.sh` sourced at shell start caches `fd -t x --exclude .git/.venv/...` to `/tmp/path-hook.cache`, rescans only when `find -newer` finds newer dirs, adds each exe's dir to `PATH` once with `:*: ` guard then `unset`s temps.
- Reference pattern from `clangc` (what "correct" looks like in this repo): `set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `source "$(include "lib/cmdarg.sh")"` + `lib/compile.sh` + `check-deps` + `checkDeps "$0"` in order; `cmdarg_info` + pre-`declare -a compiler_args` + `cmdarg c/ o?/ a?[]/ q` + `cmdarg_parse "$@"` + `((argc<1)) && log-error` + file loops + `default_flags` array + `compile_and_run 'clang' 'default_flags' 'files' "${compile}" "${quiet}" "${output}" 'compiler_args'` via namerefs.

---

## Script Reviews

### `external/colortest`

**Path:** `/home/othman/scripts/external/colortest`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Colors testing (vendored `colortest.textart` from NNBnh https://github.com/NNBnh/nnbs-text-art/blob/main/color/colortest.textart)
**Declared dependencies:** none (no signature block; external GPLv3 text-art)
**Verdict:** `Clean`

#### Critical bugs

None found.

#### Design issues

None found — divergences from house style (no `set -eo pipefail`, no `trap`, no `include`/`checkDeps`/`cmdarg`/`log-*`, raw `\033[` escapes, uppercase `TEXT`/`SEPARATOR` vars, `for x in ${VAR}` unquoted splits) are intentional for vendored external code and must not be refactored to repo style.

#### Minor / style

- Typo `lable` vs `label` used consistently (lines 31,41,46,75,95,99,105) — preserved from upstream, not a repo bug.
- `[[ "${#TEXT}" -ge '4' ]]` quotes numeric literal (line 45); `PADDING`/`print`/`separator`/`newline` used uninitialized (rely on empty default, no `set -u`) — tolerable for upstream script.

#### Confirmed correct (potential false positives)

- Raw ANSI `\033[0;...m` without `lib/loggers.sh` `print*` is correct here: external text-art directly emits escapes, not a logging bypass.
- Positional defaults `TEXT="${1:- *** }"` etc. (lines 23-28) without `cmdarg` is correct for external minimal CLI, not a missing-arg-parse bug.
- No deps block / no `checkDeps` is correct: vendored scripts outside repo trust boundary are not managed by `getDeps`/`installDep`.

---

### `dotfiles.sh`

**Path:** `/home/othman/scripts/dotfiles.sh`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Selects or specifies a configuration directory from TUCKR_DIR with interactive filtering
**Declared dependencies:** `eza`, `fzf`, `fd | fdfind (fd-find)`
**Verdict:** `Needs fixes`

#### Critical bugs

- **What happens:** `cd` uses `TUCKR_HOME` (line 35) but later search uses `TUCKR_DIR` (line 79); if user sets only canonical `TUCKR_DIR` (or the two differ), `cd "${TUCKR_HOME}/dotfiles"` fails to `/dotfiles` or wrong dir and `terminate` fires even though `fd-by-depth` path would succeed; inconsistent `PATH` after `include` resolution.
- **Where:**

```bash
cd "${TUCKR_HOME}/dotfiles" || terminate
# ...
fullpath="$(fd-by-depth "${app}" --hidden --type d --min-depth=2 --max-depth=4 "${TUCKR_DIR}/${app}" | tail -n 1)"
[[ -z "${fullpath}" ]] && fullpath="${TUCKR_DIR}/${app}"
```

- **Why it's wrong:** Two different env var names for the same tuckr root — no fallback, no validation, no default. Under `set -e` a missing `TUCKR_HOME` aborts before `TUCKR_DIR` is ever consulted; silent incoherence if both set differently.
- **Fix:**

```bash
: "${TUCKR_DIR:=${TUCKR_HOME:-${HOME}/.config/tuckr}}"
[[ -d "${TUCKR_DIR}" ]] || log-error "TUCKR_DIR not found: ${TUCKR_DIR}"
cd "${TUCKR_DIR}/dotfiles" || { log-error "dotfiles dir missing in ${TUCKR_DIR}"; }
# and later consistently:
fullpath="$(fd-by-depth "${app}" --hidden --type d --min-depth=2 --max-depth=4 "${TUCKR_DIR}/${app}" | tail -n 1)"
```

#### Design issues

- **Undocumented runtime deps:** `fd-by-depth` (repo wrapper around `fd.sh` + `awk`/`sort`/`cut`), `eza` preview `bat`/`mdcat`/`glow`/`file` fallbacks, and `fzfPreview` helpers not declared. If `fd-by-depth` missing, script fails at line 79 despite `checkDeps` passing.
  **Fix:** Add `# - fd-by-depth` (repo-local, but at least document) or switch to plain `fd`; add optional notes for `bat | cat` fallbacks; or keep `eza`/`fzf`/`fd` as hard deps and treat `bat`/`glow`/`mdcat` as soft fallbacks with `command -v` already done in preview.

- **Fragile `eza | cut` parsing:** `eza --only-dirs --icons=always --all -1 --sort name | cut -d " " -f 2-` assumes icon + space prefix; breaks if `eza` changes format or icon contains spaces. Not critical but distro-specific.
  **Fix:** Use `eza --only-dirs --all -1 --color=never` for selection and separate icon path, or `fd --type d` directly.

- **Idiom divergence:** `cd "Configs"` hard-codes capital `C` layout inside `dotfiles`; not portable if repo uses lowercase. Should validate existence.

#### Minor / style

- `if "${cancelled}"; then` quoted boolean works (`"false"` still executes `false`) but house style is unquoted `if ${cancelled}; then` or `if ${cmdarg_cfg['x']}; then`. Keep unquoted for consistency.
- `fzfPreview` constructed via `cat <<'EOF'` command substitution adds trailing newline; harmless.
- `app="${argv[0]}"` without `:?` — already guarded by `((argc<1)) || [[ -z "${argv[0]}" ]]`.

#### Confirmed correct (potential false positives)

- `source "$(include "lib/helpers.sh")"` + `lib/cmdarg.sh` + `check-deps` + `checkDeps "$0"` + `cmdarg_info` + `cmdarg_parse "$@"` order slightly different from `clangc` (helpers before cmdarg) but still correct per house style; `include` indirection via `realpath -m` is intentional, not fragile.
- `cancelled=false` + `|| cancelled=true` + `if "${cancelled}"` using `true`/`false` commands is canonical boolean pattern, not a string-comparison bug (per house brief `boolean -> literal true command`).
- `trap 'exit 1' SIGUSR1` with `log-error` → `kill -SIGUSR1` propagation is intentional, not missing `kill`.
- `fd | fdfind (fd-find)` pipe fallback in deps is correct per `checkDep` splitting logic.

---

### `renamefile`

**Path:** `/home/othman/scripts/renamefile`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Renames a file
**Declared dependencies:** none (empty block)
**Verdict:** `Needs fixes`

#### Critical bugs

- **What happens:** Same-file check `[[ "${old}" == "${new}" ]]` is unreachable when `oldDir == newDir` (which is true whenever `old == new`), so `renamefile /tmp/a/file.js /tmp/a/file.js` does not early-exit with `log-info ... are the same file`; instead falls into `elif [[ "${oldDir}" == "${newDir}" ]]` → `cmdArray+=("${new}")` → executes `mvp -i "/tmp/a/file.js" "/tmp/a/file.js"` which errors/prompts instead of graceful no-op.
- **Where:**

```bash
if [[ "${oldDir}" != '.' && "${newDir}" == '.' ]]; then
  cmdArray+=("${oldDir}/${newBase}")
elif [[ "${oldDir}" == "${newDir}" ]]; then
  cmdArray+=("${new}")
elif [[ "${old}" == "${new}" ]]; then
  log-info "${old} and ${new} are the same file"
  log-debug "${oldBase} == ${newBase}"
  exit 0
else
  cmdArray+=("${new}")
fi
```

- **Why it's wrong:** Conditional ordering masks the most specific test (`old == new`) behind a more general one (`oldDir == newDir`). Classic shadowing.
- **Fix:** Move same-file guard first, before dir logic; also normalize with `realpath -m` if desired:

```bash
if [[ "${old}" == "${new}" ]]; then
  log-info "${old} and ${new} are the same file"
  log-debug "${oldBase} == ${newBase}"
  exit 0
fi
if [[ "${oldDir}" != '.' && "${newDir}" == '.' ]]; then
  cmdArray+=("${oldDir}/${newBase}")
elif [[ "${oldDir}" == "${newDir}" ]]; then
  cmdArray+=("${new}")
else
  cmdArray+=("${new}")
fi
```

#### Design issues

- **Missing dependency declaration:** Core action is `mvp` (repo script wrapping `sudo mkdir -p` + `sudo mv -f/-i`) but deps block empty → `checkDeps` prints `x-none` and never ensures `mvp` is on PATH. On fresh install without `hooks/path.sh` sourced, `mvp` not found → `set -e` abort with raw `command not found` instead of install prompt.
  **Fix:** Add `# - mvp` to deps block (repo-local dep, at least documents requirement; or switch to plain `mv` + `mkdir -p`).

- **Directory-vs-file check:** `[[ ! -f "${old}" ]]` rejects directories and symlinks to dirs; script description says "Renames a file" so intentional, but `dirname`/`basename` logic assumes file path; a directory rename would incorrectly error. If intentional, keep `-f`; if should support dirs, switch to `-e`.

#### Minor / style

- `force="${cmdarg_cfg["force"]}"` double-quoted key vs house single-quote `['force']` — functional but inconsistent.
- `if [[ "${force}" == "true" ]]; then` string comparison works but house boolean idiom is `if ${cmdarg_cfg['force']}; then` (unquoted `true` command).
- `old="${argv[0]}"` / `new="${argv[1]}"` without `argc` check — mitigated by `[[ -z "${old}" ]]` guards but clearer to `((argc <2)) && log-error "need two args"`.

#### Confirmed correct (potential false positives)

- `set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `source "$(include ...)"` + `checkDeps` + `cmdarg "f" "force"` + `cmdarg_parse "$@"` follows house `cmdarg.sh` contract; `force` boolean defaults `"false"` handled correctly.
- `declare -a cmdArray` + `"${cmdArray[@]}"` array exec is safe, not word-splitting bug.
- `log-error` for missing args correctly triggers `kill -SIGUSR1` parent kill chain per house brief, not a missing `exit`.

---

### `cppc`

**Path:** `/home/othman/scripts/cppc`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Compiles and optionally runs C++ files with customizable compiler arguments
**Declared dependencies:** `g++ (gcc)`, `xxh3sum (xxhash) | xxhsum (xxhash) | sha1sum (coreutils)`
**Verdict:** `Clean`

#### Critical bugs

None found.

#### Design issues

None found.

#### Minor / style

- `cmdarg "q" "quiet" "Supress all output"` typo `Supress` vs `Suppress` — inherited verbatim from `clangc` reference pattern, not a functional bug.
- No additional minor — matches reference exactly.

#### Confirmed correct (potential false positives)

- `source "$(include "lib/cmdarg.sh")"` → `lib/compile.sh` → `check-deps` → `checkDeps "$0"` order is canonical per `clangc` reference, not an include-order bug.
- `xxh3sum (xxhash) | xxhsum (xxhash) | sha1sum (coreutils)` pipe fallback with parenthesized package override is correct per `checkDep` semantics, not a syntax error.
- `declare -a compiler_args` pre-declared before `cmdarg "a?[]" "compiler_args"` is required by `cmdarg.sh` and correctly done.
- `((argc < 1)) && log-error` boolean short-circuit for required positionals is house-standard, not missing `if`.
- `compile_and_run` called via namerefs `'g++' 'default_flags' 'files' "${compile}" "${quiet}" "${output}" 'compiler_args'` matches `lib/compile.sh` signature; `default_flags=("-std=c++23" "-Wall" "-Wextra" "-fdiagnostics-color=always")` is safe array.
- `# shellcheck disable=SC2034` for namerefs is intentional.

---

### `get-ext`

**Path:** `/home/othman/scripts/get-ext`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Exports VS Code extensions to a JSON file with options to overwrite existing files
**Declared dependencies:** `code`, `jq`
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **Undocumented `gum` dependency:** Overwrite prompt uses `gum confirm "File: ${file} exists..." --prompt.foreground="${U_YELLOW}"` but `gum` not in deps block. If file exists and `--overwrite` not set and `gum` missing, line 54 `gum confirm` fails → under `set -e` the failing command in `if gum confirm; then` does _not_ trigger errexit (it's a condition), but then `else terminate` path is taken incorrectly; more importantly user gets no prompt and silent `No changes made` instead of clear missing-dep error.
  **Fix:** Add `# - gum` (or `# - gum | whiptail | dialog`) to deps, or fallback to `yesNo` from `lib/helpers.sh` if `gum` absent: `if command -v gum &>/dev/null; then gum confirm ...; else yesNo "overwrite ${file}?"; fi`.

- **`U_YELLOW` env leakage:** `U_YELLOW` comes from `~/.config/zsh/variables.sh` (`export U_YELLOW="#DBAC66"`), not from `lib/loggers.sh`/`helpers.sh`. In non-interactive or `daily.sh` context (`TERM=xterm`, no zsh rc), `${U_YELLOW}` expands to empty → `gum --prompt.foreground=""` uses default color; not fatal but brittle. Should default: `${U_YELLOW:-#DBAC66}` or source colors.

#### Minor / style

- Duplicated `getExtensions >"${file}"` + `log-info "${file} has been overwritten."` in both `if "${overwrite}"` and `gum confirm` branches — could DRY into helper function but not a bug.
- `overwrite="${cmdarg_cfg['overwrite']}"` then `if "${overwrite}"; then` quoted boolean works but house idiom is `if ${cmdarg_cfg['overwrite']}; then` unquoted.
- `file="${argv[0]:-extensions.json}"` default ok but no validation that target dir is writable; `getExtensions` will fail with redirection error which `set -e` will surface via `log-error` from `jq`/`code`.

#### Confirmed correct (potential false positives)

- `code | jq -R . | jq -s .` pipeline correctly builds JSON array; `mapfile -t array < <(code --list-extensions)` is safe.
- `cmdarg "o" "overwrite"` boolean flag without `:`/`?` correctly defaults `"false"` per `cmdarg.sh`, not a missing default.
- `trap 'exit 1' SIGUSR1` + `log-error`/`terminate` propagation is house-standard, not suspicious trap alone.
- `log-info` vs `log-success` distinction intentional (info for create/overwrite).

---

### `daily.sh`

**Path:** `/home/othman/scripts/daily.sh`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Creates daily Timeshift backup, exports installed packages, VS Code extensions, and unique pnpm global packages
**Declared dependencies:** `timeshift`, `sudo`
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **Multiple missing runtime deps in block:** `pacman`, `get-ext` (→ `code`/`jq`), `pnpm-ls`, `no-dups`, `notify-send`, `hostnamectl` are executed but only `timeshift`/`sudo` declared. `checkDeps "$0"` will pass on non-Arch (no `pacman`) or missing `pnpm` but script then fails mid-run with `command not found` under `set -e`.
  **Fix:** Extend deps block to `# - pacman | paru | yay` (Arch), `# - pnpm`, `# - notify-send (libnotify)`, `# - hostnamectl (systemd)` or gate each section with `command -v ... &>/dev/null || log-warning "skipping ..."`.

- **Fragile chassis detection:** `chassis="$(hostnamectl chassis)"` — `hostnamectl chassis` prints bare word on Arch (`laptop`/`desktop`/`vm`...) but on some systemd versions requires `hostnamectl status` parsing or returns `Chassis: laptop` line. Comparison `[[ "${chassis}" == "laptop" ]]` fails if output includes prefix or trailing newline/capitalization; `device` defaults to `pc` silently. Also `hostnamectl` missing on non-systemd aborts via `set -e`.
  **Fix:** `chassis="$(hostnamectl --json=short 2>/dev/null | jq -r .Chassis // hostnamectl chassis 2>/dev/null | awk '{print $NF}')"` or simpler: `chassis="$(hostnamectl chassis 2>/dev/null | tr '[:upper:]' '[:lower:]' | awk '{print $NF}')" ` and guard: `[[ "${chassis}" == *laptop* ]]`.

- **Hard-coded `DOTFILES="${HOME}/dotfiles"` + `SCRIPTS_DIR="$(dirname "${BASH_SOURCE[0]}")"`:** Diverges from `init.sh`/`helpers.sh` `SCRIPTS_DIR="${HOME}/scripts"` + `TUCKR_DIR` convention used in `dotfiles.sh`. Breaks if user relocated `SCRIPTS_DIR` or uses `XDG_CONFIG_HOME`. Should use `: "${SCRIPTS_DIR:=${HOME}/scripts}"` and `: "${DOTFILES:=${HOME}/dotfiles}"` with fallback.

- **`export TERM='xterm'` side-effect:** Overrides caller's `TERM` (e.g., `xterm-256color`, `alacritty`) for all child processes; surprising for cron-notify.

#### Minor / style

- Commented-out `SUDO_ASKPASS` timeshift line (line 43) left in file — stale.
- `pacman -Qqe >...` / `pnpm-ls >>...` no error handling if `DOTFILES` missing — will create file anyway but `pacman` failure aborts via `set -e` before `get-ext`.
- `notify-send ... &` backgrounded without `wait` — intentional for non-blocking but could be lost if script exits immediately in cron.

#### Confirmed correct (potential false positives)

- `trap 'exit 1' SIGUSR1` without `log-error` in this file is correct per house brief: trap alone is not suspicious, only `log-error` sends the signal.
- `source "$(include "check-deps")"` without `lib/helpers.sh`/`lib/cmdarg.sh` is correct for non-cmdarg daily cron script; not a missing include.
- `now` in commented timeshift command is not evaluated (comment), not an undefined var bug.

---

### `banner`

**Path:** `/home/othman/scripts/banner`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Creates a colorful framed banner in the terminal.
**Declared dependencies:** none
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **Silent invalid-color fallback:** `colorCode="$(mapColor "${color}")" || log-error "Invalid color '${color}'"` never triggers `log-error` because `mapColor` (`lib/helpers.sh:243`) prints nothing but exits 0 on unknown color (only `[[ -v colors ]] && echo ...`). Invalid input like `--color chartreuse` silently yields empty `colorCode` → `printer ""` → `((color=...))` treats `""` as 0 → black banner instead of error.
  **Fix:** Make `mapColor` return non-zero on miss or check emptiness:

```bash
colorCode="$(mapColor "${color}")"
[[ -n "${colorCode}" ]] || log-error "Invalid color '${color}'"
```

#### Minor / style

- `msg="${argv[*]}"` joins positionals with `IFS` first char — intentional for `banner hello world` but `argv[*]` inside quotes collapses args; `argv[@]` would preserve word boundaries but banner wants flattened sentence, so current is fine.
- `edge="${text//?/${frame}}"` replaces each char with full `${frame}` string; if `frame` is multi-char (`--frame "**"`), `edge` longer than `text` — cosmetic, not bug.
- `printer "${colorCode}" "$(printf "%s\n%s\n%s\n" "${edge}" "${text}" "${edge}")"` nests command substitution — okay but could use heredoc.

#### Confirmed correct (potential false positives)

- `cmdarg "f?" "frame" ... ":"` optional string with default `:` and `cmdarg "c?" "color" ... "gray"` follows `?` optional + default pattern per `cmdarg.sh`, not a required-flag bug.
- `[[ -z "${msg}" ]] && log-error "Message is required"` short-circuit guard is house-standard for required positionals without `cmdarg` `:` flag.
- `source "$(include "lib/helpers.sh")"` → `lib/cmdarg.sh` → `check-deps` → `checkDeps` order is canonical.
- No deps block is correct (only uses `mapColor`/`printer` from helpers/loggers, no external package to install).

---

### `blank-image`

**Path:** `/home/othman/scripts/blank-image`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Creates a blank image with given width, height and color
**Declared dependencies:** `magick (imagemagick)`
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **Silent failure masking via `&&`:** `magick ... && log-success "..."` under `set -eo pipefail` does not trigger errexit on `magick` failure because `&&` list suppresses `set -e`; invalid `--width abc` or missing `magick` delegating to `checkDeps` aside, a runtime `magick` error (e.g., unsupported color, permission denied, disk full) results in script exiting 0 with no output instead of `log-error`.
  **Fix:** Use explicit error handling:

```bash
magick -size "${width}x${height}" "xc:${color}" "${name}.${extension}" || log-error "Failed to create image"
log-success "Created image '${name}.${extension}' successfully"
```

- **No input validation:** `width`/`height`/`color`/`extension`/`name` accepted verbatim; helpers provide `isPositiveInt` but not sourced and not used. `magick` error messages leak raw instead of `log-error "width must be positive int"`. Acceptable for thin wrapper but fragile for cron.

- **Short flag `-t` for height** (vs expected `-h` which is reserved) is intentional per `cmdarg.sh` (`-h` reserved for help) but non-intuitive; documenting as `-t` is correct per file.

#### Minor / style

- `extension` default `png` without dot; `"${name}.${extension}"` will produce `blank.png` correctly but `name` containing `/` or `..` allows directory traversal — not validated.
- `source "$(include "lib/cmdarg.sh")"` without `lib/helpers.sh` — `isPositiveInt`/`log-error` etc. still available via `log-error` wrapper, but helpers not needed; not a bug.

#### Confirmed correct (potential false positives)

- `# - magick (imagemagick)` package override with bare `magick` exe is correct per `checkDep` `grep -oP '\(\K[^)]*(?=\))'` extraction.
- `cmdarg "w?" "width" "1280"` etc. optional strings with defaults follow house pattern (all `?` with defaults).
- `checkDeps "$0"` after sourcing `check-deps` but before `cmdarg` is acceptable order for non-`clangc` scripts.

---

### `lua/timewarp.lua`

**Path:** `/home/othman/scripts/lua/timewarp.lua`
**Declared purpose:** Relativistic time-dilation calculator (no signature block; Lua script computing `gamma = stationary/traveler`, `fraction = sqrt(1-1/gamma^2)`, `speed = c*fraction`, formatting via `sec2time`)
**Declared dependencies:** none (Lua, no bash deps block)
**Verdict:** `Needs fixes`

#### Critical bugs

- **What happens:** Invalid or missing numeric inputs cause `tonumber` → `nil`, then `gamma = stationaryTime / travelerTime` raises `attempt to perform arithmetic on a nil value` and aborts with Lua stack trace instead of user-friendly error; swapped times where `stationary < traveler` yields `gamma <1` → `fraction = sqrt(negative)` → `nan` → prints `speed nan` silently.
- **Where:**

```lua
stationaryTime = tonumber(arg[1])  -- nil if not numeric, no check
travelerTime = tonumber(arg[2])
local gamma = stationaryTime / travelerTime  -- nil arithmetic crash
local fraction = math.sqrt(1 - 1 / (gamma ^ 2))  -- negative sqrt -> nan if gamma<1
local travelerHandle = io.popen(string.format("sec2time %d", travelerTime), "r") -- %d truncates float, nil-> error
```

- **Why it's wrong:** No `isFloat`/`isPositive` validation analogous to `lib/helpers.sh` checks; no guard for `travelerTime == 0` (division by zero → inf → `fraction=1` → `speed=c` maybe okay but should be explicit) and no guard for `gamma <=1`.
- **Fix:**

```lua
stationaryTime = tonumber(arg[1])
travelerTime = tonumber(arg[2])
if not stationaryTime or not travelerTime or stationaryTime <=0 or travelerTime <=0 then
  io.stderr:write("error: both times must be positive numbers\n"); os.exit(1)
end
if stationaryTime < travelerTime then
  io.stderr:write("error: stationary time must be >= traveler time (traveler cannot experience more time)\n"); os.exit(1)
end
if travelerTime == stationaryTime then fraction=0 else fraction=math.sqrt(1 - 1/(gamma^2)) end
```

#### Design issues

- **Hard `sec2time` dependency without fallback:** `io.popen("sec2time %d", ...)` assumes `sec2time` (repo `lua/sec2time.lua` / `bin/sec2time`) on PATH; if missing, `travelerHandle:read("*a")` returns nil or handle nil, then `stationaryRelativeTime` stays nil and `string.format("To make %s...", nil, ...)` prints `"nil"` instead of error. Should check `command -v sec2time` equivalent or fallback to raw seconds.
  **Fix:** Wrap with `if not travelerRelativeTime or travelerRelativeTime=="" then travelerRelativeTime = string.format("%d seconds", travelerTime) end`.

- **`io.read("n")` without validation:** Interactive prompt `io.read("n")` leaves trailing newline and returns nil on non-numeric, not re-prompted. Should loop until valid number or use `io.read("*l")` + `tonumber`.

#### Minor / style

- `SPEED_OF_LIGHT = 299792458` as global vs `local` — harmless.
- `string.format("sec2time %d", travelerTime)` with `%d` truncates floats; should use `%f` or `%d` only after `math.floor` validation.

#### Confirmed correct (potential false positives)

- No `set -eo pipefail`/`trap`/`include`/`checkDeps` is correct for `#!/usr/bin/env lua` script, not a missing house guard.
- `io.popen(...):read("*a"):gsub("\n","")` pattern correctly trims newline; `if travelerHandle ~= nil` nil-check is appropriate Lua idiom.
- Physics formula `gamma = stationary/traveler` then `fraction = sqrt(1-1/gamma^2)` is correct Lorentz inversion, not an algebra bug when `stationary >= traveler`.

---

### `get-deps`

**Path:** `/home/othman/scripts/get-deps`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Extracts the script's dependencies
**Declared dependencies:** none
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **Uses `replace.sh` for trivial `sed` substitution:** Line 38 `replace.sh '# - ' ''` spawns a full repo script (`lib/cmdarg.sh` + `lib/helpers.sh` + `checkDeps` + `sed` escaping) to do `sed 's|# - ||g'`. Compare `lib/helpers.sh:getDeps` which uses pure `sed 's|# - ||g'` without extra fork or `checkDeps` recursion. `replace.sh` adds latency, requires `replace.sh` on PATH (circular if `hooks/path.sh` not yet sourced), and diverges from house brief's `sed` canonical extraction. If `replace.sh` missing, `get-deps` fails even though `sed` would succeed.
  **Fix:** Replace with canonical `sed`:

```bash
sed -n '/# --- DEPENDENCIES --- #/,/# --- END SIGNATURE --- #/{/\# - /p;/# --- END SIGNATURE --- #/q}' "${file}" |
  sed 's|# - ||g' |
  grep -v " --- " || echo "x-none"
```

- **No `checkDeps`/`cmdarg` parity with `get-desc`:** `get-desc` sources `lib/cmdarg.sh` + `check-deps` + uses `cmdarg_info`/`cmdarg_parse` + `argv`/`argc`; `get-deps` uses raw `if (($# !=1))` + `command -v` + `replace.sh`. Functionally equivalent but inconsistent contract; `get-deps` also lacks `log-error` guard via `checkDeps` pre-check (though it does call `log-error` binary). Not a bug but style divergence worth aligning.

#### Minor / style

- `if (($# != 1)); then` arithmetic vs `if ((argc !=1))` in `get-desc` — both work but inconsistent.
- Missing `#!/usr/bin/env bash` header safety? Actually present via implied? File starts with `#!/usr/bin/env bash` — okay.

#### Confirmed correct (potential false positives)

- `set -eo pipefail` + `trap 'exit 1' SIGUSR1` is house-standard; not flagged as suspicious trap alone per brief.
- `sed -n '/# --- DEPENDENCIES --- #/,/# --- END SIGNATURE --- #/{/\# - /p;/# --- END SIGNATURE --- #/q}'` range with early `q` is correct per house `get-deps` logic, not an off-by-one.
- `grep -v " --- " || echo "x-none"` fallback is canonical per `lib/helpers.sh:getDeps`, not a missing-error swallowing bug.
- `[[ ! -f "${file}" ]] && log-error` dispatch via `log-error` wrapper is correct without sourcing `helpers.sh` (binary exists on PATH after hook).

---

## Batch Summary

- **Scripts reviewed:** 10 / 10
- **Critical bugs:** 3 scripts
  - `dotfiles.sh` — `TUCKR_HOME` vs `TUCKR_DIR` mismatch causes deterministic `cd` abort when only canonical `TUCKR_DIR` set (line 35 vs 79)
  - `renamefile` — same-file `old == new` branch shadowed by `oldDir == newDir`, unreachable early-exit (lines 59-73)
  - `lua/timewarp.lua` — nil arithmetic crash on non-numeric input + `nan` speed when `stationary < traveler` (no `gamma <=1` guard)
- **Design issues worth escalating:** 6 scripts
  - `dotfiles.sh` — undocumented `fd-by-depth`/`bat`/`glow` deps + fragile `eza | cut -d " " -f 2-` parsing
  - `renamefile` — missing `mvp` dep declaration (empty block)
  - `get-ext` — undocumented `gum` + `U_YELLOW` env leakage
  - `daily.sh` — missing `pacman`/`pnpm-ls`/`no-dups`/`notify-send`/`hostnamectl` deps + fragile `hostnamectl chassis` parsing + hard-coded `DOTFILES`/`SCRIPTS_DIR`/`TERM=xterm`
  - `blank-image` — `&& log-success` masks `magick` failure under `set -e`
  - `get-deps` — `replace.sh` instead of `sed` for `# - ` strip (circular fork, diverges from `helpers:getDeps` canonical)
  - `banner` — `mapColor` returns empty + 0 on invalid color, so `|| log-error` never fires (silent black fallback)
- **Cross-cutting patterns observed in this batch** (same bug/pattern repeated across multiple scripts in this batch only; batch-level, not repo-wide):
  - **Missing/empty deps blocks for repo-local helpers:** `renamefile` (needs `mvp`), `dotfiles.sh` (needs `fd-by-depth`), `daily.sh` (needs `pacman`/`pnpm-ls`/`no-dups`/`notify-send`), `get-ext` (needs `gum`) — 4/10 scripts rely on repo helpers without declaring them, so `checkDeps` passes but runtime `command not found` aborts.
  - **Boolean quoting inconsistency:** `dotfiles.sh` `if "${cancelled}"`, `renamefile` `[[ "${force}" == "true" ]]`, `get-ext` `if "${overwrite}"`, `blank-image`/`daily.sh` not using `if ${cfg['x']}; then` idiom — all work (quoted `"true"` still executes `true`) but diverge from house `if ${cmdarg_cfg['x']}; then` canonical.
  - **`set -e` masking via `&&`:** `blank-image` `magick ... && log-success` and `get-ext` `printf ... | jq ...` pipelines silently mask failures; house `log-error` pattern expects `|| log-error` or explicit check.
  - **Hard-coded Arch/systemd assumptions:** `daily.sh` `pacman -Qqe` + `hostnamectl chassis` narrows portability; grab-bag batch has no other Arch-specific scripts, so not repo-wide but worth gating with `command -v` checks.
  - **Color handling split:** `banner`/`blank-image` correctly use `mapColor`/`printer` from `helpers.sh` while `external/colortest` raw `\033[` is correctly exempt as vendored — confirms two-layer logging is understood.
- **Open questions** (design intent unclear, needs the repo owner's input rather than a guess):
  - Should `dotfiles.sh` canonicalize on `TUCKR_DIR` (tuckr standard) and drop `TUCKR_HOME`, or support both with `${TUCKR_DIR:-$TUCKR_HOME}` fallback? And should `fd-by-depth` be promoted to documented dep or replaced by plain `fd`+`sort`?
  - Is `renamefile` intended to support directory renames (`-e` vs `-f` check) or strictly files? Current `-f` rejects dirs by design.
  - Should `daily.sh` `hostnamectl chassis` be hardened to `hostnamectl chassis | awk '{print $NF}' | tr '[:upper:]' '[:lower:]'` and gated for non-systemd, and should `DOTFILES`/`SCRIPTS_DIR` respect `XDG_CONFIG_HOME`/`SCRIPTS_DIR` env overrides vs hard-coded `$HOME/dotfiles`?
  - Should `lua/timewarp.lua` validate `stationary >= traveler` and error on `gamma<=1` vs clamping to `0` speed, and should `sec2time` dependency be declared/fallback to raw seconds when `bin/sec2time` missing?
  - Should `get-deps` be aligned to `lib/helpers.sh:getDeps` pure-`sed` implementation (drop `replace.sh`) for consistency with `get-desc`?

---

## Evidence Appendix

- House style brief: `/home/othman/scripts/docs/code-reviews/house-style-brief.md` (69 lines) — `include` realpath, `checkDep` pipe+parens semantics, two-layer logging, SIGUSR1 propagation, `cmdarg.sh` contract (`:` required `?` optional `[]`/`{}`), `get-desc`/`get-deps` sed range, `init.sh`/`hooks/path.sh` cache+PATH, `clangc` reference pattern.
- Core files cross-checked: `include` (26 lines, `SCRIPTS_DIR="${HOME}/scripts"` fallback, `realpath -m`, `[[ -f ]] && echo`), `lib/cmdarg.sh` (462 lines, `CMDARG_FLAG_*`, `CMDARG_TYPE_*`, `declare -A/XA cmdarg_cfg`, `if ${cfg['x']}` literal), `lib/loggers.sh` (341 lines, `hex_to_rgb`, `printer`, `supportsColor` NO_COLOR/CI/TTY, `colorOnlyPrefix`), `lib/helpers.sh` (420 lines, `getDeps` `sed 's|# - ||g'`, `mapColor`, `isPositiveInt`, `yesNo`, `hasher`), `check-deps` (175 lines, `checkDep` `awk -F "|"`, `Trim`, `grep -oP '\(\K[^)]*(?=\))'`), `log.sh` (66 lines, `LEVEL_COLORS`/`LEVEL_OUTPUT`), `get-desc` (53 lines, `sed -n '/DESCRIPTION/{:loop; n; /DEPENDENCIES/q; ...}'`), `get-deps` (39 lines, `replace.sh '# - ' ''` variant), `init.sh` (158 lines, `SCRIPTS_DIR` verify, `fd` symlink, `hooks/path.sh` append), `hooks/path.sh` (86 lines, `/tmp/path-hook.cache`, `fd -t x`, `:*: ` guard), `clangc` (67 lines, canonical `declare -a compiler_args`, `compile_and_run 'clang' ...`).
- Batch scripts read: `external/colortest` 131 lines (GPLv3, NNBnh), `dotfiles.sh` 82 lines, `renamefile` 75 lines (uses `mvp` wrapper), `cppc` 67 lines (mirrors `clangc` with `g++ -std=c++23`), `get-ext` 64 lines (`code --list-extensions | jq`), `daily.sh` 56 lines (`pacman -Qqe`, `get-ext`, `pnpm-ls`, `no-dups`, `notify-send`), `banner` 50 lines (`mapColor`+`printer`), `blank-image` 47 lines (`magick -size WxH xc:color`), `lua/timewarp.lua` 44 lines (`SPEED_OF_LIGHT=299792458`, `sec2time` popen), `get-deps` 39 lines (duplicate of core `get-deps`).
- Supporting lookups: `replace.sh` (81 lines, `sed "s|${searchEscaped}|${replaceEscaped}|g"` wrapper), `mvp` (repo helper `sudo mkdir -p`+`sudo mv`), `fd-by-depth` (wrapper `fd.sh | awk -F/ sort -n`), `sec2time` presence `bin/sec2time` + `lua/sec2time.lua`, `U_YELLOW="#DBAC66"` from `~/.config/zsh/variables.sh` (not in lib), `U_PURPLE` via env.
