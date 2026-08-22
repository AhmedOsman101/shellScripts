# Batch Review: 13 of 22

**Scripts in this batch:** `external/pipes` (156), `get-ip` (38), `batwhich` (38), `n` (38) (4 scripts, 270 lines)
**Batch composition:** large+fillers — large standalone `external/pipes` (156 lines) plus 3 small fillers (`get-ip`, `batwhich`, `n` at 38 lines each) — pairing is incidental, cap 4, budget 270. No shared name-family or directory pattern; `external/pipes` is vendored third-party GPL screensaver, the other three are top-level query/wrapper scripts.
**Reviewer:** subagent-13
**Date:** 2026-08-21

---

## House Style Reference (do not flag these as bugs)

Before reviewing, confirm you've internalized these repo conventions. Restate them here in one line each to prove the context loaded correctly:

- Dependency declaration format (`# - binary | binary2 (pkg-override)`) and how `checkDep` resolves it: deps live between `# --- DEPENDENCIES --- #` / `# --- END SIGNATURE --- #` as `# - exe | alt (pkg)`; `checkDep` splits on `|`, `Trim`s, `awk '{print $1}'` per alternative and `command -v` checks each in order — any hit returns 0 satisfied, else echoes `(parens)` pkg or first exe for `installDep`.
- Logging convention: `log-*` wrapper scripts are primary, camelCase `log*` functions in `lib/helpers.sh` are fallback: standalone `log-debug`/`log-info`/`log-warning`/`log-error`/`log-success` plus dispatcher `log.sh` (`LEVEL_COLORS`/`LEVEL_OUTPUT`/`colorOnlyPrefix`) are the CLI entry points; `lib/helpers.sh` camelCase + `lib/loggers.sh` `printRed` etc. are in-process fallback, not dead code.
- `trap 'exit 1' SIGUSR1` + `kill -SIGUSR1 "${PPID}"` propagation chain purpose: every script traps SIGUSR1 to `exit 1`; only `log-error` sends `kill -SIGUSR1 "${PPID}"` + `wait` (guarded by `! isInteractiveShell && ! noKill`, `|| true` suppressed) to kill its parent without explicit exit-code checks.
- `cmdarg.sh` argument-parsing pattern used across scripts: `source "$(include "lib/cmdarg.sh")"` → `cmdarg_info "header" "$(get-desc "$0")"` → pre-declare `declare -a`/`declare -A` for `[]`/`{}` → `cmdarg "v"` boolean (`false`→`true` literal), `"m:"` required, `"o?"` optional, `"a?[]"`/`"H?{}"` array/hash → `cmdarg_parse "$@"` → read `cmdarg_cfg`/`argv`/`argc`; `-h/--help` reserved.
- `get-desc` / `get-deps` signature-block parsing rules: both `sed`-parse `# --- DESCRIPTION --- #` … `# --- DEPENDENCIES --- #` … `# --- END SIGNATURE --- #`; missing block is allowed (`get-deps` prints `x-none`, `checkDeps` returns 0, `get-desc` tolerates either terminator), `get-deps` uses `replace.sh`/`sed`.
- `init.sh` / `hooks/path.sh` symlink and PATH-registration workflow: `init.sh` verifies `SCRIPTS_DIR` (`~/scripts`), ensures `fd` (prompt symlink `fdfind→fd`), checks `hooks/path.sh`, idempotently appends `[[ -s "${SCRIPTS_DIR}/hooks/path.sh" ]] && source ...` to `~/.bashrc`/`.zshrc`; `hooks/path.sh` (sourced at startup) caches `fd --strip-cwd-prefix=always --no-ignore-vcs -t x` to `/tmp/path-hook.cache`, rescans only when dirs newer, adds each dir once via `:` guard, then unsets temps.
- Reference pattern from `clangc` (what "correct" looks like in this repo): `set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `source cmdarg` + `source compile` + `source check-deps` + `checkDeps "$0"` → `cmdarg_info`/`declare -a`/`cmdarg "c"`/`"o?"`/`"a?[]"`/`"q"` → `cmdarg_parse "$@"` → `cmdarg_cfg` reads, `((argc < 1)) && log-error` → array-safe nameref delegation.

---

## Script Reviews

### `external/pipes`

**Path:** `/home/othman/scripts/external/pipes`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): none — vendored third-party GPL header (`pipes.sh: Animated pipes terminal screensaver`, 2015 Acidhub/Pipeseroni/Lin) — no `# --- DESCRIPTION --- #` signature block (allowed per house §6, `get-desc` empty, `get-deps` → `x-none`)
**Declared dependencies:** none declared (no DEPENDENCIES block; `checkDeps` would be no-op)
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **What happens:** `getopts` error branch silently succeeds; unknown flag (e.g., `pipes -z`) exits 0 with no diagnostic, masking user typos.

