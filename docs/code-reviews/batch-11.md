# Batch Review: 11 of 22

**Scripts in this batch:** `switch-branch` (167), `rename-spaces` (34), `yes.sh` (35), `gitignore-refresh` (36)
**Batch composition:** large+fillers — `switch-branch` (167) is the large tool; `rename-spaces` (34), `yes.sh` (35), `gitignore-refresh` (36) are 3 small unrelated fillers paired incidentally to fill the 272-line budget (cap 4). No shared name-family: `switch-branch`/`gitignore-refresh` are git workflow tools, `rename-spaces` is text/filename, `yes.sh` is misc. Pairing is incidental, not a deliberate family batch.
**Reviewer:** subagent-11
**Date:** 2026-08-21

---

## House Style Reference (do not flag these as bugs)

Before reviewing, confirm you've internalized these repo conventions. Restate them here in one line each to prove the context loaded correctly:

- Dependency declaration format (`# - binary | binary2 (pkg-override)`) and how `checkDep` resolves it: `checkDep` splits on `|`/Trim, takes bare exe per alternative, `command -v` each — any hit returns 0 satisfied; only if none hit does it emit first exe or parenthesized pkg override for `installDep`.
- Logging convention: `log-*` wrapper scripts are primary, camelCase `log*` functions in `lib/helpers.sh` are fallback: standalone `log-debug`/`log-info`/`log-success`/`log-warning`/`log-error` (via `log.sh` dispatcher `LEVEL_COLORS`/`LEVEL_OUTPUT`/`colorOnlyPrefix`) are the canonical call sites; `lib/helpers.sh` `logDebug`/`logSuccess`/… are in-process fallback, not dead code.
- `trap 'exit 1' SIGUSR1` + `kill -SIGUSR1 "${PPID}"` propagation chain purpose: every script traps `SIGUSR1` to `exit 1`; only `log-error` sends `kill -SIGUSR1 "${PPID}"` (guarded by `! isInteractiveShell && ! noKill`) to fatally propagate without caller checking exit codes.
- `cmdarg.sh` argument-parsing pattern used across scripts: `source "$(include "lib/cmdarg.sh")"` → pre-declare `declare -a/ -A` for `[]`/`{}` → `cmdarg "v"`/`"m:"`/`"o?"`/`"a?[]"`/`"H?{}"` → `cmdarg_info "header" "$(get-desc "$0")"` → `cmdarg_parse "$@"` exactly, then `cmdarg_cfg['key']` (booleans are literal `true`/`false` commands, `if ${cmdarg_cfg['x']}; then`).
- `get-desc` / `get-deps` signature-block parsing rules: both `sed` the `# --- DESCRIPTION --- #`…`# --- DEPENDENCIES --- #`…`# --- END SIGNATURE --- #` block; missing section is allowed — immediate `# --- END SIGNATURE --- #` or no deps prints `x-none` and is not a bug.
- `init.sh` / `hooks/path.sh` symlink and PATH-registration workflow: `init.sh` verifies `SCRIPTS_DIR`/`fd`/hook and idempotently appends `[[ -s "${SCRIPTS_DIR}/hooks/path.sh" ]] && source …` to `~/.bashrc`/`${ZDOTDIR:-$HOME}/.zshrc`; `hooks/path.sh` (sourced, not executed) caches `fd --strip-cwd-prefix=always --no-ignore-vcs -t x …` to `/tmp/path-hook.cache`, rescans only on newer dirs, adds each executable's dir to `PATH` once.
- Reference pattern from `clangc` (what "correct" looks like in this repo): `set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `source "$(include "lib/cmdarg.sh")"` + `source "$(include "lib/compile.sh")"` + `source "$(include "check-deps")"` + `checkDeps "$0"` → `cmdarg_info` → pre-`declare -a compiler_args` → `cmdarg "c"`/`"o?"`/`"a?[]"`/`"q"` → `cmdarg_parse "$@"` → `argc` check + `log-error` → arrays + nameref delegate to `compile_and_run`.

---

## Script Reviews

### `switch-branch`

**Path:** `/home/othman/scripts/switch-branch`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Switches between Git branches
**Declared dependencies:** `git`, `gum`, `rg (ripgrep)`
**Verdict:** `Critical bug`

#### Critical bugs

- **What happens:** All `/` characters are stripped from branch names, corrupting any hierarchical branch (e.g. `feature/login` → `featurelogin`). Subsequent `git checkout` fails for every namespaced branch.
- **Where:**

```bash
    tr -d "/" |
