# Code Review: create-wiki

**Date:** 2026-11-10  
**Reviewer:** SeniorReviewer  
**Scope:** `create-wiki` (current working tree, HEAD context main@830ce53) plus connected reads: `lib/helpers.sh`, `document-with-llm`, `check-deps`, `mkscript`, `shellfmt`, `mdfmt`, `include`, `get-desc`, `get-deps` (presence in PATH).  
**Commits:** working tree review (no diff range supplied); recent history inspected: `830ce53 feat(wiki): add omp provider and trace debugging mode`, `ad10cac`, `669e0cb`, `a19afe2`, `6feabff`.  
**Spec:** none provided; no issue/plan/spec file discovered for this review. Reasonable-user expectations used where spec is silent (a wiki generator should not leave stale pages after source removal/rename).  
**Standards:** `/home/othman/scripts/AGENTS.md`, `/home/othman/scripts/.shellcheckrc` (enabled: SC2001, SC2002, SC2016, SC2034, SC2086, SC2153, SC2181, SC2207, SC2230, SC2296; severity=style).

## Consent

| Command / action | Status | Notes |
| --- | --- | --- |
| Read/grep/git inspection of repo files | approved (free), run | `create-wiki`, `lib/helpers.sh`, `document-with-llm`, `mkscript`, git history/status |
| `./shellfmt -i -f create-wiki` | approved, run | No changes produced |
| `shellcheck create-wiki` | approved, run | Exit 0, no findings |
| `EDITOR=cat ./mkscript test.sh` | approved (as part of user-specified test), run | Created dummy script in repo root for verification; removed after test |
| `./create-wiki --force -j 2` (first run) | approved (user specified `--force --trace -j 2`; `--trace` omitted to avoid interactive `gum confirm` under parallel TTY), run | Generated wiki including `wiki/bash/test.sh.md` |
| `mv test.sh test-renamed.sh` + `./create-wiki -j 2` | approved (user-specified rename test), run | Verified orphan behavior |
| `rm test-renamed.sh` + `./create-wiki -j 2` | approved (user-specified delete test), run | Verified orphan behavior persists |
| Cleanup of test artifacts (`wiki/bash/test*.md`, cache hashes for `test.sh`/`test-renamed.sh`) | approved as part of test, run | Cleanup completed; `wiki/` is gitignored (separate repo per user) |
| `bun check` / `deno check` / `deno lint` | not needed, not run | No TS project affected |
| Full-repo `create-wiki --all` / LLM documentation | not approved, not run | Would invoke external LLM provider |

## Summary

`create-wiki` generates and incrementally updates wiki pages but never reconciles removals: deleted or renamed source scripts leave orphan `.md` pages and orphan hash-cache entries. This was reproduced end-to-end in `/home/othman/scripts` with a dummy script (`test.sh` → `test-renamed.sh` → deleted). Additional gaps: `Home.md` is only partially populated/refreshed, `REPO_URL` discovery has no fallback under `set -e`, and help generation executes repo scripts. `shellcheck` passes clean after `shellfmt` reported no changes.

## Findings

### Important

#### F1 · [correctness] · Confirmed

**Where:** `create-wiki:L166-259` `generateScriptPage`, `create-wiki:L262-306` `generateLibPage`, `create-wiki:L360` (generation pipeline), `create-wiki:L362-403` (Home/index generation)

**What:** `create-wiki` never deletes wiki pages or hash-cache entries for source scripts that were removed or renamed; stale pages persist across subsequent runs.

**Context:** Traced generation flow: `main` (`L313-353`) dispatches existing files to `generateScriptPage`/`generateLibPage`; both write `${outputFile}` with `> "${outputFile}"` (`L254`, `L301`) and record `${hashCache}` (`L257`, `L304`) but contain no removal logic. `shouldSkipIfUnchanged` (`L80-101`) only decides whether to regenerate an existing target. No `rm`, `find -delete`, or reconciliation pass exists anywhere in the script (read whole file, `L1-414`). Cache keys are basename-based: `${WIKI_CACHE_DIR}/${scriptName}.hash` (`L185`) and `${WIKI_CACHE_DIR}/lib-${libName}.hash` (`L269`), so a rename creates a new key while the old key remains. `IGNORED_SCRIPTS` (`L57-62`, enforced at `L339-344`) suppresses generation but does not remove any pre-existing page for an ignored script.