- **Where:**

```bash
# external/pipes:92
  *) exit 0 ;;
```

- **Why it's wrong:** `getopts` sets `?` for unknown options, but handler `exit 0` reports success — caller/CI cannot detect misuse; convention is `exit 1` + usage to stderr. `shellcheck disable=2015` suppresses related `A && B || C` warning but not this silent-success.
- **Fix:**

```bash
  *) echo "Unknown option: -${arg}" >&2; exit 1 ;;
# or at minimum:
  *) exit 1 ;;
```

- **What happens:** no `# --- DEPENDENCIES --- #` declaration for runtime binaries `tput`/`stty`/`reset`; `tput cols/lines`, `tput smcup/rmcup/civis/cnorm/clear/cup/reset` and `stty -echo/echo` are called unguarded.

- **Where:**

```bash
# external/pipes:28,122-125,147,153
w=$(tput cols) h=$(tput lines)
stty -echo
tput smcup || FORCE_RESET=1
tput cup "${y[i]}" "${x[i]}"
```

- **Why it's wrong:** per `AGENTS.md` external tools must be declared; this is `external/` vendored demo (house §6 allows missing block for external demos — see `external/testfonts` precedent in batch-14), but surface is still fragile: on minimal containers without `ncurses-bin`, `w`/`h` become empty, arithmetic `w/2` fails. Low severity for vendored code; document as expected external exception.
- **Fix:** optional — add block if promoted from vendored:

```bash
# --- DEPENDENCIES --- #
# - tput (ncurses)
# --- END SIGNATURE --- #
```

#### Minor / style

- No `set -eo pipefail` / `trap 'exit 1' SIGUSR1` / `include` / `checkDeps` / `cmdarg` — intentional for vendored `external/` screensaver (matches `external/testfonts` precedent, not a house-style divergence to fix).
- `FORCE_RESET` used uninitialised in `((FORCE_RESET)) && reset` (`cleanup:104`); without `set -u` evaluates to 0, works but declare `FORCE_RESET=0` at top for clarity (already `BOLD=1`/`NOCOLOR=0` are initialised).
- `[[ ${NOCOLOR} == 0 ]]` and `((RNDSTART == 1 ? ...))` omit quotes — safe inside `[[ ]]`/`(( ))` (no word splitting) but inconsistent with repo's `[[ -n "${var}" ]]` quoting elsewhere.
- `sets` custom type `[[ "${OPTARG}" = c???????????????? ]]` matches exactly `c` + 16 chars (17 total); `-t cABC` shorter/longer silently falls to integer branch and is dropped — document that custom type requires exactly 16 chars.

#### Confirmed correct (potential false positives)

