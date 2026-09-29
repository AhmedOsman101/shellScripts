# Lua Port Ranking — ~/scripts

Ranked by ease of porting from bash to Lua, grounded in static analysis only:
per-script construct density (sed/awk/jq/network/background/trap usage), signature
DESCRIPTION/DEPENDENCIES blocks, and the generated wiki. No script was executed.

Scope: all 150 `#!/usr/bin/env bash` scripts (repo root, `lib/`, `hooks/`,
`templates/`, `rofi/rofi-*`). Subdirectories `bin/`, `wiki/`, `external/`, `python/`,
`typescript/`, `c/`, `cpp/` are not bash scripts and are out of scope.

---

## 1. Foundations to build first

The single biggest determinant of port cost is not the scripts — it is the runtime
gap between bash and Lua. Three shared pieces pay for themselves across the whole
repo and must exist before any porting:

| Piece                                           | Replaces                                                          | Notes                                                                                                                                                                                                                                                                           |
| ----------------------------------------------- | ----------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `sh.lua`                                        | ad-hoc `os.execute` / `io.popen` everywhere                       | `os.execute` returns only an exit code; `io.popen` returns only stdout, no stderr, no exit code. One wrapper `run(cmd, {input=...}) -> stdout, stderr, code` is required and used by nearly every script.                                                                       |
| `helpers.lua` (from `lib/helpers.sh`)           | 10 scripts source it directly                                     | 40 functions, mostly trivial: `shellJoinQuote`, `isPositiveInt`/`isFloat`/`isNegative*`, `yesNo`, `isInteractiveShell`, `eraseLine`, `mapColor`, `randStr`/`randWords`/`randRange`, `humanQuote`. `hasher` (xxh3sum/b2sum) can keep shelling out. Direct translation, low risk. |
| `cmdarg.lua` (from `lib/cmdarg.sh`)             | 6 scripts source it directly; the whole repo's flag parsing idiom | 462 lines, the largest library. Ports cleanly to a proper Lua module (`cmdarg.parse(arg)` filling a config table + `argv` array). Doing this early converts every script's `cmdarg_info/cmdarg/argv` scaffolding into boilerplate-free Lua.                                     |
| `loggers.lua` (from `lib/loggers.sh`)           | 1 direct source + `log-*` wrapper scripts                         | 374 lines, 46 `$(...)` expansions but they are all escape-table driven color printing. Pure output, no state. Easy.                                                                                                                                                             |
| `vscode.lua` (from `lib/vscode.sh`)             | jq calls                                                          | 43 lines; replace jq with `lua-cjson`/`dkjson`.                                                                                                                                                                                                                                 |
| `compile.lua` (from `lib/compile.sh`)           | `local -n` namerefs, cache-key generation                         | Namerefs do not exist in Lua; restructure as a table return. Moderate.                                                                                                                                                                                                          |
| `diff-handler.lua` (from `lib/diff-handler.sh`) | variable indirection + process substitution                       | 164 lines, 5 functions. Moderate.                                                                                                                                                                                                                                               |

Existing precedent: `lua/sec2time.lua` and `lua/timewarp.lua` already use plain Lua
with `os.execute("log-error ...")` for error paths — the port should follow this
style, with `sh.lua` making it systematic.

Third-party Lua modules to adopt (small, boring, standard):

- `lua-cjson` or `dkjson` — replaces every `jq` invocation (bun-ls, pnpm-ls,
  get-ext, down-ext-file, install-ext-online, vercel-status, lib/vscode.sh).
- LPeg — only where Lua patterns are insufficient (Lua patterns lack alternation
  and groups); otherwise keep `sed`/`rg` as subprocesses rather than rewriting
  regexes.
- Keep HTTP as subprocess (`curl`/`wget` via `sh.lua`) rather than pulling in
  luasocket — the scripts' failure handling is already written around CLI tools.

Not portable: `include` (the `source "$(include ...)"` machinery) disappears —
Lua's `require` + `package.path` replaces it entirely.

---

## 2. Tier 0 — Trivial (mechanical port, no logic risk)

Near-zero external logic; wrappers around one tool, pure print, or pure string
manipulation. All port with `sh.lua` + `loggers.lua` alone.

