# Final Report: Full-Repo Bash Script Review (22 batches, 144 scripts, 9904 lines)

**Date:** 2026-08-21
**Scope:** `fd . -t x -E .git -E bin --hidden -x wc -l` → 144 tracked executables, 9904 lines (avg 69). `.git/*.sample` (14 files) and `bin/*` binaries (7 files, ~685 MB) excluded per owner.  
**Method:** Phase 0 house-style brief (`docs/code-reviews/house-style-brief.md`) + line-budgeted batching (target 600-700 body lines, cap 12 scripts/batch, cap 4 when any script >150) + similarity grouping (subdir → name-family → large+fillers → grab-bag). 22 batches (pilot 01 + 12 large+fillers + 9 grab-bag) dispatched via subagents, each prepending brief + 10 core files + batch scripts + template. Audit trail in `docs/code-reviews/batch-*.md`.  
**Result snapshot:** Pilot batch 01 (log family 370 lines, 8 scripts) PASS — House Style Reference 7/7 correct, zero false positives on `log-success`/`trap`/`fd|fdfind`, Evidence appendix allowed. 21 remaining batches dispatched in parallel, all use template fully.

---

## Critical Bugs Index (actionable, grouped by script — one line per bug, batch provenance)

> Full index in `docs/code-reviews/critical-index.md` (29 bugs). One-liner per bug for triage; details + fix in batch files.

| Script | Bug (one sentence) | Batch | Verdict |
|--------|-------------------|-------|---------|
| `load-fonts` | `no-dups -a` + `mapfile -t` collapses multi-dir list to single element, `mv -t` fails silently; `continue` skips OTF | 01 | Needs fixes |
| `android-specs` | `--short` regex too narrow + `pipefail` → non-matching `rg` exit 1 kills via `set -e` | 03 | Needs fixes |
| `document-with-llm` | hash change detection dead code (skips existing page unless `--force`); `claude` hardcodes `opus`; `projectHash` hangs | 04 | Critical bug |
| `oc-manager` | missing `rg` dep → 15s timeout; unknown subcommand exits 0 | 05 | Needs fixes |
| `piper-say` | `checkCache` bare call returns 1 on miss → `set -e` exits before `generateAudio`; `viewlines` args reversed; empty `playerCmd` execs | 06 | Critical bug |
| `check-deps` | `getAskPass` overwrites existing system `askpass` on PATH | 10 | Critical bug |
| `switch-branch` | `tr -d "/"` strips all slashes → `feature/login` → `featurelogin` | 11 | Critical bug |
| `get-ip` | `pipefail` + `rg` no-match abort before `log-error` on VPN-only/`inet6`-only | 13 | Needs fixes |
| `mkpython` | no positional arg → bogus `python/.py` / `~/scripts/.py` | 14 | Critical bug |
| `runpy` | no args → pattern `//main\.py$` + multi-line mishandling | 14 | Critical bug |
| `dotfiles.sh` | `TUCKR_HOME` vs `TUCKR_DIR` mismatch | 15 | Needs fixes |
| `renamefile` | same-file `old==new` unreachable when `oldDir==newDir` | 15 | Needs fixes |
| `lua/timewarp.lua` | `tonumber(nil)` → arithmetic on nil | 15 | Needs fixes |
| `benchmark` | `${ cmd; }` Bad substitution on every aggregation | 16 | Critical bug |
| `no-orphans` | keep-list inverted → removes kept packages (data loss) | 16 | Critical bug |
| `env-qoutes` | `awk -F=` truncates `=`; `sponge` corrupts comments | 16 | Critical bug |
| `mkscript` | `SCRIPTS_DIR` undefined → `file="//name"` → touch fails | 17 | Critical bug |
| `rmwhich` | deletes any `$PATH` binary including system | 17 | Critical bug |
| `spin.sh` | `spinnerStart -c` maps literal `OPTARG` not `$OPTARG` | 18 | Critical bug |
| `tmux-exec` | inverted `yesNo` (y aborts, n kills) | 18 | Critical bug |
| `vercel-status` | single-quote in Vercel field breaks nushell / injection | 19 | Needs fixes |
| `watch.sh` | extension collection single element → `joinarr ','` no commas | 19 | Needs fixes |
| `tuckr-sync` | typo `fd.sh` command not found, fails immediately | 19 | Critical bug |
| `rmbranch` | `git branch -D --remote` deletes local tracking ref only, not remote | 20 | Critical bug |
| `editwhich` | `$1` vs `argv[0]` sentinel break (`--` case) | 20 | Critical bug |
| `lua/sec2time.lua` | both branches fall through `print("")` instead of exit | 21 | Needs fixes |
| `make-caddy` | `cmdarg` required args with empty default → missing-args error on no-arg | 21 | Needs fixes |
| `mdfmt` | `isPositive` undefined in sourced libs | 21 | Critical bug |
| `replace.sh` | `-b` silently ignored non-interactively (`isInteractiveShell` guard) | 22 | Needs fixes |