- `# shellcheck disable=2015` is intentional — script uses `((cond)) && action || fallback` arithmetic guards (`((p = (OPTARG > 0) ? ...))`, `((f = (OPTARG > 19 && ...)` etc.) where `A && B || C` is not a bug.
- `v=()` (lowercase) vs `V=()` (uppercase) are distinct: `V` is allowed-type list populated via `-t`, `v[i]` is per-pipe chosen index — case-sensitive, not a typo (`v[i]=${V[${#V[@]} * RANDOM / M]}` at line 119 correctly cross-references).
- `tput smcup || FORCE_RESET=1` / `tput rmcup` / `reset` fallback for terminals without `smcup/rmcup` is deliberate vt-compatibility, not dead code.
- `while REPLY=; read -rt 0.0$((1000 / f)) -n 1; [[ -z ${REPLY} ]]; do` exiting on any keypress plus `trap cleanup HUP TERM` / `trap 'break 2' INT` is the intended screensaver event loop, not an infinite-loop bug.
- No `get-desc`/`get-deps` block is allowed per house §6 (external demos may use plain header comment); `external/testfonts:1-62` precedent confirms this.

---

### `get-ip`

**Path:** `/home/othman/scripts/get-ip`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Retrieves the IP address of the active network interface
**Declared dependencies:** `ip`, `rg (ripgrep)`, `awk` (3 lines)
**Verdict:** `Needs fixes`

#### Critical bugs

- **What happens:** with `set -o pipefail`, if the interface has no `inet` line (VPN-only / `inet6`-only) or `net-interface` returns empty (offline), `rg` finds no match and exits 1, the pipeline `ip a | rg "$(net-interface)" | rg inet` exits 1, and due to `set -e` the assignment `IP="$(...)"` aborts the script before the `if [[ -n "${IP}" ]]; then` / `log-error "No IP found"` branch is reached — user gets a bare exit 1 with no diagnostic instead of the intended `log-error`.

- **Where:**

```bash
# get-ip:32
IP="$(ip a | rg "$(net-interface)" | rg inet)"

if [[ -n "${IP}" ]]; then
  echo "${IP}" | awk '{print $2;exit}'
else
  log-error "No IP found"
fi
```

- **Why it's wrong:** `set -eo pipefail` (`get-ip:22`) makes a failing `rg` (no match → exit 1) propagate as pipeline failure; inside `$(...)` with `set -e`, that failure terminates the script (no `|| true` guard). The `if [[ -n "${IP}" ]]` error path is unreachable for the most common failure mode. `net-interface` itself `exit 0` with empty on offline (see `net-interface:40`), so `rg ""` would match every line and accidentally return `lo`'s `127.0.0.1` instead — both empty and no-match cases are mishandled.
- **Fix:**

```bash
# guard rg no-match, and use fixed-string, and avoid silent rg "" case:
iface="$(net-interface)"
[[ -n "${iface}" ]] || log-error "No active network interface found"
IP="$(ip a | rg -F "${iface}" | rg -w inet || true)"
if [[ -n "${IP}" ]]; then
  echo "${IP}" | awk '{print $2;exit}'
else
  log-error "No IP found for interface '${iface}'"
fi
# or keep pipefail but append || true to the pipeline assignment:
# IP="$(ip a | rg -F "$(net-interface)" | rg -w inet || true)"
```

#### Design issues

- **What happens:** `rg` is invoked without `-F`/`-w`, so the interface name is treated as a regex and `inet` matches both `inet` and `inet6` — on systems where `inet6` appears before `inet` in `ip a` output, `awk '{print $2;exit}'` returns an IPv6 address (`fe80::.../64`) instead of the expected IPv4 `/24`.

- **Where:**

```bash
# get-ip:32
IP="$(ip a | rg "$(net-interface)" | rg inet)"
```

- **Why it's wrong:** `ip a` inet lines are `inet 192.168.1.10/24` and `inet6 fe80::.../64`; `rg inet` is a substring of `inet6`. For intended IPv4 retrieval, should be `rg -w inet` (word boundary) or `rg "inet "` with space. Also interface name should be fixed-string.
- **Fix:**

```bash
IP="$(ip a | rg -F "$(net-interface)" | rg -w inet || true)"
# or more robust without rg at all:
IP="$(ip -4 -o addr show "$(net-interface)" 2>/dev/null | awk '{print $4;exit}')"
```