| Script                                                                | Lines   | Why trivial                                              |
| --------------------------------------------------------------------- | ------- | -------------------------------------------------------- |
| echopass                                                              | 3       | one `echo` wrapper                                       |
| pdfx                                                                  | 3       | dispatcher to runpy                                      |
| spotifyctl                                                            | 3       | dispatcher to runpy                                      |
| yt-music-playlist                                                     | 3       | dispatcher to runpy                                      |
| updateSpicetify                                                       | 5       | 4 sequential spicetify calls                             |
| askpass                                                               | 6       | one zenity call                                          |
| cpp/release.sh                                                        | 7       | fixed call sequence                                      |
| c/release.sh                                                          | 7       | fixed call sequence                                      |
| typescript/release.sh                                                 | 9       | one deno loop                                            |
| customvscode                                                          | 21      | picks binary, runs with sudo                             |
| fd-all                                                                | 22      | one fd invocation                                        |
| print-args                                                            | 29      | prints argv                                              |
| now                                                                   | 30      | prints `date`                                            |
| selcp                                                                 | 30      | xsel one-liner                                           |
| copycat                                                               | 34      | file -> clipcopy                                         |
| collapseTilde                                                         | 32      | pure string edit (Lua `gsub`)                            |
| expandTilde                                                           | 32      | pure string edit                                         |
| yes.sh                                                                | 35      | loop + print (demo script; `sleep` loop)                 |
| gitignore-refresh                                                     | 36      | 5 fixed git calls                                        |
| catname                                                               | 37      | loop over bat calls                                      |
| fix-arabic-fonts                                                      | 26      | two sudo cp/rm calls                                     |
| log-debug / log-info / log-success / log-warning / log-error / log.sh | 33–67   | pure colored print; becomes 6 aliases over `loggers.lua` |
| banner                                                                | 50      | pure printf framing                                      |
| killwait                                                              | 39      | kill + poll loop                                         |
| git-root                                                              | 32      | `git rev-parse` wrapper                                  |
| git_current_branch                                                    | 32      | `git branch --show-current` wrapper                      |
| get-distro                                                            | 31      | parse `/etc/os-release`                                  |
| strip-ext                                                             | 44      | pure string (Lua `gsub`)                                 |
| mvp                                                                   | 51      | mkdir -p + mv                                            |
| rustbook                                                              | 32      | launch vite with config                                  |
| get-deps / get-desc                                                   | 39 / 53 | parse own signature block; trivial with Lua string ops   |

## 3. Tier 1 — Easy (real logic, but only process/string work)

Loops, arrays, argument handling, 1–3 external tools, no data-format parsing,
no concurrency. Port is a direct translation with `helpers.lua` + `cmdarg.lua`.

| Script              | Lines | Tools                     | Notes                                                       |
| ------------------- | ----- | ------------------------- | ----------------------------------------------------------- |
| batwhich            | 38    | bat                       |                                                             |
| editwhich           | 41    | $EDITOR                   |                                                             |
| rmwhich             | 44    | rm                        |                                                             |
| hasTTY              | 67    | —                         | tty detection via `io.popen("tty")`                         |
| is-git-repo         | 47    | git                       |                                                             |
| basedir             | 78    | —                         | pure string split; longest pure-logic script, still trivial |
| joinarr             | 51    | —                         | `table.concat`                                              |
| trunc               | 48    | —                         | pure string                                                 |
| toggleKB            | 40    | setxkbmap, notify-send    |                                                             |
| clipcopy            | 45    | xclip/wl-copy/copyq       | tool-fallback chain                                         |
| insert-selection    | 50    | xsel, xdotool             |                                                             |
| kill-window         | 47    | wmctrl, xdotool, xkill    |                                                             |
| kill-process        | 73    | gum                       | interactive confirm only                                    |
| tmux-exec           | 78    | tmux, pgrep               | loop over panes; no concurrency                             |
| rename-spaces       | 34    | fd                        |                                                             |
| renamefile          | 75    | —                         |                                                             |
| tempedit            | 54    | $EDITOR, clipcopy         |                                                             |
| image-text          | 59    | magick                    |                                                             |
| blank-image         | 47    | magick                    |                                                             |
| ocr                 | 58    | tesseract                 |                                                             |
| ocrcp               | 41    | tesseract + clipboard     |                                                             |
| ocrshot             | 37    | tesseract, flameshot      |                                                             |
| pkg-files           | 49    | pacman                    |                                                             |
| pkgfind             | 63    | rg, pacman/paru/yay       |                                                             |
| no-orphans          | 64    | paru                      |                                                             |
| clean-pacman        | 48    | pacman, paru              | size math -> Lua                                            |
| net-interface       | 42    | ip                        | parse `ip route`                                            |
| get-ip              | 38    | ip, rg                    |                                                             |
| font-search         | 32    | fc-list, rg               |                                                             |
| env-qoutes          | 39    | awk                       | -> plain Lua line loop                                      |
| which-cpp           | 48    | clang++/g++               |                                                             |
| fd.sh               | 49    | fd                        |                                                             |
| fd-by-depth         | 31    | fd, awk                   | sort by depth -> Lua sort                                   |
| tuckr-sync          | 49    | tuckr, fd                 |                                                             |
| runpy               | 49    | uv, fd                    | venv path logic                                             |
| loop                | 65    | gum                       |                                                             |
| repeat-it           | 94    | gum                       | retry loop; `spin` integration optional                     |
| get-package-manager | 140   | os-release, pacman family | 140 lines of pure case/if logic; no exotic constructs       |
| ls-colors           | 50    | rg                        | parse zsh color vars                                        |
| load-fonts          | 59    | fd, fc-cache              |                                                             |
| make-caddy          | 70    | mkcert, caddy, systemctl  |                                                             |
| phpfmt              | 54    | phpcbf                    |                                                             |
| md2docx             | 47    | pandoc                    |                                                             |
| mdfmt               | 66    | prettier, fd, awk         |                                                             |
| mdclean             | 82    | sponge, perl, parallel    | drops to Tier 2 if you want the perl/sponge bits native     |
| mdmath              | 89    | grep, parallel            | delimiter swap -> Lua gsub                                  |