**Impact:** After `git mv`/rename or deletion of a script, the old `wiki/.../<name>.md` remains in the wiki tree indefinitely and can be read/linked as current documentation. Renames produce duplicate pages (old + new). This is the user-reported symptom.

**Evidence:**
```bash
$ cd /home/othman/scripts
$ EDITOR=cat ./mkscript test.sh
[SUCCESS] Script 'test.sh' created and its name was copied to your clipboard.
#!/usr/bin/env bash
... (cmdarg-based template written to test.sh)

$ ./create-wiki --force -j 2 2>&1 | tail -n 12
...
wiki/bash/test.sh.md
...
Formatted 149 files, 12 unchanged [11.52ms]
[SUCCESS] Wiki generation complete!

$ ls -la wiki/bash/test.sh.md
-rw-r--r-- 1 othman othman 276 Nov 10 22:18 wiki/bash/test.sh.md

$ mv test.sh test-renamed.sh
$ ./create-wiki -j 2 2>&1 | tail -n 8
[SUCCESS] Created: bash/test-renamed.sh.md
...
wiki/bash/test-renamed.sh.md
Formatted 1 file, 161 unchanged [3.49ms]
[SUCCESS] Wiki generation complete!

$ ls -la wiki/bash/test.sh.md wiki/bash/test-renamed.sh.md
-rw-r--r-- 1 othman othman 300 Nov 10 22:18 wiki/bash/test-renamed.sh.md
-rw-r--r-- 1 othman othman 276 Nov 10 22:18 wiki/bash/test.sh.md

$ ls -la "$HOME/.cache/create-wiki/wiki/test.sh.hash" "$HOME/.cache/create-wiki/wiki/test-renamed.sh.hash"
-rw-r--r-- 1 othman othman 22 Nov 10 22:18 .../test-renamed.sh.hash
-rw-r--r-- 1 othman othman 22 Nov 10 22:18 .../test.sh.hash

$ rm test-renamed.sh
$ ./create-wiki -j 2 2>&1 | tail -n 4
Formatted 0 files, 162 unchanged [3.59ms]
[SUCCESS] Wiki generation complete!

$ ls -la wiki/bash/test.sh.md wiki/bash/test-renamed.sh.md
-rw-r--r-- 1 othman othman 300 Nov 10 22:18 wiki/bash/test-renamed.sh.md
-rw-r--r-- 1 othman othman 276 Nov 10 22:18 wiki/bash/test.sh.md
```

**Fix:** Add a post-generation reconciliation step (serial, after `parallel` at `L360` and before/with `Home.md` regeneration) that builds the expected page set for sources actually processed (root bash scripts, `lib/*.sh`, `rofi/*`, `external/*`, and any other directories `main` maps), then removes `.md` files in corresponding `WIKI_DIR` subtrees that are no longer expected (and prunes now-orphan hash-cache entries keyed by removed names). Explicitly decide behavior for `IGNORED_SCRIPTS` and for non-bash pages generated by `document-with-llm` under `--all` so reconciliation does not delete pages outside `create-wiki`'s ownership. Document whether reconciliation runs on every invocation or only with `--force`/a dedicated flag, because `wiki/` may be a separate repo with hand-edited content.

#### F2 · [correctness] · Confirmed

**Where:** `create-wiki:L362-403` (Home generation), `create-wiki:L360` (input set), `create-wiki:L166-181` (relDir mapping)

**What:** `Home.md` only indexes root-level bash scripts and `lib/*.sh`, omits other script locations that `create-wiki` generates pages for, and is not refreshed on non-force runs.

**Context:** `Home.md` is written only when missing or `FORCE` (`L364`). The "Libraries" table iterates `${SCRIPTS_DIR}/lib/*.sh` (`L380-385`) and links to `bash/lib/${libName}.md` (consistent with `generateLibPage`). The "Scripts" table iterates only `${SCRIPTS_DIR}/*` and filters to bash shebangs (`L392-399`), linking to `bash/${scriptName}.md`. However `main` is fed `SCRIPTS_DIR/*`, `SCRIPTS_DIR/lib/*.sh`, `SCRIPTS_DIR/rofi/*`, and `SCRIPTS_DIR/external/*` (`L360`), and `generateScriptPage` maps `rofi` and `external` to `bash/rofi/` and `bash/external/` (`L175-181`). Non-bash dirs (`c/`, `cpp/`, `lua/`, `python/`, `typescript/`) are out of scope for bash generation but relevant to `--all` via `document-with-llm` (`L406-408`). I traced these code paths statically; I did not capture `Home.md` contents during the rename/delete test run (that run was without `--force`, so `Home.md` would not have been rewritten per `L364`).