- **What happens:** internal helper `net-interface` is used (`rg "$(net-interface)"`) but not declared in `DEPENDENCIES`; `checkDeps "$0"` will not ensure it is on `PATH` (relies on `hooks/path.sh` `PATH` injection).

- **Where:**

```bash
# get-ip:16-19
# - ip
# - rg (ripgrep)
# - awk
# (missing net-interface)
```

- **Why it's wrong:** repo convention (see `net-speed` review in batch-14) expects internal deps to be at least noted; while internal scripts are via `PATH` not packages, declaring `# - net-interface` documents the call-graph edge (not installed via `getPackageManager`, but checked via `command -v` existence in `checkDep` logic — at least surfaces missing helper before `ip a` scan).
- **Fix:**

```bash
# --- DEPENDENCIES --- #
# - ip
# - rg (ripgrep)
# - awk
# - net-interface
# --- END SIGNATURE --- #
```

- **What happens:** `echo "${IP}" | awk '{print $2;exit}'` captures `inet 192.168.1.10/24 brd ...` → `$2` includes CIDR suffix (`/24`); caller may expect plain IP.

- **Why it's design:** not a crash, but document whether CIDR is intended (description says "IP address" singular, ambiguous). If plain IP needed, fix: `awk '{split($2,a,"/"); print a[1]; exit}'`.

#### Minor / style

- `cmdarg_parse "$@"` with zero `cmdarg` definitions and no `((argc == 0))` positional guard is the valid no-flags pattern (see `net-interface:28-29` same shape) — but `get-ip` ignores extra positionals (`get-ip foo` treats `foo` as positional via `argv` and proceeds); adding `((argc > 0)) && log-error "Unexpected argument: ${argv[0]}"` would make the contract explicit, as done in `clangc:44` for required positionals.

#### Confirmed correct (potential false positives)

- `set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `source "$(include "lib/cmdarg.sh")"` + `source "$(include "check-deps")"` + `checkDeps "$0"` + `cmdarg_info "header" "$(get-desc "$0")"` + `cmdarg_parse "$@"` ordering exactly matches `clangc` reference (§7) — not a missing-include bug.
- `# - rg (ripgrep)` with `(ripgrep)` package-override parens is correct `checkDep` syntax per house §2 (`grep -oP '\(\K[^)]*(?=\))'` extracts `ripgrep`); pipe fallback not needed here.
- `log-error "No IP found"` correctly uses `log-error` → `kill -SIGUSR1 "${PPID}"` propagation — parent trapped `SIGUSR1` will `exit 1` without manual code checks (house §4). The bug above is that this line is unreachable under `pipefail`, not that `log-error` itself is wrong.
- `awk '{print $2;exit}'` early `exit` limits to first `inet` line per interface — intentional "active interface" semantics, not truncation.

---

### `batwhich`

**Path:** `/home/othman/scripts/batwhich`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Displays the source of a script using bat, if it exists
**Declared dependencies:** `bat | batcat (bat)` (1 line)
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **What happens:** declared dependency correctly handles Debian fallback `bat | batcat (bat)` via `checkDep` pipe, but runtime only invokes `bat`, so on Debian/Ubuntu where the binary is `batcat` (package `bat`, exe `batcat`), `checkDep` succeeds (finds `batcat`, returns 0) yet `bat --style plain "${path}"` fails with `command not found`.

- **Where:**

```bash
# batwhich:17
# - bat | batcat (bat)
# ...
# batwhich:35
  bat --style plain "${path}"
```

- **Why it's wrong:** `checkDep` pipe is fallback for *existence* check, not a runtime alias; the script must dispatch to whichever binary exists (see `mkpython`/`fd.sh` pattern). Bat's own Debian packaging renames the binary to `batcat` to avoid conflict — this repo explicitly handles it in deps but not in exec.
- **Fix:**