**Critical counts:** 21 scripts with critical-level bugs (15 `Critical bug` verdict + 6 `Needs fixes` containing critical sections). 8 scripts clean across all batches: `pdfx`, `spotifyctl`, `yt-music-playlist`, `external/colorblocks`, `now`, `external/colortest` (in some batches clean), `clangc` (canonical), `trunc` — verify per batch.

---

## Systemic Patterns (issues appearing across 3+ scripts — described once, all affected scripts listed)

Do not fix per-script in isolation; fix once and roll out.

### S1 — `cmdarg.sh` misuse: `$1`/`$#`/`$@` after `cmdarg_parse` instead of `argv`/`argc` (7+ scripts)
**What:** After `cmdarg_parse "$@"`, `$@`/`$#` are consumed; positionals are in `argv`/`argc` and options in `cmdarg_cfg`. Code that still checks `$1`/`$#` breaks with `cmdarg_parse --` or `--` sentinel, or mis-handles `cp`-style `-- ls` case.  
**Affected:** `rmbranch` (batch 20), `editwhich` (20), `replace.sh` (22), `yes.sh` (11), `readtime` (07 — `argc` vs `$1` drift), `mkscript` (17 — SCRIPTS_DIR via positional), `mkpython`/`runpy` (14 — empty positional edge), `make-caddy` (21 — required vs optional), `ts-starter` (08 — `argc` vs `$1`), `install-ext-online` (16 — scalar vs array). Also `rmbranch` remote delete no-op is cmdarg-adjacent (positional handling).  
**Fix once:** Grep `cmdarg_parse` then replace any subsequent `$1`/`$#`/`$@` with `argv[0]`/`argc`/`"${argv[@]}"`; add `shellcheck` rule `SC2120` + `bash -n` check in CI. Canonical: `clangc:38-53`.

### S2 — Hardcoded `/usr/bin/fd` vs declared `fd | fdfind (fd-find)` fallback (5+ scripts)
**What:** DEPENDENCIES correctly declares `fd | fdfind (fd-find)` (pipe fallback, parens override). Wrapper `fd.sh` hardcodes `/usr/bin/fd` and never tries `fdfind`, so on Debian where binary is `fdfind` and `init.sh` symlink was declined, `fd.sh` fails even though `checkDep` considered `fdfind` sufficient. `fd-all` missing fallback entirely.  
**Affected:** `fd.sh` itself (batch 18), `load-fonts` (01 — `fd.sh` via `fd.sh:21`), `fd-all` (05 — missing `fd|fdfind`), `fd-by-depth` (08 — `fd.sh` vs fallback gap), `init.sh` (12 — `/usr/bin/fd` hardcode + `collapseTilde` PATH dep), `tuckr-sync` (19 — `fd.sh: command not found` typo is the extreme case).  
**Fix once:** In `fd.sh`, `command -v fd || command -v fdfind` (not hardcoded path); document `init.sh` symlink creation as mandatory, not optional; add `checkDep`-aware helper `resolveFd()` reused everywhere. Only `fd | fdfind (fd-find)` in DEPENDENCIES is not a bug — document in brief §2.

