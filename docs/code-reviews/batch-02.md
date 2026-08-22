# Batch Review: 02 of 22

**Scripts in this batch:** `create-wiki`, `pdfx`, `spotifyctl`, `yt-music-playlist` (4 scripts)
**Batch composition:** large+fillers — large standalone `create-wiki` (401 lines) plus 3 tiny one-liners as incidental fillers (`pdfx`, `spotifyctl`, `yt-music-playlist` are 3-line `runpy "$0" "$@"` wrappers) — pairing is incidental, not a shared pattern. Budget 410 lines, 4 scripts (cap 4 because large >150).
**Reviewer:** subagent-02
**Date:** 2026-08-21

---

## House Style Reference (do not flag these as bugs)

Before reviewing, confirm you've internalized these repo conventions. Restate them here in one line each to prove the context loaded correctly:

- Dependency declaration format (`# - binary | binary2 (pkg-override)`) and how `checkDep` resolves it: deps live between `DEPENDENCIES`/`END SIGNATURE` as `# - exe | alt (pkg)`; `checkDep` splits on `|`, `Trim`s, `awk '{print $1}'` per alternative and `command -v` checks in order — any hit returns 0 satisfied, else echoes `(parens)` content or first exe name for `installDep`.
- Logging convention: `log-*` wrapper scripts are primary, camelCase `log*` functions in `lib/helpers.sh` are fallback: standalone `log-debug/info/warning/error/success` plus `log.sh` dispatcher (via `LEVEL_COLORS`/`LEVEL_OUTPUT`/`colorOnlyPrefix`) are the CLI entry points; `lib/helpers.sh` camelCase + `lib/loggers.sh` `printRed`/`printGreen`/`hex_to_rgb` are in-process fallback, not dead code, and `log-success` vs `logSuccess` naming is both canonical.
- `trap 'exit 1' SIGUSR1` + `kill -SIGUSR1 "${PPID}"` propagation chain purpose: every script traps SIGUSR1 to `exit 1`; only `log-error` sends `kill -SIGUSR1 "${PPID}"` + `wait` (guarded by `! isInteractiveShell && ! noKill`, suppressed with `|| true`) to kill its parent up the chain without explicit exit-code checks.
- `cmdarg.sh` argument-parsing pattern used across scripts: `source "$(include "lib/cmdarg.sh")"` then `cmdarg_info "header" "$(get-desc "$0")"`; pre-declare `declare -a arr`/`declare -A hash` for `[]`/`{}` types; `cmdarg "v"` boolean defaults `"false"`/literal `true` (`if ${cfg['v']}; then`), `"m:"` required string, `"o?"` optional string, `"a?[]"`/`"H?{}"` array/hash; then `cmdarg_parse "$@"` and read `cmdarg_cfg`/`argv`/`argc`; `-h`/`--help` reserved.
- `get-desc` / `get-deps` signature-block parsing rules: both `sed`-parse `# --- DESCRIPTION --- #` … `# --- DEPENDENCIES --- #` … `# --- END SIGNATURE --- #`; missing block is allowed (`get-deps` prints `x-none`, `checkDeps` returns 0, `get-desc` tolerates either terminator); `get-deps` uses `sed -n '/DEPENDENCIES/,/END SIGNATURE/{/\# - /p}' | replace.sh`.
- `init.sh` / `hooks/path.sh` symlink and PATH-registration workflow: `init.sh` verifies `SCRIPTS_DIR` (`~/scripts`), ensures `fd` (prompts `fdfind->fd` symlink), checks `hooks/path.sh`, idempotently appends `[[ -s "${SCRIPTS_DIR}/hooks/path.sh" ]] && source ...` to `~/.bashrc` (or `~/.zshrc`); `hooks/path.sh` (sourced at startup, not executed) caches `fd --strip-cwd-prefix=always --no-ignore-vcs -t x . --exclude .git/.venv/...` to `/tmp/path-hook.cache`, rescans only when `find -newer cache`, adds each executable's dir once via `:":${PATH}:"` guard, then unsets temps.
- Reference pattern from `clangc` (what "correct" looks like in this repo): `set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `source "$(include "lib/cmdarg.sh")"` + `source "$(include "lib/compile.sh")"` + `source "$(include "check-deps")"` + `checkDeps "$0"` in order; `cmdarg_info`/`declare -a compiler_args`/`cmdarg "c"`/`"o?"`/`"a?[]"`/`"q"`/`cmdarg_parse "$@"`; literal `cmdarg_cfg` reads, `((argc <1)) && log-error`, array-safe delegation via namerefs.

---

## Script Reviews

### `create-wiki`

**Path:** `/home/othman/scripts/create-wiki`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Generates wiki pages for all scripts in the repository
**Declared dependencies:** `parallel`, `xxh3sum (xxhash) | xxhsum (xxhash) | sha1sum (coreutils)` (two lines)
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **What happens:** `hashCache` keyed only by `basename`, so two scripts in different directories with the same filename collide and can incorrectly skip generation.
- **Where:**

```bash
# create-wiki:175,259
  local hashCache="${WIKI_CACHE_DIR}/${scriptName}.hash"