```bash
if path="$(command -v "${script}" 2>/dev/null)"; then
  if command -v bat &>/dev/null; then
    bat --style plain "${path}"
  else
    batcat --style plain "${path}"
  fi
else
  log-error "Script ${script} doesn't exist!"
fi
# or: bat_bin="$(command -v bat || command -v batcat)" ; "${bat_bin}" --style plain "${path}"
```

- **What happens:** only `argv[0]` is inspected; extra positionals (`batwhich foo bar`) silently ignore `bar`.

- **Where:**

```bash
# batwhich:31-34
script="${argv[0]}"
[[ -z "${script}" ]] && log-error "No valid input was given!"

if path="$(command -v "${script}" 2>/dev/null)"; then
```

- **Why it's wrong:** inconsistent with `clangc:44` `((argc < 1)) && log-error` plus implicit single-positional contract; `((argc == 0)) && log-error` + `((argc > 1)) && log-warning "Ignoring extra arguments"` would match repo's positional discipline (see `md2docx` review in batch-14 for same pattern).
- **Fix:**

```bash
((argc == 0)) && log-error "No valid input was given!"
((argc > 1)) && log-warning "Ignoring extra arguments: ${argv[*]:1}"
script="${argv[0]}"
```

#### Minor / style

- `[[ -z "${script}" ]] && log-error ...` works but `((argc == 0)) && log-error ...` directly checks the `cmdarg` contract (like `clangc`) rather than derived variable emptiness — minor.

#### Confirmed correct (potential false positives)

- `# - bat | batcat (bat)` pipe + parens is correct per house §2 — `checkDep` splits on `|`, `Trim`s, `awk '{print $1}'` per alternative (`bat`, `batcat`), and `grep -oP '\(\K[^)]*(?=\))'` extracts override `bat` for `getPackageManager` — not a syntax error.
- `set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `source cmdarg` + `source check-deps` + `checkDeps` + `cmdarg_info` + `cmdarg_parse "$@"` ordering matches `clangc` reference, even though zero `cmdarg` definitions is valid (no-flags CLI, see `net-interface`).
- `path="$(command -v "${script}" 2>/dev/null)"` correctly distinguishes `command -v` (PATH lookup) vs `[[ -f ]]` (file existence); intended to display any executable on `PATH` (including via `hooks/path.sh`), not just files in `SCRIPTS_DIR`.
- `[[ -z "${script}" ]] && log-error` correctly triggers `log-error` → `kill -SIGUSR1 "${PPID}"` chain (house §4); no explicit `exit` needed.

---

### `n`

**Path:** `/home/othman/scripts/n`
**Declared purpose** (from `# --- DESCRIPTION --- #` block): Runs a single command in nu shell
**Declared dependencies:** `nu (nushell)`, `gum` (2 lines)
**Verdict:** `Minor issues`

#### Critical bugs

None found.

#### Design issues

- **What happens:** `nu --config "${NU_CONFIG}"` is invoked with an unguarded env-var expansion; when `NU_CONFIG` is unset or empty (default for most users — not set by `init.sh`/`hooks/path.sh`), the wrapper passes `--config ""` (empty string) which `nu` treats as a config path and fails with `Error: invalid config path ''` instead of falling back to nu's default config.

- **Where:**

```bash
# n:38
nu --config "${NU_CONFIG}" -c "${command}"
```

- **Why it's wrong:** `${VAR}` with no fallback expands to empty argument; `--config` expects a valid file or omission. `NU_CONFIG` is never documented/declared in this repo (`grep NU_CONFIG` only hits this line), so empty is the common case.
- **Fix:**

```bash
if [[ -n "${NU_CONFIG:-}" ]]; then
  nu --config "${NU_CONFIG}" -c "${command}"
else
  nu -c "${command}"
fi
# or: nu ${NU_CONFIG:+--config "${NU_CONFIG}"} -c "${command}"
```

- **What happens:** `"${argv[*]}"` joins positionals with first `IFS` char (space) and loses original quoting; `n echo "a b"` (`argv=[echo, a b]`) reconstructs as `echo a b` (two args) not `echo "a b"` (one arg with space), and `n echo 'foo  bar'` collapses whitespace.

