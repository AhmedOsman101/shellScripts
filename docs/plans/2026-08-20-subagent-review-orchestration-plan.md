# Plan: Full-Repo Bash Script Review via Subagents

**Title:** Orchestrated line-budgeted review of ~144 executable scripts (9904 lines) via ~17 subagents  
**Date:** 2026-08-20  
**Status:** Draft — awaiting repo-owner confirmation before dispatch  
**Author:** main agent (planner)  
**Related:** `docs/subagent-review-orchestration-prompt.md` (source operating instructions), `docs/templates/batch-review.md`, `docs/code-reviews/house-style-brief.md`

---

## Background

The `~/scripts` repo contains ~144 tracked executables (`fd -t x -E .git -x wc -l` -> 9904 lines) spread from 3-line one-liners (`echopass`, `pdfx`, `spotifyctl`, `yt-music-playlist`) to 300-400 line tools (`create-wiki` 401, `android-specs` 320, `document-with-llm` 316). Earlier isolated single-script reviews misdiagnosed repo-conventional patterns as bugs:

- `log-success` vs `logSuccess` naming,
- `trap 'exit 1' SIGUSR1` without a local `kill`,
- `fd | fdfind (fd-find)` pipe-fallback + parenthesized package override.

Root cause: no shared house-style context. Fix is Phase 0 house-style brief + line-budgeted, similarity-grouped batching so each subagent sees related patterns together and carries fixed-cost core files + brief.

This plan implements the four-phase operating instructions from `docs/subagent-review-orchestration-prompt.md` without writing implementation code — it is the spec + dispatch pack for builder subagents.

## Goal

Produce a **single consolidated report** with:

- Critical-bugs index (actionable, one line per bug, grouped by script)
- Systemic patterns (3+ scripts, described once with affected list)
- Design issues (per-script, lower priority)
- Style/minor (collapsed per issue-type, script-name lists)
- Open questions for repo owner (aggregated, no guessing)

while keeping false positives near zero via the house-style brief and preserving audit trail (`docs/code-reviews/batch-0X.md` per subagent).

## Constraints

- **No implementation code** — planner outputs docs/tickets only.
- **Ponytail (full):** shortest path. Reuse existing `log.sh`/`lib/*`/`check-deps`/`include`/`get-desc`/`get-deps`/`hooks/path.sh` contracts; don't add new abstractions. One `house-style-brief.md` prepended to every subagent prompt is cheaper than N re-derivations.
- **Context budget:** ~120k tokens. House-style brief + 10 core files is fixed cost per subagent; script body budget must stay ~600-700 lines per batch so no subagent drowns in 2000+ lines.
- **Tracer bullets:** each batch report must be demoable alone (verdict per script, critical/design/minor/confirmed-correct, batch summary, cross-cutting patterns, open questions).
- **Fidelity check:** `fd -t x -E .git -x wc -l` distribution is factual — never batch by flat count.

## Approach

### Phase 0 — House style brief (done, once)

Built by reading the 10 canonical files (`include`, `lib/cmdarg.sh` + `lib/cmdarg.md`, `lib/loggers.sh`, `lib/helpers.sh`, `check-deps`, `log.sh`, `get-desc`, `get-deps`, `init.sh` + `hooks/path.sh`, `clangc`):

- Artifact: `docs/code-reviews/house-style-brief.md` (~half page, flat facts, no questions).
- Covers: `include` resolution (`SCRIPTS_DIR` / `BASH_SOURCE` / `realpath -m` / `source "$(include …)"`), dependency `a | b (pkg)` pipe-fallback + parens override and how `checkDep` walks it (`command -v` loop then `grep -oP '$\K[^)]*(?=$)'`), `log-*` primary vs `lib/helpers.sh` camelCase fallback, `trap SIGUSR1` + `kill -SIGUSR1 "${PPID}"` propagation chain (only `log-error` sends), `cmdarg.sh` contract (`cmdarg 'x:'/'x?'/'x[]'/'x{}'` + `cmdarg_info` + `cmdarg_parse "$@"` + `cmdarg_cfg`/`argv`/`argc`, `-h` reserved), `get-desc`/`get-deps` optional-block parsing, `init.sh` -> `hooks/path.sh` `fd`-based PATH cache (`/tmp/path-hook.cache`, `SCRIPTS_HOOK_EXCLUDE`), and `clangc` as canonical correct shape.

