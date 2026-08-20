# Orchestrating a Full-Repo Bash Script Review via Subagents

Use this as the main agent's operating instructions when reviewing the ~150-script
repo in batches. The goal is deep, accurate per-script review without every
subagent re-deriving the repo's conventions from scratch, and without the main
agent drowning in 150 individual reports at the end.

## Phase 0: Build the house style brief (main agent, once)

Before dispatching any subagent, read these ten files yourself and produce a
single "house style brief", roughly half a page, that gets prepended to every
subagent's prompt:

1. `include`
2. `lib/cmdarg.sh` and `lib/cmdarg.md`
3. `lib/loggers.sh`
4. `lib/helpers.sh`
5. `check-deps`
6. `log.sh`
7. `get-desc`
8. `get-deps`
9. `init.sh` and `hooks/path.sh`
10. `clangc` (reference example of correct usage)

The brief should state, as flat facts, not questions:

- How `include` resolves and sources library paths.
- The dependency block syntax (`# - bin | bin2 (pkg-override)`) and exactly how
  `checkDep` walks it, including the pipe-fallback and parenthesized override
  behavior.
- That `log-*` scripts are the primary logging interface repo-wide, and the
  camelCase `log*` functions in `lib/helpers.sh` are a
  fallback layer, not a bug when camelCase appears to be unused directly.
- The `trap 'exit 1' SIGUSR1` + `kill -SIGUSR1 "${PPID}"` chain: this is a
  deliberate cross-script kill propagation mechanism, not leftover debug code.
- The `cmdarg.sh` argument-parsing contract, and what a script using it
  correctly looks like.
- `get-desc` / `get-deps` signature-block parsing rules, so subagents don't
  flag scripts for "missing" sections that are actually optional.
- The `init.sh` / `hooks/path.sh` symlink and PATH-registration flow, so
  subagents understand why a script might not need to handle its own PATH
  setup.
- What `clangc` does right, as the canonical positive example.

This brief is the single biggest lever against false positives. Every bug I
misdiagnosed earlier in this conversation (the `log-success` naming, the
`SIGUSR1` trap, the `fd | fdfind` dependency pairing) came from reviewing a
script in isolation without this context. Don't skip this phase.

## Phase 1: Batch the scripts

Don't batch by a flat script count. Run `fd . -t x --hidden -x wc -l` first
and look at the distribution before deciding anything. This repo's actual
spread runs from 3-line one-liners (`spotifyctl`, `pdfx`, `yt-music-playlist`) up to
300-400 line tools (`create-wiki`, `android-specs`, `document-with-llm`).
A flat "X scripts per batch" rule puts wildly uneven review effort in each
subagent's hands: one batch of tiny scripts is trivial, another batch of
large ones can be 2,000+ lines of script body on top of the ten core files.

**Rule: batch by a line budget, not a script count.**

- **Target ~600-700 lines of combined script body per batch**, the core
  files and house style brief sit on top of this and are roughly fixed cost
  per subagent regardless of batch content.
- **Cap at 12 scripts per batch even if the line budget isn't hit.** A batch
  of twelve 20-line utility scripts is still twelve separate review write-ups
  and twelve verdicts to track; capping the count keeps the aggregation step
  sane even for line-light batches.
- **Cap at 4 scripts per batch once any single script exceeds ~150 lines.**
  Scripts like `create-wiki` (401), `android-specs` (320),
  `document-with-llm` (316), `piper-say` (234), `readtime` (233), and
  `oc-manager` (245) deserve their own batch, paired with at most a
  couple of smaller companions, not buried alongside seven other scripts.

With this repo's numbers (~9,500 total lines, ~140 scripts), that produces
somewhere around 16-18 batches, but each subagent's actual workload
stays comparable across batches instead of varying by 40x.

## Grouping by similarity

Line budget decides batch _size_. Similarity decides batch _composition_.
Group scripts that share a pattern into the same batch whenever the line
budget allows it, since a subagent reviewing related scripts together builds
useful local context fast (it sees the shared pattern once, then just checks
each script against it) and produces more consistent verdicts than reviewing
the same pattern cold in five different unrelated batches.

Passes to run over the `fd` output before assigning batches:

1. **By subdirectory.** Anything already grouped by the filesystem stays
   grouped: `rofi/*`, `lua/*`, `external/*`, `cpp/*`, `c/*`, `typescript/*`.
   These often share a language, a build tool, or a release process.