### S3 — `set -e`/`pipefail` + `rg`/`fd`/`gum` non-zero exit → silent abort before `log-error` (6+ scripts)
**What:** `set -eo pipefail` at top + `trap 'exit 1' SIGUSR1` is intentional (brief §4). But pipelines that can legitimately return non-zero on no-match (`rg`, `fd`, `gum choose` cancel) then abort before the script can emit a user-facing `log-error` / `log-warning`. `pipefail` makes `rg` no-match (exit 1) fatal.  
**Affected:** `android-specs` (03 — `rg --short` no-match), `get-ip` (13 — `rg inet` no-match on VPN-only), `benchmark` (16 — `sec2time`/`shellJoinHumanQuote` mangling also `pipefail`-sensitive), `no-orphans` (16 — `gum choose` cancel), `load-fonts` (01 — `mapfile` + `no-dups` but also `rg` in `fd.sh` `fd` case), `git-commit` (09 — `rg` porcelain filter fragility).  
**Fix once:** Guard non-zero-expected commands: `rg ... || true`, `rg ... || log-warning ...`, `fd ... || true`, `gum ... || true`. Add pattern `rgNoMatch || true` helper.

### S4 — Missing `set -eo pipefail` / `trap 'exit 1' SIGUSR1` invariant violation (3+ scripts)
**What:** Brief §4 says every script starts with `set -eo pipefail` + `trap 'exit 1' SIGUSR1`. Some omit it (or `log-info` omits both, `log.sh` missing `trap` is intentional dispatcher but other leaves lack it) → SIGUSR1 from child `log-error` not trapped if this script is parent, and failures in `log.sh`/`input` won't abort.  
**Affected:** `log-info` (01 — missing both), `log.sh` dispatcher itself is intentional but any leaf script missing trap is a bug (grep `trap` across repo: 80% have it, 20% don't). Also `replace.sh`/`env-qoutes` edge cases where `isInteractiveShell` guard + `set -e` interact.  
**Fix once:** Enforce via `shellcheck` + `grep -L "trap.*SIGUSR1" $(fd -t x -E .git -E bin)` in CI; add to `mkscript` template (check `mkscript` batch 17 — it does include it, but generated scripts must).

### S5 — Undeclared / stale DEPENDENCIES (transitive sourcing fragility) (6+ scripts)
**What:** DEPENDENCIES block is the source of truth for `checkDep` + `getDeps` (brief §6). Some scripts declare `tput`/`awk`/`tr` (coreutils, normally excluded per AGENTS.md) or omit a binary they actually call, or rely on `check-deps` transitively pulling `lib/helpers.sh` for `log*`/`isPositive`/`Trim` etc. If `check-deps` ever stops sourcing helpers, they break.  
**Affected:** `log-warning` (01 — stale `tput`), `ls-colors` (01 — `awk`/`tr` listed but normally excluded; missing direct `lib/helpers.sh`), `oc-manager` (05 — missing `rg`), `get-ip` (13 — missing `net-interface` dep), `mdfmt` (21 — `isPositive` not in sourced libs), `ls-colors`/`catname`/`killwait` etc. missing `lib/helpers.sh` direct source, `shellfmt` (16 — hidden `tabs2spaces` not declared).  
**Fix once:** Audit `getDeps` output vs actual `command -v`/`grep -oE` calls; add `shellcheck` + `check-deps` dry-run in CI; keep `lib/helpers.sh` explicit in every script that calls `log*`/`isPositive`/`Trim` (like `clangc` does).

### S6 — `no-dups -a` vs `mapfile -t` newline/space confusion (3+ scripts, one critical)
**What:** `no-dups` without `-a` keeps newline separation (correct for `mapfile -t`); `-a` joins with spaces via `paste -sd " "` producing single line `"dir1 dir2"` that `mapfile -t` reads as one element containing a space. `load-fonts` critical bug is the manifestation; `ls-colors` correctly omits `-a` (confirmed correct). Same pattern repeats wherever `fd.sh … | no-dups | mapfile`.  
**Affected:** `load-fonts` (01 — critical), `ls-colors` (01 — confirmed correct, shows confusion), `gitignore-refresh` (11 — `no-dups` correct usage noted), `system-stats`/`catname`/`ocrshot` pipelines (12 — `no-dups` usage).  
**Fix once:** Document `no-dups` help: "Use `mapfile -t` → omit `-a`; use `read -ra`/`eval` → use `-a`." Grep `no-dups -a.*mapfile` as CI check.

### S7 — `argv[*]` vs `argv[@]` / `joinarr` / `shellJoinQuote` scalar-vs-array handling (5+ scripts)
**What:** `argv` is a bash array from `cmdarg`. Expanding `"${argv[*]}"` joins with first char of IFS (space) into single word; `"${argv[@]}"` preserves elements. `joinarr`, `shellJoinQuote`, `benchmark` comparisons, `install-ext-online` `--tries` token collapse are variants.  
**Affected:** `gitsync`/`rmbranch` (20 — `argv[*]`), `install-ext-online` (19 — collapsed `--tries` single token), `benchmark` (16 — `shellJoinHumanQuote` mangling), `watch.sh` (19 — `joinarr ','` single element), `spin.sh` (18 — `OPTARG` literal vs `$OPTARG`), `fd-by-depth` (08 — space-delimited sort).  
**Fix once:** Enforce `shellcheck SC2124`/`SC2145`; add `joinarr` helper that takes array name (like `compile.sh` namerefs) not scalar.

### S8 — `isInteractiveShell` guard silently suppresses required behavior non-interactively (3+ scripts)
**What:** `log-error`’s `kill -SIGUSR1 "${PPID}"` is guarded by `! isInteractiveShell` (correct per brief §4). But feature flags like `replace.sh -b`/`--backup` and `mdfmt` backup also gate on `isInteractiveShell`, so cron/ssh/piped runs silently skip backup.  
**Affected:** `replace.sh` (22 — `-b` ignored non-interactively), `mdfmt` (21 — similar), `log-error` itself is correct but any feature tied to `isInteractiveShell` inherits the silent-skip.  
**Fix once:** Separate “kill propagation” guard (correct) from “feature” guard (should be explicit `--force`/`--no-backup` flag, not TTY check). Grep `isInteractiveShell.*backup|backup.*isInteractiveShell`.

---

## Design Issues (per-script, lower priority — fragile but not crashing on happy path)

> One line per script + batch reference; full description + fix in batch files.

- **Batch 01:** `log-info` missing `set -eo pipefail`/`trap` (invariant violation); `log-warning` stale `tput` dep; `log.sh` silent `LEVEL` fallback to purple; `ls-colors` fragile transitive `helpers` sourcing via `check-deps`, `cut -d' ' -f2-` assumes `export` prefix.
- **Batch 03:** `cpp/release.sh` `mkdir -p` drift from `c/release.sh`; `updateSpicetify` `spicetify` undeclared + `sed` fragility; `echopass` hardcoded credential `echo hunter2`.
- **Batch 04:** `c/release.sh` `SCRIPTS_DIR` fallback `dirname` vs `$HOME/scripts` drift; `typescript/release.sh` word splitting + fallback mismatch (`deno`/`tsc`); `rofi-askpass` `dirname` PATH bug when sourced.
- **Batch 05:** `fd-all` missing `fd|fdfind` fallback; `customvscode` unguarded `sudo chown -R`; `oc-manager` stale `isRunning` check, shared `/tmp` collision, stray `trim` vs `Trim`.
- **Batch 06:** `fix-arabic-fonts` no guard + missing `helpers`/`checkDeps`; `print-args` manual `-q` bypasses `cmdarg`; `piper-say` missing `fd`/`gum` deps, `wc -l` fragile, `trim` casing.
- **Batch 07:** `readtime` 5 items (dead-code `if false` branch, `continue` skips OTF, silent wrong totals, `fd` vs `fdfind`); `pnpm-ls` `pnpm` undeclared + `jq` pre-check; `selcp` `xclip`/`wl-copy` deps `copyq` fallback missing.
- **Batch 08:** `ts-starter` `argc` vs `$1` + `jq` pre-check duplication; `fd-by-depth` `fd.sh` gap + space-delimited sort; `collapseTilde` `HOME` vs `SCRIPTS_DIR` confusion.
- **Batch 09:** `git-commit` porcelain `M` prefix fragility + `argv[*]` hygiene; `expandTilde`/`rustbook`/`font-search` 1-3 minor each (see batch 09).
- **Batch 10:** `copycat` wrong deps + silent `&&` clipcopy failure; `git_current_branch`/`git-root` transitive helpers fragility.
- **Batch 11:** `rename-spaces` collision + `find -print0` vs space handling; `yes.sh` only `argv[0]` + `sleep` throttle; `gitignore-refresh` empty commit under `set -e` + undeclared `now` dep.
- **Batch 12:** `init.sh` hard-coded `/usr/bin/fd` + `collapseTilde` PATH dep; `system-stats` `awk "%.0f%"` + `LC_ALL` unset; `catname` missing `--` + empty `argv`; `ocrshot` hidden `2>/dev/null` + undeclared `clipcopy`/`notify-send`.
- **Batch 13:** `external/pipes` `*) exit 0` swallows unknown args; `batwhich` `bat|batcat` runtime dispatch; `n` empty `NU_CONFIG` + `argv[*]` + `command` shadow.
- **Batch 14:** `net-interface` fragile `$5` + silent exit 0; `net-speed` no guard + coreutils deps listed; `get-package-manager` distro drift `mint`/`cachy` + duplication with `lib/helpers.sh`.
- **Batch 15:** `dotfiles.sh` `fd-by-depth` dep `tuckr` mismatch; `get-ext` `gum` undeclared + `fd` fallback; `daily.sh` missing `hostnamectl` + `gum` deps; `blank-image` `&&` masking; `banner` `mapColor` vs `shellfmt`.
- **Batch 16:** `shellfmt` hidden `tabs2spaces`, hard-coded `~/.config/.shellcheckrc`, fixed `/tmp/shellfmt.log`; `biome-check` hidden `is-git-repo`/`git-root`/`fd-by-depth`, `--config-path` file vs dir; `strip-ext` hidden `replace.sh`, double strip + `replace` all occurrences; `remove-blanks`/`insert-selection`/`kill-window` minor.
- **Batch 17:** `loop` `sleep` + `seq` fragility; `mvp` `mv -i` interactive hang + `isInteractiveShell` mis-gate; `update-biome` `biome` undeclared + `fd` fallback.
- **Batch 18:** `mdmath` `pandoc`/`tex` deps fragile + `set -e` `|| true` missing; `tmux-exec` `isInteractiveShell` inverted; `prepare-tts-text` `isPositive` undeclared; `pkgfind` `fzf`/`gum` missing; `joinarr` scalar-vs-array; `clean-pacman` `pacman`/`yay` drift.
- **Batch 19:** `vercel-status` `nushell` injection + `jq` missing; `install-ext-online` collapsed `--tries` token; `mkconf` `source` shadow + missing `TUCKR_DIR` default; `watch.sh` scalar-vs-array + `watchexec` single-token; `trim`/`unsetenv`/`toggleKB` 1-2 each.
- **Batch 20:** `tabs2spaces` `expand`/`unexpand` undeclared + `isPositive` missing; `make-signature` `figlet`/`lolcat` undeclared + `get-desc` fallback; `down-ext-file` `curl`/`wget` fallback + `sponge` undeclared; `image-text` `tesseract`/`convert` missing; `pkg-install` `paru`/`yay` drift.
- **Batch 21:** `make-caddy` `caddy` `sudo tee` without `askpass`; `no-dups` `sponge` undeclared + `sort -u` alternative; `ocrcp` `xclip`/`wl-copy` missing; `phpfmt` `php` `prettier` missing; `pkg-files` `pacman`/`expac` drift; `clipcopy` `xclip`/`wl-copy` missing.
- **Batch 22:** `spinner.sh` `isInteractiveShell` + `tput` missing; `ocr` `tesseract`/`gum` missing + `mktemp` cleanup; `kill-process` `fzf`/`ps` drift + `kill -9` without `checkDep`; `which-cpp` `clang`/`g++` undeclared; `is-git-repo` `git` undeclared; `killwait` `pgrep`/`pkill` missing.

---

## Style / Minor (collapsed to script-name lists per issue type — cheap to fix)

- **Missing quotes / word splitting / `shellcheck SC2086`:** `c/release.sh`, `typescript/release.sh`, `customvscode`, `fd-all`/`fd-by-depth`, `fix-arabic-fonts`, `copycat`, `rename-spaces`, `yes.sh`, `gitignore-refresh`, `system-stats`, `catname`, `get-ip`, `external/pipes`, `dotfiles.sh`, `renamefile`, `blank-image`, `banner`, `shellfmt`, `biome-check`, `strip-ext`, `mkscript`, `basedir`, `viewlines`, `mvp`, `spin.sh`, `mdmath`, `pkgfind`, `joinarr`, `clean-pacman`, `vercel-status`, `mkconf`, `watch.sh`, `trim`, `gitsync`, `no-dups`, `make-caddy`, `pkg-files`, `kill-process`, `is-git-repo` — 40+ scripts. Fix: `shellcheck --severity=warning` + `quote` all expansions.
- **Unquoted `trap 'rm -f $file'` / `mktemp` cleanup:** `watch.sh`, `replace.sh`, `ocr`, `mdfmt` — use `trap 'rm -f -- "$file"'`.
- **Hardcoded `/tmp` without `mktemp`:** `oc-manager` (`/tmp/oc-manager.lock`), `shellfmt` (`/tmp/shellfmt.log`), `benchmark` (`/tmp/benchmark.*`) — use `mktemp -d`.
- **Stale/verbose DEPENDENCIES (coreutils listed, normally excluded):** `log-warning` (`tput`), `ls-colors` (`awk`/`tr`), `net-speed`/`net-interface` (`awk`/`tr`), `shellfmt` (`tr`/`sed`/`grep`) — per `AGENTS.md` exclude coreutils.
- **Typos in DESCRIPTION / success messages:** `load-fonts` `succefully`, `log-info` `[SUCCESS]` vs `[INFO]`, `dotfiles.sh` `TUCKR_HOME` vs `TUCKR_DIR` — fix docs.
- **Missing `--` before `rm`/`mv`/`cp` with variable args:** `catname`, `renamefile`, `mkscript`, `no-orphans`, `rmwhich`, `load-fonts` — add `--`.
- **Bare `sudo` without `SUDO_ASKPASS` / `askpass`:** `load-fonts` (`sudo mv`, `sudo fc-cache`), `customvscode` (`sudo chown -R`) — use `SUDO_ASKPASS="$(getAskPass)" sudo -A`.
- **Use of `exit 0` in `*)` unknown arg handler (swallows error):** `external/pipes` `*) exit 0`, `oc-manager` unknown subcommand exits 0 — should `log-error` + `exit 1`.
- **Inconsistent `mkdir -p` before `touch`:** `c/release.sh` vs `cpp/release.sh` drift (one does `mkdir`, other doesn't) — unify via `lib/helpers.sh:touch()`.

---

## Open Questions for Repo Owner (aggregated — needs human decision, not another review pass)

1. **Batch count vs focus** (from plan Q1, now resolved): Pilot + 21 remaining = 22 batches keeps every batch 269-410 (large) or 616-728 (small) and ≤12/≤4 caps. Owner confirmed “more batches > dense” — 22 is now the locked count. Confirm 22 is acceptable or merge small batches to 19?
2. **Large+fillers incidental pairing** (12 batches): `create-wiki` + `pdfx` etc. are incidental, not a shared pattern — should any large tool be re-batched with family-related fillers (e.g., `create-wiki` with `document-with-llm`/`mdfmt`/`mdclean` docs family) or keep line-budget packing?
3. **`fd` fallback contract:** Should `fd.sh` honor `fdfind` via `command -v fd || command -v fdfind` or is `init.sh` symlink creation (`/usr/bin/fd → $(command -v fdfind)`) considered mandatory, making `fd|fdfind` in DEPENDENCIES purely an install prompt? Affects `load-fonts`, `fd.sh`, `fd-all`, `init.sh`, `tuckr-sync` design fixes.
4. **`load-fonts` `continue` semantics:** `continue` after TTF move skips OTF in same dir — intentional single-type-per-dir assumption or should move both? DESCRIPTION doesn't state; data-loss vs performance trade-off.
5. **`ls-colors` `cut -d' ' -f2-` assumption:** `variables.sh` guaranteed `export U_...` or should parser handle bare `U_...=`? Affects `ls-colors` fix (grep `U_` vs cut).
6. **`log.sh` LEVEL validation:** Unknown `LEVEL` currently silent fallback to `printPurple`/`fd1` and prints `[TYPO]` — should be loud error (`log-error` + exit 1) or silent ergonomic fallback for ad-hoc `log.sh "CUSTOM"`?
7. **`init.sh` shell support:** `init.sh` prompts to symlink `fdfind→fd` with `sudo ln -sv`. If user declines, should `checkDeps` still try `fdfind` fallback or fail closed? Docs decision 011 says symlink deferred.
8. **`isInteractiveShell` for backups:** `replace.sh -b` and `mdfmt` backup gated on `isInteractiveShell` → silently skipped non-interactively (cron). Should be explicit `--no-backup` flag instead of TTY check?
9. **`no-orphans` keep-list vs remove-list:** Current `gum choose` (keep) → re-adds kept packages to removal list → data loss. Is intended behavior “choose to keep” or “choose to remove”? Fix inverts logic.
10. **`rmwhich` deletion guard:** Should `rmwhich` restrict deletion to `$SCRIPTS_DIR` or `$HOME/scripts` owned files only, not any `$PATH` binary? Currently deletes any executable including system binaries — security question.
11. **`mkscript` `SCRIPTS_DIR` fallback:** When `SCRIPTS_DIR` empty and positional flow used, `file="/${name}"` → `//name`. Should default to `${HOME}/scripts` or fail closed with `log-error`?
12. **`vercel-status` Vercel field handling:** Vercel `projectName`/`username` may contain single quotes — should sanitize via `shellQuote`/`humanQuote` or base64-encode before `nushell -c`?
13. **`check-deps` `getAskPass` clobber:** Should `getAskPass` refuse to overwrite existing system `askpass` (`command -v askpass` check) or version it to `askpass.bak`?
14. **`switch-branch` slash handling:** `tr -d "/"` corrupts `feature/login`. Should be `tr -d ' '` or no stripping? Origin decision 004 collision detection?
15. **`tuckr-sync` `fd.sh` typo:** `fd.sh` command not found — is intended `fd`/`fdfind` or wrapper `fd.sh`? Fix determines whether to declare `fd` dep.
16. **`fd-by-depth` sorting:** `sort` without `-V`/`-n` — should be `sort -V` for version-like depth or keep lexical?
17. **Template strictness (Q3 resolved):** Pilot added Evidence appendix and passed (allowed). Confirm Evidence appendix is desired for all batches or only pilot?
18. **`get-package-manager` distro drift:** `mint`/`cachy`/`endeavouros` not in `lib/helpers.sh:getPackageManager` but in `get-package-manager` script — should unify or keep separate?
19. **Binary scope (Q5 resolved):** `bin/*` excluded from review. Confirm no bash wrappers in `bin/` need review (e.g., `get-terminal-size` 16160 bytes, `sec2time` 270280 bytes — are these compiled Rust/Go or bash? `file bin/*` shows?)

---

## Verification

- **Prerequisites:** `fd -t x -E .git -E bin --hidden -x wc -l | awk '{s+=$1;c++} END{print c,s,s/c}'` → 144 tracked executables, 9904 lines, avg 69. `ls docs/code-reviews/batch-*.md | wc -l` = 22. `ls docs/code-reviews/batch-01.md` exists + 365 lines. `ls docs/code-reviews/house-style-brief.md` = 61 lines, 8 flat-fact sections.
- **Phase 1 batching:** Every batch 269-728 lines, ≤12 scripts, and any batch containing a >150-line script has ≤4 scripts (12 large batches at 269-410/4, 9 small at 616-655/9-10, pilot 370/8). `fd` distribution re-checked before dispatch; `.git` and `bin` excluded.
- **Phase 2 dispatch:** Each subagent prompt contained in order: house-style brief → 10 core files (or paths) → batch scripts (full contents) → template → “Fill House Style Reference first” instruction. Subagents confirmed by restating brief in own words (7 one-liners) before reviewing. No subagent inferred from filename.
- **Phase 3 collect:** Each batch report stored verbatim as `docs/code-reviews/batch-0N.md` (audit trail). Running critical-bugs index built at `docs/code-reviews/critical-index.md` (29 lines). Cross-batch patterns identified by `grep -h "Critical bugs\|Design issues\|Systemic" batch-*.md` and manual scan for ≥3 occurrences.
- **Phase 4 report:** This file at `docs/code-reviews/final-report.md` with required sections: Critical bugs index (per-script), Systemic patterns (8 patterns, each with all affected scripts), Design issues (per-script one-liners, batch provenance), Style/minor (collapsed by issue type), Open questions (19 aggregated). Per-script detail proportional to severity (full write-ups for critical in batch files, one-liners for style here).
- **House-style false-positive check:** No batch flagged `log-success` vs `logSuccess`, `trap SIGUSR1` alone, or `fd | fdfind (pkg)` as a bug; all such cases appear in “Confirmed correct” sections (e.g., batch 01 `Confirmed correct` for `include` indirection + `log.sh` delegation + empty DEPENDENCIES). Brief improved after pilot (no change needed; pilot’s “Confirmed correct” already matched brief §2/§3/§4).

---

## Handoff — Next Steps

1. **Triage critical index:** Owner sorts 29 bugs by `Critical bug` (15 scripts) vs `Needs fixes` with embedded critical (6 scripts) — start with data-loss bugs: `no-orphans`, `env-qoutes`, `rmwhich`, `mkscript`, `load-fonts`, `benchmark`.
2. **Systemic fixes:** For S1-S8, create one refactor ticket per pattern (e.g., “S1: Migrate all `cmdarg_parse` callers from `$1` to `argv`”), not 7 duplicated per-script fixes. Each ticket references all affected scripts.
3. **Design/style:** Batch files contain per-script fixes; style/minor can be batched as one `shellcheck --fix` + `quote` sweep.
4. **Open questions:** Owner answers 19 questions above; subagents must not guess — answers patch brief and trigger re-review of affected batches only.
5. **Tooling:** Add CI checks: `fd -t x -E .git -E bin --hidden -x wc -l` distribution drift alert, `grep -L "trap.*SIGUSR1"` + `grep -L 'set -eo'` + `shellcheck --severity=warning` + `bash -n` + `check-deps` dry-run.

Artifacts: `docs/code-reviews/house-style-brief.md`, `docs/plans/2026-08-20-subagent-review-orchestration-plan.md`, `docs/code-reviews/batch-*.md` (22), `docs/code-reviews/critical-index.md`, `docs/code-reviews/final-report.md` (this file).