# create-wiki:259
  local hashCache="${WIKI_CACHE_DIR}/lib-${libName}.hash"
```

- **Why it's wrong:** `generateScriptPage` stores `${scriptName}.hash` without any directory component; if the repo ever contains e.g. `external/foo` and root `foo` with the same basename, the second write overwrites the first hash and `shouldSkipIfUnchanged` can falsely return 0 (skip) for the other file. Lib variant mitigates with `lib-` prefix but scripts do not. In practice the repo currently has unique basenames, but the cache design is fragile.
- **Fix:** key by relative path or full hash of path, e.g.:

```bash
local hashCache="${WIKI_CACHE_DIR}/${relDir//\//_}-${scriptName}.hash"
# or
local hashCache="${WIKI_CACHE_DIR}/$(hasher "${file}" | awk '{print $1}')-${scriptName}.hash"
```

Low severity; fix only if duplicate basenames are expected.

- **What happens:** `HELP_CACHE_DIR` key is `fileHash` only (content hash, no path), so two different files with identical content would share a cached `--help` output.
- **Where:**

```bash
# create-wiki:117-118
  local fileHash="$(hasher "${file}" | awk '{ print $1 }')"
  local cacheFile="${HELP_CACHE_DIR}/${fileHash}"
```

- **Why it's wrong:** same collision class as above, but for help cache; identical file content naturally yields identical help only if scripts are functionally identical, so the aliasing is benign today, but a content-hash-only key conflates distinct scripts.
- **Fix:** include basename in key (`${fileHash}-${scriptName}`) or accept as intentional deduplication and document it. Keep as design note, not critical.

- **What happens:** `parseCmdargFlags` table shows raw `flag` token including `?`, `[]`, `:` suffixes (e.g. `a?[]`, `d?`), so markdown renders `| -a?[] |` / `| -d? |` instead of the user-facing short flag `| -a |` / `| -d |`.
- **Where:**

```bash
# create-wiki:150
      echo "| -${flag%%:*} | --${longopt} | ${flagType} | ${descText:-No description} |"