2. **By name prefix/family.** Group scripts whose names signal a shared
   purpose, even across directories:
   - `log-debug`, `log-info`, `log-warning`, `log-error`, `log-success`,
     `log.sh` — the whole logging family, best reviewed together against
     `lib/loggers.sh` in one pass.
   - `get-ext`, `get-package-manager`, `get-distro`, `get-deps`, `get-desc`,
     `get-askpass`, `get-unique`, `get-ip` — the `get-*` query-and-print
     family.
   - `fd-all`, `fd-by-depth`, `fd.sh` — `fd` wrapper family.
   - `git_current_branch`, `git-root`, `git-commit`, `gitsync`,
     `gitignore-refresh`, `switch-branch`, `rmbranch`, `is-git-repo` — git workflow tools.
   - `mkscript`, `mkconf`, `mkpython`, `mk-gitignore`, `make-caddy`,
     `make-signature` — scaffolding/generator scripts.
   - `pkgfind`, `pkg-files`, `pkg-install`, `aur-install`, `clean-pacman`,
     `install-ext`, `install-ext-online`, `down-ext-file` — package
     management.
   - `kill-process`, `kill-window`, `killwait` — process control.
   - `ocrshot`, `ocrcp`, `ocr` — OCR pipeline.
   - `trim`, `trunc`, `strip-ext`, `tabs2spaces`, `remove-blanks`, `no-dups`,
     `no-orphans`, `catname`, `renamefile`, `rename-spaces`, `collapseTilde`,
     `expandTilde`, `env-qoutes` — text/filename utilities.
   - `system-stats`, `cpu-usage`, `net-speed`, `net-interface`, `now`,
     `spinner.sh`, `spin.sh`, `benchmark` — system-info/monitoring.
   - `font-search`, `load-fonts`, `fix-arabic-fonts`, `ls-colors` — font
     tooling.
3. **Large standalone tools go nearly alone.** `create-wiki`, `android-specs`,
   `document-with-llm`, `piper-say`, `oc-manager`, `readtime`, `check-deps`,
   `vercel-status`, `ts-starter` don't share a family with anything else in
   the list. Pair each with one or two small, unrelated scripts only to fill
   out the line budget, not because they're related. Note in the batch header
   that the pairing is incidental, so the subagent doesn't go looking for a
   connection that isn't there.
4. **Leftovers form general-purpose batches.** Whatever doesn't fit a family
   or a directory gets grouped last, by whatever combination fills the line
   budget. These batches are fine to be a grab-bag; just say so in the batch
   header so the subagent doesn't waste time hunting for shared intent.

When a script could fit two families (e.g., `clean-pacman` is both a
`pkg-*`-family script and arguably a maintenance script), pick whichever
grouping the surrounding batch benefits from more, and don't overthink it;
consistency of verdicts matters more than a perfect taxonomy.

## Phase 2: Dispatch each subagent

For each batch, the subagent's prompt should contain, in this order:

1. The house style brief from Phase 0.
2. The full contents of the ten core files (not just paths, unless the
   subagent has its own file-reading tool access; if it does, paths are
   sufficient and cheaper).
3. The list of script paths in this batch, with full contents.
4. The batch review template (`docs/templates/batch-review.md`).
5. A direct instruction: _"Fill in the House Style Reference section first,
   in your own words, before reviewing anything. If a pattern you're about to
   flag as a bug matches something in the house style brief, it's not a bug.
   If you're unsure whether something is intentional, put it in the 'Open
   questions' section instead of guessing either way."_

Do not let a subagent review a script it hasn't fully read. Do not let it
infer a script's dependencies or behavior from its filename.

## Phase 3: Collect and aggregate

As batch reports come back:

1. Store each batch report as its own file (`docs/code-reviews/batch-01.md`, etc.)
   rather than merging immediately. This keeps a clean audit trail back to
   the raw subagent output.
2. Build a running critical-bugs index: one line per confirmed critical bug,
   script name, one-sentence description, batch number. This is the list the
   repo owner actually needs to act on.
3. Watch for cross-batch patterns, not just cross-cutting patterns within a
   single batch. If three unrelated batches all flag the same misuse of
   `cmdarg.sh`, that's a systemic issue worth its own section in the final
   report rather than three buried mentions.
4. Treat every "Confirmed correct (potential false positives)" entry as a
   signal, not noise. If multiple subagents independently flagged the same
   pattern before ruling it correct, the house style brief probably needs a
   clearer line item, and a later batch might get it wrong if the brief
   doesn't improve.

## Phase 4: Final report structure

Produce one consolidated document with:

- **Critical bugs index** (the actionable list, grouped by script)
- **Systemic patterns** (issues appearing across 3+ scripts, described once
  with all affected scripts listed, not repeated per-script)
- **Design issues** (per-script, lower priority)
- **Style/minor** (collapsed to a short list of script names per issue type,
  not full write-ups, since these are cheap to fix and don't need
  justification)
- **Open questions for the repo owner** (aggregated from every batch, since
  these need a human decision, not another review pass)

Keep the final report's per-script detail proportional to severity: full
write-ups for critical bugs, one line for style nits. A 150-script repo
review that gives equal weight to a missing quote and a `set -u` crash isn't
useful to act on.