## 4. Tier 2 — Moderate (parsing, JSON, or heavy text munging)

Needs a deliberate mapping decision: Lua patterns/LPeg for sed, Lua tables for
awk pipelines, lua-cjson for jq. Arrays + command substitution everywhere, but
no background-process or terminal-control complexity.

| Script             | Lines | Obstacle                                                                                    |
| ------------------ | ----- | ------------------------------------------------------------------------------------------- |
| bun-ls             | 51    | jq (3) + bun; JSON walk                                                                     |
| pnpm-ls            | 43    | jq (2) + pnpm                                                                               |
| get-ext            | 64    | jq (2) + code CLI                                                                           |
| down-ext-file      | 66    | wget + jq; download loop                                                                    |
| install-ext        | 48    | code CLI                                                                                    |
| install-ext-online | 125   | wget/jq/sqlite3/gum; largest JSON consumer                                                  |
| update-biome       | 48    | wget download + install                                                                     |
| trim               | 57    | 6 sed programs -> Lua patterns                                                              |
| tabs2spaces        | 45    | 2 sed programs                                                                              |
| remove-blanks      | 56    | awk (4)                                                                                     |
| replace.sh         | 81    | 5 sed programs; backup logic                                                                |
| viewlines          | 67    | awk (5) line ranges -> trivial Lua readline                                                 |
| no-dups            | 82    | awk (3), backup + array output modes                                                        |
| get-unique         | 100   | awk (3)                                                                                     |
| cpu-usage          | 58    | 4 bc -> Lua math; /proc parsing                                                             |
| net-speed          | 54    | awk delta math                                                                              |
| system-stats       | 37    | 4 awk pipelines (top/free/df)                                                               |
| benchmark          | 127   | awk statistics + bc; integer/float stats -> Lua math                                        |
| readtime           | 233   | 31 cmdsub but all pure word-count logic + pandoc/pdftotext; large but linear                |
| prepare-tts-text   | 70    | 3 sed + pandoc                                                                              |
| vercel-status      | 118   | curl + 14 jq -> lua-cjson; biggest JSON rewrite but linear                                  |
| rmbranch           | 91    | git + gum + indirection flag                                                                |
| gitsync            | 91    | 9 git calls                                                                                 |
| switch-branch      | 167   | git + gum + rg; branch list UI                                                              |
| git-commit         | 191   | 12 git calls + commit-sage + AI path; 16 cmdsub; largest git flow                           |
| unsetenv           | 42    | fzf + awk + clipboard                                                                       |
| pkg-install        | 54    | fzf + pacman                                                                                |
| aur-install        | 54    | fzf + paru + plocate                                                                        |
| dotfiles.sh        | 82    | fzf + eza/fd preview chain                                                                  |
| fzf-preview        | 80    | 5 preview tools; big dispatch table only                                                    |
| biome-check        | 74    | biome + fd/git                                                                              |
| biome-watch        | 39    | delegates to watch.sh                                                                       |
| watch.sh           | 64    | watchexec + arg joining                                                                     |
| daily.sh           | 56    | timeshift, pacman, pnpm; 1 bg job                                                           |
| check-deps         | 118   | orchestration of get-deps/get-askpass/get-package-manager; 12 cmdsub but no exotic features |
| shellfmt           | 85    | shfmt/shellcheck/patch pipeline                                                             |
| mk-gitignore       | 65    | curl + fzf                                                                                  |
| mkconf             | 68    | gum + tuckr                                                                                 |
| mkpython           | 74    | uv + fd                                                                                     |
| mkscript           | 126   | gum + template emission; 16 cmdsub, all linear                                              |
| make-signature     | 70    | toilet + sed                                                                                |
| include            | 26    | superseded by `require`; port only as documentation                                         |

