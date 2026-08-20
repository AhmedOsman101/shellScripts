# Batch Review: [batch number] of [total batches]

**Scripts in this batch:** [list filenames]
**Batch composition:** [directory group / name-family / large-tool-plus-fillers / grab-bag] — state which. If the batch shares a real pattern, name it here (e.g. "the `log-*` family" or "`get-*` query scripts"). If it's a large tool paired with unrelated fillers just to fill the line budget, say so explicitly, don't hunt for a connection that isn't there.
**Reviewer:** subagent-[batch number]
**Date:** [date]

---

## House Style Reference (do not flag these as bugs)

Before reviewing, confirm you've internalized these repo conventions. Restate them here in one line each to prove the context loaded correctly:

- Dependency declaration format (`# - binary | binary2 (pkg-override)`) and how `checkDep` resolves it:
- Logging convention: `log-*` wrapper scripts are primary, camelCase `log*` functions in `lib/helpers.sh` are fallback:
- `trap 'exit 1' SIGUSR1` + `kill -SIGUSR1 "${PPID}"` propagation chain purpose:
- `cmdarg.sh` argument-parsing pattern used across scripts:
- `get-desc` / `get-deps` signature-block parsing rules:
- `init.sh` / `hooks/path.sh` symlink and PATH-registration workflow:
- Reference pattern from `clangc` (what "correct" looks like in this repo):

---

## Script Reviews

Repeat this block for every script in the batch.

### `<script-name>`

**Path:** `<full path>`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): <one line>
**Declared dependencies:** <list, or "none">
**Verdict:** `Clean` / `Minor issues` / `Needs fixes` / `Critical bug`

#### Critical bugs

Bugs that cause incorrect behavior, crashes, or silent failure. For each:

- **What happens:** short description
- **Where:**

```bash
# offending line(s), quoted exactly
```

- **Why it's wrong:**
- **Fix:**

```bash
# corrected line(s)
```

_(If none, write "None found.")_

#### Design issues

Things that work but are fragile, distro-specific, or diverge from repo conventions without a stated reason. Same format as above, lighter weight.

_(If none, write "None found.")_

#### Minor / style

Naming, quoting, redundant checks, anything cosmetic. Keep this section short; don't pad it.

_(If none, write "None found.")_

#### Confirmed correct (potential false positives)

Things that look wrong at first glance but match repo convention once cross-checked against the house style or core files. State the pattern and why it's fine. This section exists to prevent re-litigating known-good patterns in the final report.

_(If none, write "None found.")_

---

_(repeat the above block for each script in the batch)_

---

## Batch Summary

- **Scripts reviewed:** X / X
- **Critical bugs:** [script names, one line each]
- **Design issues worth escalating:** [script names]
- **Cross-cutting patterns observed in this batch** (same bug/pattern repeated across multiple scripts in this batch only; batch-level, not repo-wide):
- **Open questions** (design intent unclear, needs the repo owner's input rather than a guess):