**Impact:** Pages generated for `bash/rofi/*` and `bash/external/*` are not discoverable from `Home.md`. After renames/deletions on a non-force run, `Home.md` retains stale links/names because it is not regenerated. A wiki consumer relying on `Home.md` will miss existing pages and follow dead links.

**Evidence:**
```bash
# create-wiki:L360 — generation input includes rofi/external
printf '%s\0' "${SCRIPTS_DIR}"/* "${SCRIPTS_DIR}/lib"/*.sh "${SCRIPTS_DIR}/rofi"/* "${SCRIPTS_DIR}/external"/* | parallel ...

# create-wiki:L175-181 — mapping
case "${relDir}" in
  "") relDir="bash" ;;
  lib | rofi | external) relDir="bash/${relDir}" ;;
  *) : ;;
esac

# create-wiki:L364,392-399 — Home only refreshed on missing/force and only lists root scripts
if [[ ! -f "${homeFile}" ]] || "${FORCE}"; then
  ...
  for file in "${SCRIPTS_DIR}"/*; do
    ... bash shebang filter ...
    echo "| [${scriptName}](bash/${scriptName}.md) | ${desc:-No description} |"
  done
fi
```

**Fix:** Regenerate `Home.md` on every run (or track a hash) and include sections/links for `bash/rofi/`, `bash/external/`, and—when `--all` is used—language subdirs produced by `document-with-llm`. At minimum, ensure Home reflects the same source set that was just generated and does not retain links to removed scripts.

#### F3 · [correctness] · Confirmed

**Where:** `create-wiki:L65-66`, `create-wiki:L21`

**What:** `REPO_URL` is derived from `git remote get-url origin` with no fallback or override; failure aborts the script before wiki generation.

**Context:** The script enables `set -eo pipefail` (`L21`). At `L65` it runs `remote="$(git -C "${SCRIPTS_DIR}" remote get-url origin | sed 's|\.git$||')"`, then normalizes SSH form at `L66`. If `${SCRIPTS_DIR}` is not a git repo, has no `origin`, or `git` fails, the command substitution/pipe returns non-zero and the script exits under `-e`/`pipefail` before `initCache`/generation (`L309+`). No `cmdarg` option provides an explicit repo URL and no fallback to relative links exists. `REPO_URL` is interpolated into every generated page's Source link (`L251`, `L299`).

**Impact:** In environments without a configured `origin` remote (fresh clone variant, detached work copy, mirror, or certain CI contexts), `create-wiki` fails entirely instead of generating pages or warning. This is a hard dependency not declared in the script signature/dependencies block (`L14-19`).

**Evidence:**
```bash
# create-wiki:L21,65-66
set -eo pipefail
...
remote="$(git -C "${SCRIPTS_DIR}" remote get-url origin | sed 's|\.git$||')"
REPO_URL="${remote/git@github.com:/https://github.com/}"
```

**Fix:** Add a `--repo-url`/`-r` option (and/or derive from existing `origin` only when present), and fall back to a relative source path or omit the Source link with a warning when no URL is available. Guard the `git remote` call so failure does not abort under `set -e` unless the URL is strictly required.

### Minor

#### F4 · [smell] · Confirmed

**Where:** `create-wiki:L112-134` `getHelpOutput`, `create-wiki:L360` (parallel invocation)

**What:** Wiki generation executes `--help` for every `cmdarg`-using script (`timeout 2 "${file}" --help`), which is a side-effect surface and a performance cost despite caching.

**Context:** `usesCmdarg` (`L108-110`) gates execution on matching `cmdarg_parse|cmdarg "`. On cache miss, `getHelpOutput` runs the target script as an executable with `--help` and captures stdout/stderr (`L131`), caching by content hash of the script file (`L122-127`). `main`/generation runs under `parallel -j "${JOBS}"` (`L360`, `JOBS` defaults to `nproc` at `L40,53`). I confirmed `getHelpOutput` is called from `generateScriptPage` (`L193`) and that help cache is keyed by script content hash; I did not audit every script's `--help` behavior for side effects.

