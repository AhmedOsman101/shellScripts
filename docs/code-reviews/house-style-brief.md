# House Style Brief — scripts repo (prepend to every subagent prompt)

> Half-page flat facts. If a pattern you're about to flag matches a line here, it's not a bug.
> Fill in the House Style Reference section of the batch template in your own words before reviewing.

### 1. `include` — path resolution

- `SCRIPTS_DIR="${HOME}/scripts"`; fallback `scripts_dir="$(dirname -- "${BASH_SOURCE[0]}")"` if not a directory.
- Resolved as `realpath -m "${script_dir}/$1"`; echoes the absolute path **only if the file exists**.
- Usage is always `source "$(include "lib/helpers.sh")"` (or `lib/cmdarg.sh`, `check-deps`, etc.). Don't flag the `include` indirection or the `realpath -m` as fragile — it's intentional.

### 2. Dependency block — `checkDep` semantics

- Dependencies live between `# --- DEPENDENCIES --- #` and `# --- END SIGNATURE --- #`, one per line as `# - exe | alt (pkg-override)`.
- `checkDep` (from `check-deps`) splits on `|` and `Trim`s, takes the bare exe name (`awk '{print $1}'`), runs `command -v` on each alternative in order; **if any alternative is found it returns 0 (satisfied, nothing to install)**.
- Only if none are found does it fall back to the first field as `exeName` and extracts an optional parenthesized override via `grep -oP '$\K[^)]*(?=$)'` as `pkgName`; it echoes `pkgName` if present else `exeName` for `installDep` -> `getPackageManager`.
- Therefore `fd | fdfind (fd-find)`, `xxh3sum (xxhash) | xxhsum (xxhash) | sha1sum (coreutils)` etc. are **correct** — pipe is fallback, parens is package-name override. Don't flag them as syntax errors.
- `getDeps`/`get-deps` extraction is `sed -n '/# --- DEPENDENCIES --- #/,/# --- END SIGNATURE --- #/{/\# - /p;}' | sed 's|# - ||g'`; if no block, it prints `x-none` and `checkDeps` returns 0.

### 3. Logging — two layers, both intentional

- **Primary interface:** standalone scripts `log-debug`, `log-info`, `log-warning`, `log-error`, `log-success` plus dispatcher `log.sh`. Every repo script calls `log-error` / `log-success` etc. as commands.
- `log.sh` maps `LEVEL -> (printPurple/printMagenta/printGreen/printYellow/printRed)` via `LEVEL_COLORS` and `LEVEL_OUTPUT` (1=stdout, 2=stderr), then `colorOnlyPrefix`.
- **Fallback layer:** `lib/helpers.sh` defines camelCase `logDebug`, `logSuccess`, `logInfo`, `logWarning`, `logError`, `logSafeError` (and `log-warning` etc. delegate to them). These are for in-process use without a fork. They are **not dead code** when no script calls `logSuccess` directly — `log-success` is the caller.
- Color helpers live in `lib/loggers.sh` (`printRed`, `printGreen`, `printPurple`, `hex_to_rgb`, `printer`, `stylePrint`, `colorOnlyPrefix`, `supportsColor` checking `NO_COLOR`, `CI`, TTY, `TERM`).
- Never flag `log-success` vs `logSuccess` naming as a bug; both are canonical.

### 4. `trap 'exit 1' SIGUSR1` + `kill -SIGUSR1 "${PPID}"` — intentional propagation

- Every script starts with `set -eo pipefail` and `trap 'exit 1' SIGUSR1`.
- **Only** `log-error` sends the signal: `kill -SIGUSR1 "${PPID}" &>/dev/null || true; wait "${PPID}" &>/dev/null || true` — guarded by `! isInteractiveShell && ! "${noKill:-false}"` and flags `--no-kill` / `--no-error` / `--safe` (`--safe` = both).
- This kills the parent that trapped SIGUSR1, propagating a fatal error up the call chain without the parent needing to check exit codes. It's deliberate, not leftover debug. Don't flag the trap alone as suspicious, and don't require every script to contain a matching `kill`.

### 5. `cmdarg.sh` — argument-parsing contract (what "correct" looks like)