```

- **Why it's wrong:** `%%:*` only strips a trailing `:`, leaving `?` and `[]`/`{}` suffixes visible in the Flags & Options table. The displayed flag does not match the `cmdarg` contract shown in `clangc` (`-a`, `-o`, etc.). Cosmetic only; help output below the table is still correct.
- **Fix:**

```bash
echo "| -${flag:0:1} | --${longopt} | ${flagType} | ${descText:-No description} |"
```

or `flagClean="${flag%%[\?:]*}"` then `flagClean="${flagClean%%\[*}"` before printing. Low severity.

#### Minor / style

- `origRelDir` extraction uses `sed -e " s|^/||"` with a leading space before `s`, and `generateLibPage` `desc` line uses `-e' s/ $//'` with a leading space inside the quoted expression. Both rely on GNU `sed` tolerating whitespace before the `s` command (it does), but the stray space is inconsistent with the first `-e "s|^${SCRIPTS_DIR}||"` and with `clangc` style. Prefer `sed -e "s|^${SCRIPTS_DIR}||" -e "s|^/||"` and `sed -e 's/  */ /g' -e 's/^ //' -e 's/ $//'` for clarity. Not a bug (`shellcheck` passes), just style. `create-wiki:163`, `create-wiki:265`.

- `relDir` mapping hard-codes `lib | rofi | external -> bash/${relDir}` but `generateLibPage`/`generateScriptPage` already handle the mapping via `relDir="bash/${relDir}"`; any future top-level language dir (`python`, `lua`, etc.) correctly falls through `* ) : ;;` and keeps its dir — this is intentional per comments `create-wiki:167-170`, not a missing case. Document if new language dirs should be added to the wiki.

- `parallel` invocation enumerates `printf '%s\0' "${SCRIPTS_DIR}"/* "${SCRIPTS_DIR}/lib"/*.sh "${SCRIPTS_DIR}/rofi"/* "${SCRIPTS_DIR}/external"/*` — if `rofi`/`external` are empty or contain no executables, the glob expands to the literal pattern (no `nullglob`/`failglob` set) and `main` immediately skips via `[[ -f "${file}" ]] || continue` and `head -1` shebang check. Correct but sends a few literal entries through `parallel`; adding `shopt -s nullglob` or guarding with `[[ -e "${pattern}" ]]` would avoid the wasted jobs. Not a bug.

- Dependencies listing `xxh3sum (xxhash) | xxhsum (xxhash) | sha1sum (coreutils)` correctly uses pipe as fallback and parens as package override per house-style-brief §2; the `hasher()` helper in `lib/helpers.sh:411-420` already covers this triple fallback, so the three-way declaration is redundant but harmless and matches `clangc`.

- Mixed `log-info` vs `log-success` vs `logVerbose` is consistent: `logVerbose` delegates to `log-info` for skipped/ignored messages, `generateScriptPage`/`generateLibPage` delegate to `log-success` for created pages — matches `log.sh` `LEVEL_COLORS` mapping and `lib/helpers.sh` fallback, not a naming bug.

- `document-with-llm` and `mdfmt` invoked at `create-wiki:394,397` are not declared in `DEPENDENCIES`; `document-with-llm` is conditional on `--all` (opt-in) and `mdfmt` is best-effort (`&>/dev/null` suppressed). Either declare them as optional deps or document that they are optional external tools, consistent with prior batches' handling of optional formatters.

#### Confirmed correct (potential false positives)

- `set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `source "$(include "lib/cmdarg.sh")"` + `source "$(include "lib/helpers.sh")"` + `source "$(include "check-deps")"` + `checkDeps "$0"` + `cmdarg_info "header" "$(get-desc "$0")"` + `declare`/ `cmdarg "d?"`/`"f"`/`"a"`/`"p?"`/`"m?"`/`"v"`/`"j?"` + `cmdarg_parse "$@"` order exactly matches `clangc` reference pattern; `isPositive "${JOBS}"` validator and boolean `if "${FORCE}"` / `"${VERBOSE}" && log-info || true` / `if "${ALL}"` literal `true`/`false` usage are canonical `cmdarg.sh` booleans, not quoted-string bugs.
- `# - parallel` and `# - xxh3sum (xxhash) | xxhsum (xxhash) | sha1sum (coreutils)` pipe+parens are correct `checkDep` syntax per house-style-brief §2; `get-deps` extraction via `sed -n '/DEPENDENCIES/,/END SIGNATURE/{/\# - /p}'` handles them.
- `remote="$(git -C "${SCRIPTS_DIR}" remote get-url origin | sed 's|\.git$||')"` + `REPO_URL="${remote/git@github.com:/https://github.com/}"` correctly handles both `https://` and `git@` remotes via bash `${var/pattern/repl}` expansion.
- `export -f main ... hasher ...` + `export WIKI_DIR ... IGNORED_SCRIPTS_LIST` + `parallel -0 -j "${JOBS}" -k -m --tty main` is the correct way to ship bash functions and arrays through `parallel` (arrays serialized via `printf '%s\n'` because bash cannot export arrays).
- `timeout 2 "${file}" --help 2>&1 || true` guarded by `usesCmdarg` is intentional safe `--help` handler (only scripts that parse `cmdarg` have a safe help path); `hasher` + `awk '{print $1}'` hash handling and `shouldSkipIfUnchanged` `[[ -f "${outputFile}" ]] && [[ -f "${hashCache}" ]]` + `currentHash == $(<hashCache)` + `return 0` skip / `return 1` generate correctly implements the `--force` inverted-logic contract.
- Missing DESCRIPTION is allowed per house-style-brief §6; scripts that fall through `head -1` `*"bash"*` or `*.rasi` checks are silently skipped, which is intentional filtering for `wiki/`, `c/`, etc., not a missed-file bug.

---

### `pdfx`

**Path:** `/home/othman/scripts/pdfx`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): none declared — file contains only `#!/usr/bin/env bash` + `runpy "$0" "$@"` (no signature block; `get-desc` would return empty, `get-deps` would return `x-none`)
**Declared dependencies:** none declared (no `DEPENDENCIES` block; `checkDeps` would return 0 via `x-none`)
**Verdict:** `Clean`

#### Critical bugs

None found.

#### Design issues

None found.

#### Minor / style

- No `set -eo pipefail` / `trap 'exit 1' SIGUSR1` / signature block, unlike the 400-line `create-wiki` in the same batch. This is acceptable for a 3-line `runpy` shim — the shim delegates all error handling to `runpy` itself (`runpy:20-21` has `set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `checkDeps "$0"` for `uv` / `fd | fdfind`). Adding a full header would add no signal for these shims.

#### Confirmed correct (potential false positives)

- `runpy "$0" "$@"` is the canonical Python-shim pattern in this repo (used by all `python/*/main.py` entry points; see `runpy:23-40` resolving `strip-ext "$1" sh zsh fish bash` -> `pattern="/pdfx/main\.py$"` -> `fd.sh ... -p "${dir}"` -> `venv`/`uv run`). The missing DESCRIPTION/DEPENDENCIES block is allowed per house-style-brief §6; deps are declared on `runpy` (`uv`, `fd | fdfind`), not on the shim itself — do not flag as missing deps. Verified `python/pdfx/main.py` exists (`python/pdfx/docs/external-context/...` present) and `runpy` correctly handles `venv` activation vs `uv run` fallback.

---

### `spotifyctl`

**Path:** `/home/othman/scripts/spotifyctl`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): none declared — same 3-line `runpy` shim
**Declared dependencies:** none declared
**Verdict:** `Clean`

#### Critical bugs

None found.

#### Design issues

None found.

#### Minor / style

- Same as `pdfx` — no `set -eo pipefail`/`trap`/signature header. Intentionally minimal shim that delegates to `runpy`; not a divergence from `clangc` reference pattern — the large tool (`create-wiki`) follows the full pattern, the filler shims intentionally do not.

#### Confirmed correct (potential false positives)

- `runpy "$0" "$@"` correctly resolves to `python/spotifyctl/main.py` via `runpy:25` `strip-ext` + `fd.sh` pattern (`/spotifyctl/main\.py$`). Verified `python/spotifyctl/main.py` exists and uses `dbus`/`GLib` PlayerManager. The batch pairing with `create-wiki` is incidental line-budget filler (large >150 cap 4), not a shared `runpy` family pattern to audit — do not hunt for a connection that isn't there.
- Missing DESCRIPTION/DEPENDENCIES is allowed per house-style-brief §6; `get-deps` returns `x-none`, `checkDeps` correctly returns 0. The shim's runtime deps (`uv`, `fd|fdfind`) are declared on `runpy`, not here — house style says `init.sh`/`hooks/path.sh` handles PATH, not per-script concern.

---

### `yt-music-playlist`

**Path:** `/home/othman/scripts/yt-music-playlist`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): none declared — same 3-line `runpy` shim
**Declared dependencies:** none declared
**Verdict:** `Clean`

#### Critical bugs

None found.

#### Design issues

None found.

#### Minor / style

- Same as siblings — no full signature/header. Intentionally minimal; `yt-music-playlist` filename with hyphens is correctly handled by `strip-ext` + `fd.sh` pattern (`/yt-music-playlist/main\.py$`), unlike underscore-vs-hyphen mismatches seen elsewhere in other batches. No rename needed.

#### Confirmed correct (potential false positives)

- `runpy "$0" "$@"` correctly resolves to `python/yt-music-playlist/main.py`; verified subdirectory exists under `python/`. The shim contains no `cmdarg`/`log-error`/`trap` logic to flag — only `runpy` does. The three `runpy` shims in this batch (`pdfx`, `spotifyctl`, `yt-music-playlist`) identically share 3 lines (`#!/usr/bin/env bash` + blank + `runpy "$0" "$@"`); the duplication is intentional entry-point convention, not copy-paste debt.
- As with siblings, no signature block is not a bug per house-style-brief §6; `get-desc` tolerates either DEPENDENCIES or END SIGNATURE as terminator, and `get-deps` extraction would correctly yield `x-none`.