**Impact:** A script whose help path performs I/O, network access, or state mutation (outside cmdarg's typical behavior) would execute it during documentation generation. Concurrent execution at `nproc` can amplify load. Cache mitigates repeated runs but not first-run side effects.

**Evidence:**
```bash
# create-wiki:L122-133
local fileHash="$(hasher "${file}" | awk '{ print $1 }')"
local cacheFile="${HELP_CACHE_DIR}/${fileHash}"
if [[ -s "${cacheFile}" ]]; then
  cat "${cacheFile}"
  return
fi
...
output="$(timeout 2 "${file}" --help 2>&1 || true)"
```

**Fix:** Prefer static extraction from `cmdarg` declarations/signature for usage where possible, or restrict `--help` execution to an explicit opt-in/allowlist. If execution remains, document the assumption that `--help` is side-effect-free for cmdarg scripts.

#### F5 · [correctness] · Confirmed

**Where:** `create-wiki:L406-408`, `document-with-llm:L1-220` (connected, partially read)

**What:** `--all` delegates non-bash documentation to `document-with-llm`, but `create-wiki` does not reconcile or coordinate stale-page removal for pages that delegation may create/own.

**Context:** When `ALL` is set, `create-wiki` runs `document-with-llm -d "${WIKI_DIR}" -p "${PROVIDER}" ...` after bash generation and before `mdfmt` (`L406-410`). `document-with-llm` writes to language subdirs under `${WIKI_DIR}` (observed from its header/help text and structure: `getWikiDir`/`output_file="${WIKI_DIR}/${wiki_dir}/${project_name}.md"` in its implementation). No shared manifest or deletion protocol between the two scripts is visible in `create-wiki`. Because `wiki/` may be a separate repo (user-stated), ownership boundaries matter.

**Impact:** Any stale-page fix in `create-wiki` risks either (a) leaving non-bash stale pages undeleted, or (b) deleting LLM-generated pages if reconciliation is over-broad. Correctness of "no stale wiki files" for `--all` workflows is currently unspecified.

**Evidence:**
```bash
# create-wiki:L406-410
if "${ALL}"; then
  document-with-llm -d "${WIKI_DIR}" -p "${PROVIDER}" ${MODEL:+-m "${MODEL}"} ${FORCE:+-f} ${VERBOSE:+-v}
fi

mdfmt "${WIKI_DIR}"
```

**Fix:** Define ownership per subdirectory (e.g. `bash/`, `bash/lib/`, `bash/rofi/`, `bash/external/` owned by `create-wiki`; language dirs owned by `document-with-llm` when `--all` runs) and have each reconciler operate only within its owned set, or emit a manifest consumed by a single final reconciliation pass.

#### F6 · [smell] · Unverified

**Where:** `create-wiki:L314`, `create-wiki:L324`, `create-wiki:L360`

**What:** `TRACE` mode uses `gum confirm` inside parallel jobs and `set -x` in job context, which is likely unusable/fragile under concurrent execution.

**Context:** `main` runs `${TRACE} && set -x` (`L314`) and `${TRACE} && gum confirm "Proceed with ${file}?"` per file (`L324`) while parallel is invoked as `parallel -0 -j "${JOBS}" -k -m --tty main` (`L360`). Multiple jobs prompting on a shared TTY (`-j` may be >1) can interleave or contend for input. I did not run with `--trace` (user requested it but also constrained non-interactive verification; `gum` prompts would block/hang in this environment).

**Impact:** `--trace` debugging mode may hang or produce confusing interleaved output/prompts when used with parallelism >1, reducing its diagnostic value.

**Evidence:** *(static)*
```bash
# create-wiki:L314,324,360
${TRACE} && set -x
...
${TRACE} && gum confirm "Proceed with ${file}?"
...
printf '%s\0' ... | parallel -0 -j "${JOBS}" -k -m --tty main
```

**Fix:** When `TRACE` is enabled, force `-j 1` (or require it), or replace per-file interactive confirmation with non-interactive trace logging.

**Unverified reason:** Not executed with `--trace`; behavior inferred from parallel+TTY+interactive prompt interaction. Would be confirmed by running `./create-wiki --trace -j 2` in an interactive terminal and observing prompt contention/ordering.

### Question

#### Q1 · [correctness] · Unverified

**Where:** `create-wiki:L364-403`, interaction with F1

**What:** During the rename/delete verification (runs without `--force` after the initial forced generation), did `Home.md` retain a link to `test.sh` and omit `test-renamed.sh`?

**Context:** `Home.md` is only regenerated when missing or `${FORCE}` is true (`L364`). The rename/delete experiment was performed as: `--force` run (generated `test.sh.md`), rename + non-force run (generated `test-renamed.sh.md`), delete + non-force run. I captured page existence and cache state but did not capture `Home.md` contents before cleanup.

**Impact:** If yes, F2 is also runtime-confirmed in the stale-link aspect; if no (e.g. other logic rewrote Home), F2's refresh claim needs narrowing.

**Evidence:** Not captured. Code path: `create-wiki:L364` gates Home regeneration on `! -f || FORCE`.

**What would unblock:** Re-run the same rename/delete sequence and `grep -n "test.sh\|test-renamed" wiki/Home.md` after each step, or inspect current `wiki/Home.md` in a state where a rename was performed without `--force`.

## Declined to judge

- `document-with-llm` internals and its own stale-page/cache behavior — invoked only under `--all` (not exercised); out of scope except for interface/ownership implications noted in F5.
- `mdfmt` formatting semantics and idempotence — external formatter; observed to run successfully during tests (`Formatted ... files`), but correctness of its rewrites not reviewed.
- `get-desc`, `get-deps`, `hasher`, `cmdarg`, `log-*` helper correctness — treated as trusted dependencies except where their contracts are directly relevant (`hasher` content-hash behavior; basename-keyed cache choice is in `create-wiki`).
- LLM prompt/template quality under `templates/document-with-llm/prompt.md` — not part of `create-wiki`.
- Performance/concurrency tuning of `parallel -j "$(nproc)"` across the full repo — no benchmark requested.
- Product decision on whether `IGNORED_SCRIPTS` should retroactively delete existing wiki pages — flagged in F1 fix notes; requires author/maintainer intent.

## Unverified

| Id | Claim | Why unconfirmed | What would confirm it |
| --- | --- | --- | --- |
| F6 | `--trace` with `gum confirm` under `parallel -j >1 --tty` is fragile/hangs | Not executed; interactive TTY contention not exercised in this run | Run `./create-wiki --trace -j 2` interactively and observe prompt behavior/ordering |
| Q1 | `Home.md` retained stale `test.sh` link and missed `test-renamed.sh` during non-force rename/delete steps | `Home.md` content not captured during experiment before cleanup | Repeat test and inspect `wiki/Home.md` after each step |

## Tooling / standards checks

```bash
$ ./shellfmt -i -f create-wiki
EXIT=0
$ git diff --stat -- create-wiki
(no output)

$ shellcheck create-wiki
EXIT=0
```

`create-wiki` conforms to repo `shellfmt` formatting as-is and passes `shellcheck` with the repo's `.shellcheckrc` (severity=style, enabled SC2001/SC2002/SC2016/SC2034/SC2086/SC2153/SC2181/SC2207/SC2230/SC2296). No shellcheck findings required changes.

## Roll-up

| Axis | Critical | Important | Minor | Question |
| --- | --- | --- | --- | --- |
| correctness | 0 | 3 (F1, F2, F3) | 1 (F5) | 1 (Q1) |
| spec | 0 | 0 | 0 | 0 |
| smell | 0 | 0 | 2 (F4, F6) | 0 |

**Coverage:** Full static read of `create-wiki` (414 lines) and targeted reads of connected scripts (`lib/helpers.sh` hasher/logging/validation helpers, `document-with-llm` interface/flow, `check-deps`, `mkscript`). Executed formatting/lint and an end-to-end create→rename→delete verification using a dummy cmdarg-based script (`EDITOR=cat ./mkscript test.sh`) with `./create-wiki --force -j 2` then `./create-wiki -j 2`. `--all`/LLM path and `--trace` interactive path were not executed. `wiki/` is a separate gitignored repo (per user); temporary test pages/hashes created during verification were cleaned up. No diff/range was provided; review treated the current script as the scope.