- `source "$(include "lib/cmdarg.sh")"` then:
  ```bash
  cmdarg_info "header" "$(get-desc "$0")"
  declare -a myarr; declare -A myhash   # must exist BEFORE cmdarg for [] / {}
  cmdarg "v" "verbose" "Enable verbose output"          # boolean -> defaults "false", set to literal `true` command when present
  cmdarg "m:" "message" "Text to write"                 # required string (":" + no default -> required)
  cmdarg "o?" "output" "Output file" ""                # optional string ("?")
  cmdarg "a?[]" "myarr" "Values"                        # optional array
  cmdarg "H?{}" "myhash" "Key=val"                      # optional hash
  cmdarg_parse "$@"                                     # exactly this form
  # then use:
  verbose="${cmdarg_cfg['verbose']}"; if ${cmdarg_cfg['verbose']}; then ...; fi
  message="${cmdarg_cfg['message']}"
  # positionals in "${argv[@]}" / "${argc}"
  ```
- Flags: single letter `N` + `:` required / `?` optional + optional `[]` or `{}` type suffix. `-h` / `--help` is reserved (auto-usage via `cmdarg_helpers['usage']`). Supports `-x val`, `--long val`, `--long=val`, `--` sentinel, bare `-` as positional.
- `CMDARG_ERROR_BEHAVIOR=return` by default; `cmdarg_parse` returns on error and the trap/kill chain surfaces it. Don't flag `cmdarg_cfg['x']` quoted-string vs boolean literal — booleans are literally `true`/`false`.

### 6. `get-desc` / `get-deps` — signature-block parsing is optional

- Both parse `# --- DESCRIPTION --- #` … `# --- DEPENDENCIES --- #` … `# --- END SIGNATURE --- #` comment blocks.
- `get-desc`: `sed -n '/# --- DESCRIPTION --- #/{:loop; n; /# --- DEPENDENCIES --- #/q; /# --- END SIGNATURE --- #/q; /\# /p; b loop}' | sed 's|# ||g'`. `get-deps`: `sed -n '/# --- DEPENDENCIES --- #/,/# --- END SIGNATURE --- #/{/\# - /p; /# --- END SIGNATURE --- #/q}' | replace.sh '# - ' ''`.
- Missing `DESCRIPTION` or `DEPENDENCIES` section is **allowed** — scripts with `# --- DEPENDENCIES --- #` immediately followed by `# --- END SIGNATURE --- #` (or no deps) are correct. Don't flag "missing description" as a bug.
- `get-desc` tolerates either DEPENDENCIES or END SIGNATURE as terminator.

### 7. `init.sh` / `hooks/path.sh` — PATH registration, not per-script concern

- `init.sh` verifies `SCRIPTS_DIR` (default `~/scripts`), ensures `fd` (or prompts to symlink `fdfind -> fd`), verifies `hooks/path.sh` exists, then idempotently appends `[[ -s "${SCRIPTS_DIR}/hooks/path.sh" ]] && source "${SCRIPTS_DIR}/hooks/path.sh"` to `~/.bashrc` (bash) or `${ZDOTDIR:-$HOME}/.zshrc` (zsh), or the list passed via `declare -a shells; cmdarg "s?[]" "shells" …`.
- `hooks/path.sh` (sourced at shell startup, not executed) caches executable discovery: `fd --strip-cwd-prefix=always --no-ignore-vcs -t x . --exclude .git --exclude .venv …` (+ `$SCRIPTS_HOOK_EXCLUDE`), writes to `/tmp/path-hook.cache`, rescans only when `find "${SCRIPTS_DIR}" -type d -newer "${__cacheFile}"` finds newer dirs, then adds each executable's directory to `PATH` once (`:":${PATH}:"` guard), then `unset`s all temps. Scripts **do not** need to handle their own PATH setup — that's the hook's job.

### 8. `clangc` — canonical positive example

- `set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `source "$(include "lib/cmdarg.sh")"` + `source "$(include "lib/compile.sh")"` + `source "$(include "check-deps")"` + `checkDeps "$0"` in that order.
- `cmdarg_info "header" "$(get-desc "$0")"`; pre-declares `declare -a compiler_args`; defines `cmdarg "c"` (boolean compile), `cmdarg "o?"` (optional string with "" default), `cmdarg "a?[]"` (array), `cmdarg "q"` (boolean quiet); calls `cmdarg_parse "$@"`; reads `cmdarg_cfg` literally (`"${cmdarg_cfg['compile']}"`); validates `((argc < 1)) && log-error …`; builds arrays safely, delegates to `compile_and_run` with namerefs (`'clang' 'default_flags' 'files' … 'compiler_args'`). Copy this shape when judging other scripts.