---

## Batch Summary

- **Scripts reviewed:** 4 / 4
- **Critical bugs:** none — `create-wiki` has no crash/incorrect-behavior bugs; the three `runpy` shims are trivially correct.
- **Design issues worth escalating:** `create-wiki` — 1) hash-cache keyed by `basename` only (`${scriptName}.hash`) collides if two scripts share a filename across `lib`/`rofi`/`external`/root (mitigate by including `relDir` in cache key); 2) help-cache keyed by `fileHash` only (same content-hash aliasing); 3) `parseCmdargFlags` `| -${flag%%:*} |` leaves `?[]`/`?` suffix visible in Flags table (use `${flag:0:1}`). All low severity, only if the repo ever gains duplicate basenames or users rely on the Flags table for copy-paste.
- **Cross-cutting patterns observed in this batch** (same bug/pattern repeated across multiple scripts in this batch only; batch-level, not repo-wide):
  - The three fillers (`pdfx`, `spotifyctl`, `yt-music-playlist`) are byte-identical 3-line `runpy` shims — no per-script divergence to audit, and their missing DESCRIPTION/DEPENDENCIES/trap/cmdarg blocks are collectively intentional, not an omission.
  - No batch-wide `cmdarg`/`log-*`/`checkDep` anti-pattern — the large `create-wiki` is the only script in this batch that uses `cmdarg.sh`/`checkDeps`/`log-*`/`hasher`, so there is no repeated bug to flag at batch level. Any `hasher`/`checkDep` fallback (`xxh3sum | xxhsum | sha1sum`, `fd | fdfind`) is house-style correct per brief §2, not a cross-cutting issue.