- **Where:**

```bash
# n:34-35
else
  command="${argv[*]}"
fi

nu --config "${NU_CONFIG}" -c "${command}"
```

- **Why it's wrong:** `argv[*]` string joins, `argv[@]` preserves boundaries; but `nu -c` expects a single string anyway, so joins are inherent — the issue is lack of shell-escaping when reconstructing. For `n`'s purpose (single `nu -c` invocation), this is arguably intentional passthrough, but quoting-heavy pipelines will misbehave.
- **Fix:** if preserving quoting matters:

```bash
command="${argv[*]}"
# or more faithful: keep joined but document that arguments are space-joined for nu -c parsing
```

Low severity; keep as design note unless `n` is used with complex quoted nu pipelines.

- **What happens:** local variable named `command` shadows the `command` builtin (used elsewhere as `command -v`, `command touch`); `command="$(gum ...)"` redefines it in this shell, then `nu --config ... -c "${command}"` reads it but any later `command -v` in the same process would be shadowed.

- **Why it's design:** no downstream `command` call in this script, so no runtime failure, but violates repo's naming convention (see `clangc:files`, `compile` etc. use lowercase specific names); prefer `nuCmd`/`cmdStr`.

#### Minor / style

- `cmdarg` invoked with zero definitions — valid no-flags pattern (see `get-ip`/`batwhich`), but `n` silently accepts extra `gum`-related flags as positionals; consistent with repo but could document.
- `gum write --placeholder="Enter a command..."` blocks indefinitely until user submits — intentional interactive fallback when `argc==0`, but no `SIGINT` trap beyond inherited `trap 'exit 1' SIGUSR1` (fine).
- `NU_CONFIG` not declared in `DEPENDENCIES` or documented in header — correct to not list env vars as deps, but a comment `# NU_CONFIG env var optionally points to nushell config` would clarify.

#### Confirmed correct (potential false positives)

- `set -eo pipefail` + `trap 'exit 1' SIGUSR1` + `source cmdarg` + `checkDeps` + `cmdarg_info` + `cmdarg_parse "$@"` exactly matches `clangc` reference even though `clangc` pre-declares arrays — arrays only needed for `[]`/`{}` types, and `n` defines no flags, so no `declare -a` is required.
- `# - nu (nushell)` `(nushell)` package override is correct `checkDep` syntax; `nu` binary is installed via `nushell` package on Debian/Ubuntu — `grep -oP '\(\K[^)]*(?=\))'` correctly extracts `nushell` for `installDep` (house §2).
- `if ((argc == 0)); then command="$(gum write ...)" else command="${argv[*]}"; fi` correctly branches on `cmdarg`'s `argc` (not `$#` — `cmdarg_parse "$@"` consumes flags and populates `argc`/`argv`; `argv[*]` is the intended join for `nu -c`).
- `gum write` without `--width`/`--height` is the intended `gum` TUI usage (like `load-fonts:gum spin` elsewhere) — not a missing flag.

---

## Batch Summary

