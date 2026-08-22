# Critical Bugs Index — Running List (one line per confirmed critical bug)

> Generated from 22 batch reports (2026-08-21). Use this as the actionable list. Grouped by script.

| # | Script | One-sentence bug | Batch | Severity |
|---|--------|-----------------|-------|----------|
| 1 | `load-fonts` | `no-dups -a` + `mapfile -t` collapses multi-dir list to single element (`"dir1 dir2"`), `mv -t` fails silently; plus `continue` skips OTF in mixed dirs | 01 | Needs fixes |
| 2 | `android-specs` | `--short` filter regex too narrow + `set -o pipefail` makes non-matching `rg` exit 1 trigger `set -e` kill | 03 | Needs fixes |
| 3 | `document-with-llm` | hash-based change detection dead code — existing page skipped unless `--force`, incremental docs never update; also `claude` hardcodes `opus`, `projectHash` hangs on empty dir | 04 | Critical bug |
| 4 | `oc-manager` | missing `rg` dep causes 15s timeout with generic error; unknown subcommand exits 0 not 1 | 05 | Needs fixes |
| 5 | `piper-say` | `checkCache` bare call returns 1 on miss → `set -e` exits before `generateAudio`; also `viewlines` args reversed, empty `playerCmd` execs | 06 | Critical bug |
| 6 | `check-deps` | `getAskPass` overwrites existing system `askpass` binary on PATH | 10 | Critical bug |
| 7 | `switch-branch` | `tr -d "/"` strips all slashes → `feature/login` → `featurelogin`, checkout fails for hierarchical branches | 11 | Critical bug |
| 8 | `get-ip` | `set -o pipefail` + `rg` no-match abort before `log-error` on VPN-only/`inet6`-only or empty `net-interface` | 13 | Needs fixes |
| 9 | `mkpython` | no positional arg creates bogus `python/.py` / `~/scripts/.py` or empty `name` → `touch` fails | 14 | Critical bug |
| 10 | `runpy` | no args → `strip-ext ""` → pattern `//main\.py$` + multi-line mishandling | 14 | Critical bug |
| 11 | `dotfiles.sh` | `TUCKR_HOME` vs `TUCKR_DIR` mismatch (canonical `TUCKR_DIR` not used) → wrong search path | 15 | Needs fixes |
| 12 | `renamefile` | same-file check `old==new` unreachable when `oldDir==newDir`, deep same-file missed | 15 | Needs fixes |
| 13 | `lua/timewarp.lua` | `tonumber(nil)` → `nil` → `gamma = nil` raises `attempt to perform arithmetic on nil` | 15 | Needs fixes |
| 14 | `benchmark` | `Bad substitution` on every timing aggregation (`${ cmd; }`) + `sec2time`/`shellJoinHumanQuote` mangling, `printf` arity | 16 | Critical bug |
| 15 | `no-orphans` | keep-list inverted: kept packages re-added to removal list → data loss (removes packages user asked to keep) | 16 | Critical bug |
| 16 | `env-qoutes` | `awk -F=` truncates `=` in values, corrupts comments via `sponge`, `.env` silently mangled | 16 | Critical bug |
| 17 | `mkscript` | `SCRIPTS_DIR` undefined in positional flow → `file="/${name}"` expands to `//name` → `touch` fails / writes to root | 17 | Critical bug |
| 18 | `rmwhich` | deletes any executable on `$PATH` including system binaries, no `SCRIPTS_DIR` guard | 17 | Critical bug |
| 19 | `spin.sh` | `spinnerStart -c <color>` maps literal `OPTARG` not `$OPTARG` → color never applied | 18 | Critical bug |
| 20 | `tmux-exec` | inverted `yesNo` confirmation: "y" aborts, "n" proceeds to kill — opposite | 18 | Critical bug |
| 21 | `vercel-status` | single-quote in Vercel field breaks nushell invocation / code injection (projectName/username) | 19 | Needs fixes |
| 22 | `watch.sh` | interactive extension collection produces single array element → `joinarr ','` emits no commas | 19 | Needs fixes |
| 23 | `tuckr-sync` | typo `fd.sh: command not found` (should be `fd`/`fdfind` fallback), script fails immediately | 19 | Critical bug |
| 24 | `rmbranch` | `git branch -D --remote` deletes local tracking ref `origin/<branch>`, never contacts remote | 20 | Critical bug |
| 25 | `editwhich` | `$1` vs `argv[0]` sentinel break: `editwhich -- ls` checks `command -v "--"` → false "Script ls doesn't exist!" | 20 | Critical bug |
| 26 | `lua/sec2time.lua` | both branches log but fall through `tonumber(nil) → 0 → print("")` instead of exiting, non-terminating | 21 | Needs fixes |
| 27 | `make-caddy` | `cmdarg` required args with empty default → `Missing arguments` on no-arg invocation (should be optional) | 21 | Needs fixes |
| 28 | `mdfmt` | `isPositive` not defined in sourced libs → `bash: isPositive: command not found` | 21 | Critical bug |
| 29 | `replace.sh` | `-b`/`--backup` silently ignored non-interactively (cron/ssh/piped) due to `isInteractiveShell` guard | 22 | Needs fixes |

Counts: 29 bugs across 22 batches, 21 scripts. Verdict `Critical bug` = 15 scripts, `Needs fixes` with embedded critical = 14 scripts. All stored verbatim in `docs/code-reviews/batch-*.md`.