## 5. Tier 3 — Hard (concurrency, terminal control, or orchestration)

| Script            | Lines | Obstacle                                                                                                                                                                               |
| ----------------- | ----- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| spinner.sh        | 95    | `trap` + `printf -v` + background worker + cursor save/restore; needs signal handling and raw terminal state (Lua lacks job control; needs a signal module, e.g. via luasignal or luv) |
| spin.sh           | 119   | same as spinner.sh plus `getopts`, bg worker, sourced-API design                                                                                                                       |
| oc-manager        | 245   | 2 bg processes, `trap`, watch loop, lockfile, ansifilter pipeline                                                                                                                      |
| vercel-status     | 118   | (moderate content) but 24 cmdsub + full JSON modeling -> put late if perfectly preserving formatting matters                                                                           |
| android-specs     | 320   | 14 awk + 4 sed pipelines over adb/dumpsys output; most awk to rewrite in the repo                                                                                                      |
| piper-say         | 234   | streaming TTS pipelines (named pipes via process substitution), mpv/aplay, 15 cmdsub                                                                                                   |
| ts-starter        | 220   | 5 package-manager flows, curl/jq/sponge, husky hook generation; 155 ext tool names                                                                                                     |
| document-with-llm | 316   | multi-language dispatch, per-language collectors, change-detection hashing, LLM CLI coupling                                                                                           |
| create-wiki       | 405   | largest script; rofi UI, caching, 10 sed, per-script doc generation; only worth porting once the wiki itself is restructured                                                           |

## 6. Tier 4 — Do not port (or port differently)

| Script                               | Reason                                                                                                                                              |
| ------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| hooks/path.sh                        | Sourced shell hook manipulating `PATH`; it must run inside the shell to have any effect. Keep as bash.                                              |
| init.sh                              | Symlink farm for bash scripts into `~/.local/bin/scripts`; its job is managing the bash ecosystem itself. Port last, only if the repo is fully Lua. |
| templates/pre-commit-\*.sh (5 files) | Git hooks; they work fine as-is and are trivially replaceable by pointing the hook path at any interpreter. No port value.                          |
| spin.sh (sourced-library mode)       | If used via `source`, its public functions must become `spin.lua` + `require`; same work as Tier 3.                                                 |
| yes.sh (alternative)                 | `coreutils yes` already exists; the port is only worth it as a loop demo.                                                                           |

## 7. Recommended port order

1. `sh.lua`, `loggers.lua`, `helpers.lua` — unblocks everything.
2. `cmdarg.lua` — converts 6 direct consumers and the repo-wide flag idiom.
3. Tier 0 batch (~36 scripts) — mostly mechanical, validates the runtime.
4. Tier 1 batch (~45 scripts) — real logic, no parsing risk.
5. Tier 2, grouped by shared obstacle: JSON consumers first (lua-cjson earns
   its keep), then sed/awk rewrites, then git flows.
6. Tier 3 last, one script per PR; each needs its own design (signals for
   spinners, luv or luasignal for oc-manager, LPeg decisions for android-specs).
7. Tier 4: keep bash.

## 8. Risks and caveats

- **Lua patterns are not regex.** No alternation, no capture groups in
  quantifiers. Every sed/awk rewrite either simplifies the pattern, uses LPeg,
  or shells out to sed/rg. Decide per script; shelling out is the boring default
  and matches the existing `lua/sec2time.lua` style.
- **No job control / no traps.** Tier 3 spinner and oc-manager work needs a C
  binding (luasignal, luv) or LuaJIT FFI. Budget for that dependency or keep
  those two in bash.
- **Exit codes and stderr.** `os.execute`/`io.popen` gaps make `sh.lua` the
  correctness-critical piece; test it against the pipefail-sensitive scripts
  (log-error's SIGUSR1 signaling to parent has no Lua equivalent — the
  `log-*` scripts' parent-signaling behavior changes when ported).
- **Wiki and tooling coupling.** `create-wiki` only documents bash scripts, and
  `check-deps`/`mkscript` signatures assume bash. Every ported script leaves
  the wiki generator's coverage until create-wiki learns Lua (Tier 3 dependency
  argument for deferring it).
- **Script-count summary:** \~36 trivial, \~45 easy, \~55 moderate, \~10 hard,
  \~5 keep-as-bash, out of ~150 bash scripts.