```

in context:

```bash
branchList=$(
  printf '%s\n' "${branchList}" |
    sed -e 's|^origin/||g' -e 's|^origin$||g' |
    tr -d "/" |
    no-dups | trim |
    remove-blanks
)
```

- **Why it's wrong:** `sed 's|^origin/||g'` already strips the remote prefix. `tr -d "/"` then deletes *all* remaining slashes, not just a trailing prefix — it destroys `feature/foo`, `bugfix/bar/baz`, `user/name/branch` etc. No branch with a `/` can be switched to; `git branch --list` names containing `/` are mangled before comparison and `switchBranch` never finds the real name.
- **Fix:**

```bash
# remove the tr line entirely; origin stripping is already handled by sed
branchList=$(
  printf '%s\n' "${branchList}" |
    sed -e 's|^origin/||g' -e 's|^origin$||g' |
    no-dups | trim |
    remove-blanks
)
```

If the intent was to drop an empty `origin` entry, `sed -e 's|^origin/||g' -e '/^origin$/d'` already covers it.

---

- **What happens:** Failure message in `createBranch` prints the wrong branch name (the last value of the earlier loop variable, not the requested name).
- **Where:**

```bash
    log-error "Failed to create branch '${branch}'"
```

in context:

```bash
  if "${cmd[@]}" &>"${file}"; then
    log-success "$(cat "${file}")"
    if [[ "${clearPrev}" -eq 0 ]]; then
      git rm -rf . &>/dev/null || true
    fi
  else
    log-warning "$(cat "${file}")"
    log-error "Failed to create branch '${branch}'"
  fi
```

- **Why it's wrong:** `branch` is the loop variable from `for branch in "${branches[@]}"` above; `createBranch`'s argument is `branchName`. On error the user sees "Failed to create branch '<last-existing-branch>'" instead of the requested `${branchName}`, masking the real failure.
- **Fix:**

```bash
    log-error "Failed to create branch '${branchName}'"
```

#### Design issues

- **What happens:** Current-branch filtering uses an unescaped regex interpolation; branch names containing regex metacharacters are mis-filtered.
- **Where:**

```bash
  (printf '%s\n' "${branchList}" | rg -v "^${current}$") # Add the rest, excluding the current one
```

- **Why it's wrong:** `${current}` is interpolated verbatim into `rg` regex. A branch named `fix.1`, `feat+test`, `release[1]`, `chore*` etc. makes `^${current}$` match a broader set or fail to match. Repo convention is `rg`/`grep` with `-F` for literal branch names (cf. `rmbranch` uses similar patterns, `is-git-repo` avoids regex on rev-parse).
- **Fix:**

```bash
  (printf '%s\n' "${branchList}" | rg -F -v -x "${current}") # Add the rest, excluding the current one
```

or `rg -F -v "^${current}$"` is insufficient; `-F -x` is the literal whole-line match.

---

- **What happens:** `switchBranch`/`createBranch` depend on exact interaction of `gum choose`/`gum confirm`/`gum input` exit codes and `terminate`/`log-error` trap propagation; abort paths are inconsistent and `mktemp` cleanup is deferred.
- **Where:**

```bash
file=$(mktemp -t XXXXX-"$(basename "$0")")
trap 'rm -f $file' EXIT
```

```bash
    ) || terminate
```

```bash
    ) || log-error "Failed to capture the branch name"