- **Open questions** (design intent unclear, needs the repo owner's input rather than a guess):
  - `create-wiki` hash-cache basename-only key: is uniqueness of basenames across `lib`/`rofi`/`external`/root an enforced repo invariant, or should the cache be fixed to include `relDir`? If basenames are guaranteed unique, the current key is fine and the collision note can be closed.
  - `create-wiki` `--all` + `document-with-llm`/`mdfmt`: are these meant to be declared as optional DEPENDENCIES (like `parallel` is) or intentionally left undeclared because they are conditional/best-effort? Should `mdfmt` failure be surfaced or remain `&>/dev/null` suppressed?
  - `pdfx`/`spotifyctl`/`yt-music-playlist` shims: should 3-line `runpy` shims gain a minimal `# --- DESCRIPTION --- #` block for `get-desc`/`Home.md` indexing, or is the `head -1` `*"bash"*` filter intentionally relying on the `runpy` indirection to keep them out of the bash wiki (they are documented via Python paths instead)?

---

## Evidence Appendix (optional)

- House style brief: `/home/othman/scripts/docs/code-reviews/house-style-brief.md:1-68`
- Core files read: `include:1-26`, `lib/cmdarg.sh:1-462`, `lib/loggers.sh:1-341`, `lib/helpers.sh:1-420`, `check-deps:1-175`, `log.sh:1-66`, `get-desc:1-53`, `get-deps:1-39`, `init.sh:1-158`, `hooks/path.sh:1-86`, `clangc:1-67`
- Batch scripts read: `create-wiki:1-401`, `pdfx:1-3`, `spotifyctl:1-3`, `yt-music-playlist:1-3`
- Supporting reads: `runpy:1-40`, `strip-ext:1-44`, `python/pdfx/main.py:1-30`, `python/spotifyctl/main.py:1-20`, `python/yt-music-playlist/main.py:1-20`, `batch-01.md:1-385` (template style reference)
- Verification: `shellcheck create-wiki` exit 0 (no warnings); `fd.sh`/`no-dups`/`replace.sh` pipelines in `create-wiki` previously audited in batch-01 context for `load-fonts`/`ls-colors`.