- **Scripts reviewed:** 4 / 4
- **Critical bugs:** `get-ip` — `set -o pipefail` makes `rg` no-match (interface offline / `inet6`-only) exit 1 and, due to `set -e`, aborts at `IP="$(...)"` before `log-error "No IP found"` is reachable, yielding silent exit 1 with no diagnostic (fix: `... | rg -w inet || true` + `iface` empty guard).
- **Design issues worth escalating:** `external/pipes` — `*) exit 0` on unknown `getopts` flag silently succeeds; `batwhich` — `bat | batcat (bat)` declared but runtime only calls `bat`, fails on Debian where binary is `batcat`; `n` — `nu --config "${NU_CONFIG}"` passes empty `""` when `NU_CONFIG` unset (common case), causing `nu` invalid-config error; `get-ip` — `rg inet` also matches `inet6`, `rg` without `-F` treats interface regex, and missing `net-interface` in DEPENDENCIES (same internal-dep gap flagged in batch-14 for `net-speed`).
- **Cross-cutting patterns observed in this batch** (same bug/pattern repeated across multiple scripts in this batch only; batch-level, not repo-wide):
  - **Missing empty-interface/empty-result guard before piping:** `get-ip` (`IP="$(ip a | rg "$(net-interface)" | rg inet)"` with `pipefail`) and `n` (`nu --config "${NU_CONFIG}"` empty) both fail when an upstream helper/env returns empty — neither validates for empty before consuming via `rg`/`nu` flag, leading to silent `rg ""` matches-everything or `nu --config ""` invalid path.
  - **Vendored vs repo convention divergence:** `external/pipes` intentionally omits `set -eo pipefail`/`trap SIGUSR1`/`checkDeps`/`cmdarg`/`DEPENDENCIES` block (consistent with `external/testfonts` precedent in batch-14) — not a bug, but the only script in this batch that correctly bypasses the `clangc` reference pattern, while the other three follow it strictly.
  - **Pipe-as-fallback declaration vs runtime dispatch drift:** `batwhich` declares `bat | batcat (bat)` correctly for `checkDep`, but runtime does not dispatch to whichever was found (`bat` only), mirroring the `fd | fdfind` vs hardcoded `/usr/bin/fd` gap previously flagged in batch-01 `load-fonts:fd.sh` — same class: `checkDep` handles fallback, exec does not.
- **Open questions** (design intent unclear, needs the repo owner's input rather than a guess):
  - `external/pipes` — should `external/` vendored scripts remain exempt from repo house-style (no `set -e`/`trap`/`DEPENDENCIES`/`log-*`), or be wrapped/thinned to add a minimal `# --- DESCRIPTION --- #` block for `get-desc`/`create-wiki` indexing (currently `get-desc` returns empty for it)?
  - `get-ip` — should CIDR suffix (`192.168.1.10/24`) be retained in output (current `awk '{print $2;exit}'`) or stripped to plain IP (`split($2,a,"/")`) — description says "IP address" ambiguous?
  - `batwhich` — is `bat | batcat` fallback needed only for `checkDep` install prompt, or should runtime also support `batcat` on Debian (i.e., is `batcat` availability without `bat` symlink considered a supported config, or is `init.sh`'s `fdfind→fd` symlink pattern expected to be replicated for `batcat→bat`)?
  - `n` — is `NU_CONFIG` meant to be user-set env (document and keep `:-` fallback), or should it be removed and let `nu` use its default config discovery (`nu --config` omitted entirely when unset)? No other script references `NU_CONFIG`.

---

## Evidence Appendix (optional — supporting reads beyond batch files)

- House style brief: `/home/othman/scripts/docs/code-reviews/house-style-brief.md:1-69`
- Core files read: `include:1-26`, `lib/cmdarg.sh:1-462`, `lib/loggers.sh:1-341`, `lib/helpers.sh:1-420`, `check-deps:1-175`, `log.sh:1-66`, `get-desc:1-53`, `get-deps:1-39`, `init.sh:1-158`, `hooks/path.sh:1-86`, `clangc:1-67`
- Batch scripts read: `external/pipes:1-156`, `get-ip:1-38`, `batwhich:1-38`, `n:1-38`
- Supporting reads: `net-interface:1-42`, `docs/code-reviews/batch-01.md:1-385` (load-fonts `fd.sh` precedent), `docs/code-reviews/batch-14.md:1-685` (external/testfonts, net-speed, net-interface precedents for pipefail/empty-interface and vendored exemptions), `docs/templates/batch-review.md:1-85`
- Verification: `grep NU_CONFIG` only hits `n:38`; `command -v bat` fallback pattern cross-checked against `checkDep` pipe logic in `check-deps:28-52`; `rg inet` vs `inet6` substring reproduced via `ip a` sample inspection