```

- **Why it's wrong:** `terminate` (`helpers.sh:61-65`) does `logInfo` + `exit 0` — a user ESC/cancel on `gum choose` exits 0 (success) not non-zero, masking abort. `gum confirm` non-zero is silently absorbed (`|| clearPrev=1`). `trap 'rm -f $file' EXIT` is correct per-signal (distinct from `SIGUSR1` trap), but uses unquoted `$file` in the trap string; if `mktemp` template ever produced a space (custom `TMPDIR`), word-splitting would occur. Minor but worth `trap 'rm -f "${file}"' EXIT` or `trap "rm -f '${file}'"`.
- **Fix:**

```bash
file=$(mktemp -t "XXXXX-$(basename "$0")")
trap 'rm -f "${file}"' EXIT
```

and standardize aborts to `exit 1` or non-zero, or preserve `terminate` if 0-on-cancel is intentional (document it).

---

- **What happens:** `git branch --list` pipelines include remote symref line `origin/HEAD -> origin/main` which survives `sed 's|^origin/||g'` as `HEAD -> main` and is kept as a bogus branch entry.
- **Where:**

```bash
branchList=$(
  git branch --list --format='%(refname:short)' --remote
  git branch --list --format='%(refname:short)'
)
```

- **Why it's wrong:** `--remote` emits `origin/HEAD -> origin/main` (with ` -> `). After stripping `origin/`, the arrow line remains and passes through `no-dups`/`trim`/`remove-blanks` as a branch candidate, polluting `gum choose`.
- **Fix:**

```bash
branchList=$(
  git branch --list --format='%(refname:short)' --remote | grep -v ' -> '
  git branch --list --format='%(refname:short)'
)
```

or filter `rg -v ' -> '` before sed.

#### Minor / style

- `if [[ ${#branches[@]} == 1 ]]` uses string `==` for numeric count; idiomatic is `-eq`/`(( ${#branches[@]} == 1 ))`. Not a bug due to `[[ ]]`, but inconsistent with `clangc:44` `((argc < 1))`.
- `createBranch` boolean test `if "${isOrphan}"; then` relies on `isOrphan` being literal `true`/`false` command (from `createBranch "${branchParam}" true` vs default `${2:-false}`). Correct per `cmdarg` boolean convention but fragile if caller passes any other string; document or use `[[ "${isOrphan}" == true ]]`.
- `file=$(mktemp -t XXXXX-"$(basename "$0")")` — `mktemp -t` is deprecated on GNU coreutils (`-t` is BSD-compat); portable form is `mktemp -t "$(basename "$0").XXXXX"` or bare `mktemp`.

#### Confirmed correct (potential false positives)

- `source "$(include "lib/helpers.sh")"` / `source "$(include "lib/cmdarg.sh")"` / `source "$(include "check-deps")"` + `checkDeps "$0"` + `trap 'exit 1' SIGUSR1` + `set -eo pipefail` — all match house style 1/4/7 and `clangc` canonical pattern; do not flag include indirection or missing `realpath -m` check (intentional, only echoes if file exists).
- `cmdarg "n" "new"` / `cmdarg "o" "orphan"` as boolean flags without `:`/`?`, reading via `${cmdarg_cfg['new']}` and testing with `if "${createNew}"; then` — correct per house style 5 (booleans default `"false"`, set to literal `true` command).
- `cmdarg_info "header" "$(get-desc "$0")"` + `cmdarg_parse "$@"` + `branchParam=${argv[0]:-"#-none-#"}` + `argc`/`argv` sentinel handling — correct cmdarg contract (house style 5); `get-desc` tolerates missing deps section (house style 6).
- `branchList` pipe `no-dups | trim | remove-blanks` — `no-dups` without `-a` keeps newline separation, correct for `mapfile -t`; contrasts with `load-fonts` bug (`no-dups -a | mapfile`) audited in batch-01 — this usage is intentional (house style 6).
- `# --- DEPENDENCIES --- #` listing `rg (ripgrep)` with package override parens — correct per house style 2; `checkDep` splits on `|` and `Trim`s, takes bare exe, `rg` resolves via `command -v`.
- `is-git-repo` / `git_current_branch` are repo-provided executables (sourced via `hooks/path.sh` PATH hook, not `lib/helpers.sh` functions); reliance on PATH is intentional per house style 7 — not a missing-source bug.

---

### `rename-spaces`

**Path:** `/home/othman/scripts/rename-spaces`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Replaces all spaces in file names to underscores (_)
**Declared dependencies:** `fd | fdfind (fd-find)`
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **What happens:** Declaration/usage mismatch plus collision/interactive hang on duplicate targets. Declared deps say `fd | fdfind` but code calls `fd.sh` wrapper; actual `fd.sh` (scripts/fd.sh:21-43) hard-codes `/usr/bin/fd --hidden --exclude .git …` + `"$@"`; dependency check passes if system `fd` exists, but script fails if `fd.sh` not on PATH (hook not sourced). More importantly, two distinct files can map to the same underscore target (`a b.txt` + `a_b.txt` → `a_b.txt`) and `renamefile` defaults to interactive `mvp -i` (renamefile:56) — script will hang awaiting TTY confirmation when run non-interactively, or silently overwrite if user previously aliased `mvp -f`.
- **Where:**

```bash
# --- DEPENDENCIES --- #
# - fd | fdfind (fd-find)
```

```bash
mapfile -t arr < <(fd.sh ' ' -t f -p "${PWD}")
```

```bash
for file in "${arr[@]}"; do
  renamefile "${file}" "${file// /_}"
done
```

- **Why it's wrong:** No collision detection and no `-f`/`-n` policy. Repo's `renamefile` (renamefile:31-54) supports `cmdarg -f` for force; `rename-spaces` never passes it, so behavior is TTY-dependent. For batch rename of `N` files, one collision stalls the whole run (`read -r answer </dev/tty` in `yesNo`-style prompts elsewhere; `mvp -i` similarly prompts on TTY).
- **Fix:**

```bash
# option A: skip collisions explicitly (safe default)
for file in "${arr[@]}"; do
  target="${file// /_}"
  [[ "${file}" == "${target}" ]] && continue
  if [[ -e "${target}" ]]; then
    log-warning "Skipping '${file}': target '${target}' already exists"
    continue
  fi
  renamefile -f "${file}" "${target}"
done
```

or declare intent: add `cmdarg "f" "force"` and forward `-f` when desired. Also either list dependency as `fd` (accurate for `fd.sh`'s hard-coded `/usr/bin/fd`) or invoke `fd` directly to match the declared check.

---

- **What happens:** Searches only `-t f` (regular files), but directory names containing spaces are ignored; `fd.sh ' ' -t f -p "${PWD}"` with `-p` (full path, fd.sh passes through) will still emit file paths whose parent dirs contain spaces, and `${file// /_}` will attempt to rename with a non-existent intermediate dir (e.g. `foo bar/baz qux.txt` → `foo_bar/baz_qux.txt` — first component rename fails because `foo bar/` ≠ `foo_bar/`).
- **Where:**

```bash
mapfile -t arr < <(fd.sh ' ' -t f -p "${PWD}")
```

- **Why it's wrong:** Replacing spaces in the full path renames parent dirs implicitly, but `renamefile`/`mvp` only `mkdir -p` the target's `dirname` (mvp:40) and then `mv` the leaf — the source path's parent still contains a space and is not pre-renamed, so the `mv` fails with "No such file or directory" when parent dirs themselves contain spaces. Ordering deepest-first or handling dirs separately is required.
- **Fix:** Either scope to basename only (`renamefile` already handles `dirname` mismatch cases, but not mid-path spaces), or enumerate depth-sorted and rename leaves first, or document limit to `maxdepth 1` / file-basename only:

```bash
# safest minimal fix: only rename basename, preserve dir path
for file in "${arr[@]}"; do
  dir="$(dirname "${file}")"
  base="$(basename "${file}")"
  newBase="${base// /_}"
  [[ "${base}" == "${newBase}" ]] && continue
  renamefile -f "${file}" "${dir}/${newBase}"
done
```

#### Minor / style

- `cmdarg_parse "$@"` with no declared `cmdarg` flags is correct for a zero-flag script, but `cmdarg_info "header" "$(get-desc "$0")"` is still invoked before any `cmdarg` definition — canonical order is `cmdarg_info` then `cmdarg` definitions then `cmdarg_parse`; here order is `checkDeps` → `cmdarg_info` → `cmdarg_parse` with no flags — matches `init.sh`/`log.sh` shape, not a bug.
- `mapfile -t arr < <(fd.sh ' ' -t f -p "${PWD}")` quotes `' '` correctly but `fd.sh` interprets first arg as regex pattern — `' '` matches any filename containing a space, intended. No word-splitting risk in `for file in "${arr[@]}"` / `"${file// /_}"` — correctly quoted.
- Silent no-op when no files contain spaces: `arr` empty, loop zero iterations, script exits 0 with no output — acceptable; could `log-info` "No files with spaces" for UX but not required.

#### Confirmed correct (potential false positives)

- `set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `source "$(include "lib/cmdarg.sh")"` + `source "$(include "check-deps")"` + `checkDeps "$0"` — house-style startup (style 4/7); `get-desc` tolerates empty `DEPENDENCIES` section (house style 6) — not a bug.
- `# - fd | fdfind (fd-find)` dependency line with pipe fallback and pkg override — correct per house style 2 (`checkDep` splits on `|`, `command -v` each alternative); do not flag `|` or `(fd-find)` as syntax error.
- `source "$(include "...")"` indirection using `realpath -m` + existence check — intentional (house style 1), not fragile.
- `renamefile "${file}" "${file// /_}"` using pure Bash `${var// /_}` substitution — correct; no need for `tr` or `sed` external command (house style ladder 3).

---

### `yes.sh`

**Path:** `/home/othman/scripts/yes.sh`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Output a string repeatedly until killed
**Declared dependencies:** none
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **What happens:** Only the first positional argument is repeated; `yes` POSIX/GNU concatenates all arguments with spaces (`yes foo bar` → `foo bar` per line). User expectation from name `yes` is multi-arg join; supplying `yes.sh a b c` silently drops `b c`.
- **Where:**

```bash
  printf '%s\n' "${argv[0]:-y}"
```

- **Why it's wrong:** Diverges from `yes(1)` contract without documenting. The `# --- DESCRIPTION --- #` says "Output a string repeatedly" — ambiguous, but filename `yes.sh` strongly implies `yes` compatibility. If strict compat is desired, should join all `argv` with spaces.
- **Fix:**

```bash
# POSIX yes semantics: join all args with space, default "y"
while :; do
  if ((argc == 0)); then
    printf 'y\n'
  else
    printf '%s\n' "${argv[*]}"
  fi
  sleep 0.05
done
```

If single-arg is intentional, document in description/header or add `cmdarg` help text clarifying "only first argument is used".

---

- **What happens:** Fixed `sleep 0.05` (50 ms) throttles to ~20 lines/s; GNU `yes` is unthrottled and saturates stdout. For pipelines relying on `yes` throughput (e.g. `yes | head -n 1000000`), the throttle is a ~50000× slowdown and changes semantics.
- **Where:**

```bash
  sleep 0.05 # 50ms delay
```

- **Why it's wrong:** Intentional throttle is undocumented and distro-specific: fractional `sleep 0.05` requires GNU coreutils `sleep`; `busybox`/`alpine`/`dash` `sleep` rejects fractional seconds (fails with `invalid interval`). Script then exits due to `set -e`, breaking the infinite loop.
- **Fix:** Either remove the sleep to match `yes(1)` (and rely on consumer back-pressure), or make it configurable and portable:

```bash
# add to cmdarg setup:
cmdarg "d?" "delay" "Delay between lines (seconds, 0 for none)" "0"
# then:
delay="${cmdarg_cfg['delay']}"
while :; do
  printf '%s\n' "${argv[0]:-y}"
  [[ "${delay}" != "0" ]] && sleep "${delay}" || true
done
```

and document the default.

#### Minor / style

- Unused `source "$(include "lib/helpers.sh")"` — no `log*`, `Trim`, `is*` etc. is called; script only uses `cmdarg` + `checkDeps` + `argv`. Sourcing helpers forks no extra process once but adds load and couples to `lib/loggers.sh` for no benefit; remove or keep for future logging — either is fine, but matches `clangc` which sources only `cmdarg` + `compile` + `check-deps`.
- `checkDeps "$0"` with empty dependency block still extracts `x-none` and returns 0 — correct per house style 6; not a useless call (canonical in `log.sh`/`get-desc`).
- `set -eo pipefail` + `trap 'exit 1' SIGUSR1` are harmless for an infinite loop but ensure `log-error` propagation if `printf` ever fails (e.g. broken pipe `yes.sh | head -n 5` — `printf` fails with SIGPIPE; `set -e` + `pipefail` will cause exit 1, matching `yes` behavior which exits on SIGPIPE).

#### Confirmed correct (potential false positives)

- `source "$(include "lib/cmdarg.sh")"` + `cmdarg_info "header" "$(get-desc "$0")"` + `cmdarg_parse "$@"` with zero declared flags — correct; `get-desc` parsing tolerates missing description terminator (house style 6), and `argv`/`argc` are still populated.
- `# --- DEPENDENCIES --- #` empty block (immediately followed by `# --- END SIGNATURE --- #`) — intentional and allowed per house style 6; `get-deps` correctly returns `x-none`, do not flag "missing dependencies" as bug.
- `trap 'exit 1' SIGUSR1` without a matching `kill -SIGUSR1` in this script — correct per house style 4; only `log-error` sends the signal, not every script.
- `sleep 0.05` fractional syntax is valid on GNU coreutils (repo targets `init.sh` `apt`/`dnf`/`pacman` hosts where this holds); only flagged above for portability, not as syntax error.

---

### `gitignore-refresh`

**Path:** `/home/othman/scripts/gitignore-refresh`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Refreshes Git repository by removing cached files and recommitting to apply updated .gitignore
**Declared dependencies:** `git`
**Verdict:** `Needs fixes`

#### Critical bugs

None found — but Design issues below cause silent failure under `set -e` in the common no-op case.

#### Design issues

- **What happens:** `git commit -am "remove ignored files $(now)"` exits 1 when there is nothing to commit (e.g. `.gitignore` already applied, or no ignored files tracked). With `set -eo pipefail`, the script then exits non-zero and, via `trap 'exit 1' SIGUSR1` / `log-error` chain, reports failure even though the repo is already in the desired state.
- **Where:**

```bash
git rm -r --cached .

git add .

git commit -am "remove ignored files $(now)"
```

- **Why it's wrong:** `git rm -r --cached .` + `git add .` correctly re-applies `.gitignore`, but when the index is unchanged `git commit` has no diff and fails: `nothing to commit, working tree clean` (exit 1). The script's success condition is wrong — it should succeed when no commit is needed. Current `set -e` makes the no-op path the failure path.
- **Fix:**

```bash
is-git-repo

git rm -r --cached . >/dev/null
git add . >/dev/null

if git diff --cached --quiet; then
  log-info "No ignored files to remove — working tree already clean"
  exit 0
fi

# now is a repo executable (scripts/now:30 `date +"%Y-%m-%d@%I:%M%p"`), resolved via hooks/path.sh PATH
git commit -m "remove ignored files $(now)"
```

Notes: use `git commit -m` (not `-am`) after `git add .` — `-a` re-adds modified tracked files only and is redundant after `git add .`; if untracked-file handling is desired, keep `-a` but guard with the `diff --cached --quiet` check. Alternatively `git commit --allow-empty -m ...` if empty commits are intentional, but silent no-op with `log-info` is more expected.

---

- **What happens:** Undeclared runtime dependency on `now` script (scripts/now:30). `now` is an executable resolved via `hooks/path.sh` PATH hook, not a shell function from `lib/helpers.sh` (helpers.sh provides no `now`); `checkDeps` only verifies `git`, so `now` missing on a fresh host produces `command not found` and `set -e` exit, masked as a checkout failure.
- **Where:**

```bash
git commit -am "remove ignored files $(now)"
```

- **Why it's wrong:** House style 2 requires every external executable to be listed in `# --- DEPENDENCIES --- #` for `checkDep` → `getPackageManager` / `checkDeps` install. `now` is repo-local, always present if `hooks/path.sh` succeeded, but if PATH hook not yet sourced (e.g. fresh `init.sh` not run, or `SCRIPTS_DIR` not exported), `now` is not found. `get-deps` extraction via `sed -n '/# --- DEPENDENCIES --- #/,/# --- END SIGNATURE --- #/{/\# - /p;}'` would correctly surface it if declared.
- **Fix:**

```bash
# --- DEPENDENCIES --- #
# - git
# - now
```

or inline `date +"%Y-%m-%d@%I:%M%p"` to avoid the extra process and keep deps as `git` only. With `set -e`, prefer `$(now)` quoted or with `command -v now >/dev/null || log-error "now not found"`.

---

- **What happens:** `git rm -r --cached .` output/errors are unsuppressed and not checked; on a non-git repo or empty repo (`is-git-repo` guards, but `git rev-parse` race), it prints large file list to stdout and may fail mid-pipeline.
- **Where:**

```bash
is-git-repo

git rm -r --cached .
```

- **Why it's wrong:** `is-git-repo` (is-git-repo:42-45) without `--safe` will `log-error` → `kill -SIGUSR1 "${PPID}"` + `wait`, correctly aborting parent. But the script discards that propagation nuance: after `is-git-repo` succeeds, `git rm -r --cached .` may still fail if the index is empty (`fatal: No pathspec`). Suppress or handle.
- **Fix:** Redirect or handle as above (`>/dev/null` + `diff --cached` guard); also consider `is-git-repo --safe` if silent check is desired (cf. `ts-starter` uses `--safe`).

#### Minor / style

- `cmdarg_info "header" "$(get-desc "$0")"` + `cmdarg_parse "$@"` with no flags — correct but no help text; add footer noting "No options; updates index per current .gitignore" for `cmdarg_usage`.
- `git commit -am` mixes `-a` (auto-stage modified) and `-m`; after `git add .` the `-a` is redundant. Use `git commit -m` or `git commit --all -m` consistently.
- Missing `set -u` is intentional (house style: only `set -eo pipefail`); do not flag.

#### Confirmed correct (potential false positives)

- `set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `source "$(include "lib/cmdarg.sh")"` + `source "$(include "check-deps")"` + `checkDeps "$0"` + `cmdarg_info`/`cmdarg_parse` — canonical shape matching `clangc` (house style 8), not a bug; order `checkDeps` before `cmdarg_parse` is correct.
- `# --- DEPENDENCIES --- #` / `# --- END SIGNATURE --- #` single-dep `git` block — correctly parsed by `get-deps` (`sed -n '/# --- DEPENDENCIES --- #/,/# --- END SIGNATURE --- #/{/\# - /p; …}' | sed 's|# - ||g'`), not a missing-deps bug (house style 6).
- `is-git-repo` bare invocation (without `command -v` check) is intentional — `hooks/path.sh` adds script dirs to `PATH` (house style 7); script is executable and `checkDeps` already verified `git`.
- `$(now)` command substitution invoking sibling script `now` (scripts/now:30) — correct; `now` is a repo executable, not an undefined function, and `helpers.sh` `now` absence is not a bug (`now` lives as `scripts/now`, resolved via PATH hook).
- `source "$(include "...")"` with `realpath -m` + `[[ -f … ]] && echo` — intentional guard (house style 1); not fragile.

---

## Batch Summary

- **Scripts reviewed:** 4 / 4
- **Critical bugs:** `switch-branch` — `tr -d "/"` destroys hierarchical branch names (all `/` stripped); `createBranch` error message uses loop variable `${branch}` instead of `${branchName}` (wrong name on failure)
- **Design issues worth escalating:** `switch-branch` — unescaped `rg -v "^${current}$"` + `origin/HEAD -> origin/main` symref not filtered + `gum` abort trap/orphan `clearPrev` logic/ `mktemp -t` portability; `rename-spaces` — `fd.sh` vs declared `fd` dep mismatch + full-path space replacement fails for parent dirs with spaces + collision/interactive `mvp -i` hang; `gitignore-refresh` — `git commit` fails with `set -e` when nothing to commit (no-op = failure) + undeclared `now` dependency / `git commit -am` redundancy; `yes.sh` — only `argv[0]` repeated (not `argv[*]`) + `sleep 0.05` throttling/portability vs GNU `yes`
- **Cross-cutting patterns observed in this batch** (same bug/pattern repeated across multiple scripts in this batch only; batch-level, not repo-wide): `switch-branch` + `gitignore-refresh` both rely on `is-git-repo`/`git_current_branch` without `--safe` and handle `git` exit codes inconsistently with `set -e` (commit/branch abort paths); `switch-branch` + `rename-spaces` both pipe through `no-dups | trim | remove-blanks` correctly without `-a` (consistent, contrasts with `load-fonts` audit in batch-01); `rename-spaces` + `yes.sh` both declare minimal/empty deps while invoking repo-local executables (`fd.sh`/`renamefile`/`now`) resolved via `hooks/path.sh` PATH rather than declared `checkDep` entries — pattern worth standardizing.
- **Open questions** (design intent unclear, needs the repo owner's input rather than a guess): `switch-branch` — is `tr -d "/"` a typo for `tr -d "\r"` or intentional slash stripping? Should `switch-branch` support namespaced branches (`feature/*`, `user/*`) or is flat-name policy deliberate? Should `createBranch --orphan` `git rm -rf .` be the default or behind `gum confirm`? Should `rename-spaces` rename only basenames or whole-path spaces, and should it default to `renamefile -f` (force) or interactive with collision skip? Should `gitignore-refresh` produce an empty commit (`--allow-empty`) or silently succeed when no ignored files exist? Should `yes.sh` mimic GNU `yes` (`argv[*]` + no throttle) or keep throttled single-arg behavior?

---

## Evidence appendix

### switch-branch

- `switch-branch:42-57` branch list pipeline with `tr -d "/"`, sed origin strip, and no-dups
- `switch-branch:60-63` `rg -v "^${current}$"` unescaped
- `switch-branch:68-69` `mktemp -t` + `trap 'rm -f $file' EXIT`
- `switch-branch:122-159` `createBranch` including `log-error "Failed to create branch '${branch}'"` vs `${branchName}`
- `switch-branch:140-148` orphan `clearPrev` / `cmd+=('--orphan')` logic
- Cross-check: `is-git-repo:30-46` `log-error --no-kill` vs `log-error` branching; `git_current_branch:30-32` `git branch --show-current`; `no-dups:45-51` `awk '!seen[$0]++'` without `-a` (correct for `mapfile`); `trim:36` `sed` escaping; `remove-blanks:42` `awk 'NF'`; `fd.sh:21-43` hard-coded `/usr/bin/fd --hidden --exclude`

### rename-spaces

- `rename-spaces:30-34` `fd.sh ' ' -t f -p "${PWD}"` + `renamefile "${file}" "${file// /_}"`
- `renamefile:31-75` `cmdarg -f`/`-i` + `mvp -f`/`-i` dispatch, `dirname`/`basename` branching
- `mvp:30-51` `mkdir -p` + `sudo mv -f`/`-i`
- `fd.sh:21-43` excludes + `"$@"` passthrough
- `no-dups:45-51` correct `-a` vs non-`-a` distinction (see `docs/code-reviews/batch-01.md:246-261` load-fonts audit)

### yes.sh

- `yes.sh:28-35` `cmdarg_parse` with zero flags + `while :; do printf '%s\n' "${argv[0]:-y}"; sleep 0.05; done`
- `lib/helpers.sh:228-230` `isInteractiveShell` etc. (unused here, but sourced)

### gitignore-refresh

- `gitignore-refresh:30-36` `is-git-repo` → `git rm -r --cached .` → `git add .` → `git commit -am "remove ignored files $(now)"`
- `now:28-30` `date +"%Y-%m-%d@%I:%M%p"` + deps `date`
- `is-git-repo:30-46` safe flag behavior; `hooks/path.sh:21-53` PATH hook caching

### core files read

- `include:19-26` `SCRIPTS_DIR` fallback + `realpath -m`
- `lib/cmdarg.sh:18-369` full arg parsing contract (boolean `true`/`false`, `declare -A` pre-declare, `cmdarg_parse "$@"`)
- `lib/loggers.sh:322-341` `colorOnlyPrefix` / `printer` / `supportsColor`
- `lib/helpers.sh:18-420` `log*` fallback, `input`, `getDeps`, `getPackageManager`, `Trim`, `isInt`, `supportsColor`, `yesNo`, `hasher`
- `check-deps:21-175` `checkDep` pipe-split + `getPackageManager` + `installDep`
- `log.sh:28-66` `LEVEL_COLORS`/`LEVEL_OUTPUT` dispatcher
- `get-desc:42-53` description sed block; `get-deps:37-39` deps sed block
- `init.sh:20-158` PATH hook install; `hooks/path.sh:20-86` cache/rescan + PATH guard; `clangc:21-67` canonical pattern reference