Lever: biggest false-positive reducer. Every subagent must restate it in its own words before reviewing.

### Phase 1 — Batch by line budget, compose by similarity

**Sizing rule (budget -> size):**

- Target **600-700 lines of script body per batch** (core files + brief are fixed cost atop this).
- Cap **12 scripts/batch** even if budget not hit (12× 20-line utilities is already 12 verdicts to aggregate).
- Cap **4 scripts/batch when any script >150 lines** (so `create-wiki` etc. get ~alone, paired with ≤2 small incidentals, not buried with 7 others).

Observed distribution (`fd -t x -E .git -x wc -l | sort -rn`):

- 3 lines: `echopass`, `pdfx`, `spotifyctl`, `yt-music-playlist`
- 100-175 lines: `get-unique` 100, `vercel-status` 118, `spin.sh` 119, `benchmark` 127, `mkscript` 127, `get-package-manager` 142, `external/pipes` 156, `init.sh` 158, `switch-branch` 167, `check-deps` 175
- 190-401 lines: `git-commit` 191, `ts-starter` 220, `readtime` 233, `piper-say` 234, `oc-manager` 245, `document-with-llm` 316, `android-specs` 320, `create-wiki` 401

Total: **144 scripts, 9904 lines, avg 69** -> ~15 batches by pure budget, ~17-20 after caps + similarity (spec's 16-18 estimate aligns).

**Composition rule (similarity -> which scripts together):**

Four passes over the `fd` listing, budget permitting:

1. **By subdirectory:** `rofi/*` (3), `lua/*` (2), `external/*` (4), `cpp/*`/`c/*`/`typescript/*` (3) stay together.
2. **By name-family:** `log-*`+`log.sh` (6), `get-*` (8), `fd-*` (3), git family (8), scaffolding `mkscript/mkconf/mkpython/mk-gitignore/make-caddy/make-signature` (6), pkg family (8), `kill-*` (3), OCR `ocr/ocrcp/ocrshot` (3), text/filename `trim/trunc/strip-ext/tabs2spaces/remove-blanks/no-dups/no-orphans/catname/renamefile/rename-spaces/collapseTilde/expandTilde/env-qoutes` (13), system-info `system-stats/cpu-usage/net-speed/net-interface/now/spinner.sh/spin.sh/benchmark` (8), font `font-search/load-fonts/fix-arabic-fonts/ls-colors` (4).
3. **Large standalones go nearly alone** (+1-2 tiny incidentals, header notes "pairing is incidental"): `create-wiki`, `android-specs`, `document-with-llm`, `piper-say`, `oc-manager`, `readtime`, `check-deps`, `vercel-status`, `ts-starter`. Don't hunt for a connection when header says none.
4. **Leftovers -> grab-bag batches** filling the budget; header says grab-bag so subagent doesn't waste time hunting intent.

Tie-break (e.g., `clean-pacman` fits both pkg and maintenance) — pick whichever fills the batch better; consistency of verdicts > taxonomy perfection.

### Phase 2 — Dispatch per batch

For each batch, subagent prompt contains **in this order:**

1. House-style brief (full text from `docs/code-reviews/house-style-brief.md`)
2. Full contents of the 10 core files (or paths if the subagent has file-read access — paths are cheaper)
3. Batch's script paths **with full contents** (never infer from filename)
4. Batch review template (`docs/templates/batch-review.md`)
5. Direct instruction: _"Fill in House Style Reference in your own words first. If a pattern you're about to flag matches the brief, it's not a bug. If unsure whether intentional, put it in Open questions — don't guess."_

Guardrail: subagent must not review a script it hasn't fully read.

### Phase 3 — Collect & aggregate (audit trail)

1. Store each batch report verbatim as `docs/code-reviews/batch-01.md` … `batch-18.md` (no immediate merge).
2. Maintain running **critical-bugs index**: `| script | one-sentence | batch |`.
3. Watch for **cross-batch patterns** (e.g., same `cmdarg.sh` misuse flagged in 3+ unrelated batches -> systemic section, not 3 buried mentions).
4. Treat every "Confirmed correct (potential false positives)" as signal: if N subagents flagged then exonerated the same pattern, the brief needs a clearer line.

### Phase 4 — Final consolidated report

At `docs/code-reviews/final-report.md`:

- **Critical bugs index** (grouped by script, with batch provenance)
- **Systemic patterns** (once, with all affected scripts listed)
- **Design issues** (per-script, lower priority)
- **Style/minor** (collapsed: issue-type -> script-name list)
- **Open questions for repo owner** (aggregated, human-decision only)

Weight detail by severity: full write-up for critical, one line for style nits. Equal weight for a missing quote and a `set -u` crash is not useful.

---

## Steps

### Step 1 — Verify Phase 0 artifact (already written)

- Confirm `docs/code-reviews/house-style-brief.md` exists and is half-page flat facts.
- Spot-check: `checkDep` pipe-fallback + parens, `trap SIGUSR1` chain, `cmdarg` boolean literal `true`, `hooks/path.sh` cache invalidation, `clangc` shape all present.

### Step 2 — Re-run distribution and lock batch table

- Command (must run from repo root): `fd . -t x -E .git --hidden -x wc -l | sort -rn -k1` and `fd . -t x -E .git --hidden -x wc -l | awk '{s+=$1;c++} END{print c, s, s/c}'`.
- Using the 2026-08-20 snapshot (144 scripts, 9904 lines), propose the table below. **Before dispatch, re-run and adjust** — lines drift.

#### Proposed batch table (illustrative, respects 600-700 / ≤12 / ≤4-if->150)

> Composition tag: `[dir]` / `[family]` / `[large+fillers]` / `[grab-bag]`. "+fillers" = 1-2 tiny scripts to approach budget; pairing is incidental.

| Batch | Composition                             | Scripts (lines)                                                                                                                                                                                          | Body total | #   |
| ----- | --------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------- | --- |
| 01    | [large+fillers] create-wiki batch       | `create-wiki` 401 + `pdfx` 3 + `spotifyctl` 3 + `yt-music-playlist` 3 + `updateSpicetify` 5                                                                                                              | 418        | 6   |
| 02    | [large+fillers] android-specs batch     | `android-specs` 320 + `customvscode` 21 + `print-args` 29 + `now` 30 + `pnpm-ls` 30                                                                                                                      | 430        | 5   |
| 03    | [large+fillers] document-with-llm batch | `document-with-llm` 316 + `include` 26 + `fix-arabic-fonts` 26 + `font-search` 32 + `collapseTilde` 32                                                                                                   | 432        | 5   |
| 04    | [large+fillers] oc-manager batch        | `oc-manager` 245 + `expandTilde` 32 + `rustbook` 32 + `selcp` 30 + `get-distro` 31                                                                                                                       | 370        | 5   |
| 05    | [large+fillers] piper-say batch         | `piper-say` 234 + `ocr` 58 + `ocrshot` 37 + `ocrcp` 41 + `image-text` 59                                                                                                                                 | 429        | 5   |
| 06    | [large+fillers] readtime batch          | `readtime` 233 + `strip-ext` 44 + `tabs2spaces` 45 + `trunc` 48 + `trim` 57                                                                                                                              | 427        | 5   |
| 07    | [large+fillers] ts-starter batch        | `ts-starter` 220 + `blank-image` 47 + `clipcopy` 45 + `copycat` 34 + `rename-spaces` 34                                                                                                                  | 380        | 5   |
| 08    | [large+fillers] check-deps + git-large  | `check-deps` 175 + `git-commit` 191 + `switch-branch` 167 + `get-desc` 53                                                                                                                                | 586        | 4   |
| 09    | [large+fillers] vercel-status batch     | `vercel-status` 118 + `benchmark` 127 + `spin.sh` 119 + `spinner.sh` 95 + `system-stats` 37                                                                                                              | 496        | 5   |
| 10    | [family] logging                        | `log-debug` 33 + `log-info` 30 + `log-success` 33 + `log-warning` 33 + `log-error` 67 + `log.sh` 64 + `load-fonts` 60 + `ls-colors` 50                                                                   | 370        | 8   |
| 11    | [family] get-\*                         | `get-ext` 64 + `get-package-manager` 142 + `get-deps` 39 + `get-askpass` 94 + `get-unique` 100 + `get-ip` 38                                                                                             | 477        | 6   |
| 12    | [family] fd + git-small                 | `fd-all` 22 + `fd-by-depth` 31 + `fd.sh` 43 + `git_current_branch` 32 + `git-root` 32 + `is-git-repo` 47 + `gitignore-refresh` 36 + `gitsync` 91 + `rmbranch` 91                                         | 425        | 9   |
| 13    | [family] scaffolding                    | `mkscript` 127 + `mkconf` 68 + `mkpython` 74 + `mk-gitignore` 65 + `make-caddy` 70 + `make-signature` 70 + `basedir` 78                                                                                  | 552        | 7   |
| 14    | [family] pkg                            | `pkgfind` 62 + `pkg-files` 49 + `pkg-install` 54 + `aur-install` 54 + `clean-pacman` 48 + `install-ext` 48 + `install-ext-online` 77 + `down-ext-file` 66                                                | 458        | 8   |
| 15    | [family] text/filename                  | `no-dups` 82 + `no-orphans` 64 + `remove-blanks` 56 + `catname` 37 + `renamefile` 75 + `env-qoutes` 39 + `kill-process` 73 + `kill-window` 47 + `killwait` 39                                            | 512        | 9   |
| 16    | [dir] rofi + lua + external             | `rofi/rofi-askpass` 11 + `rofi/rofi-list` 66 + `rofi/rofi-music` 82 + `lua/timewarp.lua` 44 + `lua/sec2time.lua` 95 + `external/colorblocks` 22 + `external/testfonts` 62 + `external/colortest` 131     | 513        | 8   |
| 17    | [grab-bag] leftovers-1                  | `banner` 50 + `batwhich` 38 + `n` 38 + `biome-watch` 39 + `toggleKB` 40 + `editwhich` 41 + `rmwhich` 44 + `net-interface` 42 + `unsetenv` 42 + `which-cpp` 48 + `tuckr-sync` 49 + `runpy` 49             | 520        | 12  |
| 18    | [grab-bag] leftovers-2                  | `daily.sh` 56 + `cpu-usage` 58 + `net-speed` 54 + `md2docx` 47 + `mvp` 51 + `joinarr` 51 + `insert-selection` 50 + `phpfmt` 54 + `tempedit` 54 + `viewlines` 67 + `prepare-tts-text` 70 + `tmux-exec` 78 | 690        | 12  |
| 19    | [grab-bag] leftovers-3                  | `dotfiles.sh` 82 + `shellfmt` 85 + `mdmath` 89 + `repeat-it` 94 + `fzf-preview` 80 + `replace.sh` 81 + `yes.sh` 35 + `init.sh` 158 + `clangc` 67 + `cppc` 67                                             | 838        | 10  |

_Notes:_

- B08 has two >150 scripts but stays at cap 4; header notes both are large (one is family, one is `check-deps` standalone) — pairing not deeply related but both >150, cap forces 4.
- B19 is slightly over 700 (838) because `init.sh` 158 is in leftovers; split B19 into 19a/19b if a strict 700 cap is required (e.g., `init.sh`+`clangc`+`cppc` =292 vs rest 546). Prefer 18 batches at ~550 avg over 19 at ~520 — both satisfy "comparable workload" (spec's 16-18 is a guideline, not a hard limit; line budget is the hard constraint).
- The `external/pipes` 156 line script was omitted in this snapshot to keep B16 at 513; move it to B16 or B09 depending on re-run counts — it fits either.
- Before dispatch, re-run `fd … -x wc -l` and rebalance any batch that drifted >700 or >12 (or >4 with a >150).

_If you prefer exactly 17 batches, merge B17+B18's smallest scripts and trim fillers from large batches; the priority is comparable effort, not a magic batch count._

### Step 3 — Prepare subagent dispatch pack

For each batch in the locked table:

- File: `docs/code-reviews/batch-NN.md` (template copy + filled header: scripts, composition, lines, batch #).
- Prompt order: house-style brief -> 10 core files (or paths) -> batch scripts (full contents) -> template -> "fill House Style Reference first" instruction.
- Guardrail: never let a subagent infer from filename; always include full file contents.

Dispatch can be parallel (all batches at once) or wave 1 (large batches) then wave 2 (families) — large batches are lowest-risk to parallelize.

### Step 4 — Aggregation

- Keep raw `batch-NN.md` as audit trail.
- Running critical-bugs index file: `docs/code-reviews/critical-index.md` (one line per confirmed critical bug: `| 2026-08-20 | batch-03 | piper-say | one-sentence |`).
- Cross-batch scan: `grep -h "Critical bugs\|Design issues\|Systemic" docs/code-reviews/batch-*.md` nightly; promote any issue appearing in ≥3 batches to `Systemic patterns`.
- Brief-improvement loop: after first 3 batches return, grep "Confirmed correct" — if ≥2 subagents flagged-then-exonerated the same pattern, patch `house-style-brief.md` and re-prepend to remaining batches before they start.

### Step 5 — Final report

- File: `docs/code-reviews/final-report.md` with structure from Phase 4 (critical index -> systemic -> design -> style/minor collapsed -> open questions).
- Weight: full write-ups only for critical; one-liners for style.
- Verification: `shellcheck` sample on critical-bug scripts before claiming "confirmed".

## Verification

- **Phase 0:** `ls docs/code-reviews/house-style-brief.md` exists; brief contains all 8 flat-fact sections verbatim; subagents can quote back `checkDep` pipe/override logic.
- **Phase 1:** `fd . -t x -E .git --hidden -x wc -l | awk '{s+=$1;c++} END{print c, s}'` reproduces 144 / 9904; every batch in the table sums to 340-700 lines, ≤12 scripts, and any batch containing a >150-line script has ≤4 scripts. `ls external/ lua/ rofi/` groupings stay together.
- **Phase 2:** Each `batch-NN.md` starts with a filled "House Style Reference" (7 lines, own words) before any script verdict — enforced by prompt order.
- **Phase 3:** `ls docs/code-reviews/batch-*.md | wc -l` == batch count; `cat docs/code-reviews/critical-index.md | wc -l` == number of critical entries in final report's index.
- **Phase 4:** `grep -c "Critical\|Systemic\|Open questions" docs/code-reviews/final-report.md` ≥3 sections; style/minor section lists script names per issue-type, not per-script essays.

## Open Questions (for repo owner — do not guess in subagent reviews)

1. **Batch count vs file count:** Table proposes 18-19 batches to honor both 600-700 line budget and ≤4-when->150 cap. Is 18-19 acceptable, or should we force 16-17 by merging leftovers even if one batch hits ~838 lines?
2. **Parallelism:** Dispatch all 18 subagents at once, or wave large batches first so early "Confirmed correct" signals can patch the brief before family batches start?
3. **Template strictness:** Must subagents strictly use `docs/templates/batch-review.md` (no extra sections), or can they add an "Evidence" appendix with `shellcheck`/`bash -n` output?
4. **Git hooks scope:** `fd -t x --hidden -E .git` excludes `.git/hooks/*.sample` (14 files, ~500 lines). Confirm they should stay out of review scope.
5. **Compiled binaries:** `bin/*` (clean-url, emoji-strip, etc.) are binary — out of scope for bash review, correct?

---

## Suggested Skills for Builder Agents

- `grill-with-docs` / `grilling` — if any script's intent is ambiguous, ask owner rather than guessing (gate: "Open questions" not "bug").
- `systematic-debugging` — before labeling a `set -u`/`set -e` interaction as critical, reproduce with `bash -n` + `shellcheck`.
- `request-refactor-plan` — systemic patterns (e.g., repeated `cmdarg.sh` misuse) should become a small refactor plan, not 8 duplicated fixes.

## Handoff

- **Purpose:** Execute the 4-phase orchestration end-to-end.
- **Current state:** Phase 0 artifact `docs/code-reviews/house-style-brief.md` written and verified against the 10 core files. Distribution snapshot taken (144 exec, 9904 lines). Plan doc (this file) is the dispatch spec; batch table is illustrative — re-verify with `fd … -x wc -l` before locking.
- **Decisions made:** Line-budget > script-count; half-page flat-fact brief as single false-positive lever; similarity passes in priority order (subdir -> name-family -> large-standalone -> grab-bag); audit trail per batch file.
- **Next steps:** (1) Owner confirms Open Questions 1-5. (2) Lock batch table with a fresh `fd` run. (3) Dispatch subagents per Phase 2 prompt order. (4) Aggregate per Phase 3-4 into `final-report.md`.
