# Shell Scripts and Utilities

A curated collection of utility scripts for developers, sysadmins, and power users. Small, sharp tools that slot into your shell like they were always there.

## Documentation

Full per-script reference lives in the [wiki](https://github.com/AhmedOsman101/shellScripts/wiki) — auto-generated pages for every executable in the repo (and its libraries).

## Repository Purpose

A grab-bag of scripts that automate the repetitive, simplify the common, and compose with each other. See the [Highlights](#highlights) below for categories and examples — the [wiki](https://github.com/AhmedOsman101/shellScripts/wiki) has the full list.

## Installation

The repo hooks into your shell via a sourced hook script (`hooks/path.sh`), not by symlinking into a bin directory. Each shell startup runs the hook, which scans the repo for executables and adds their directories to `PATH` (mtime-cached, so the scan cost is paid once per session).

```bash
# Add this line to your shell config:
export SCRIPTS_DIR="$HOME/scripts" # Replace that with the location you want

# Clone the repo
git clone https://github.com/AhmedOsman101/shellScripts.git "$SCRIPTS_DIR"

# Initialize the scripts directory and set up your shell(s).
cd "$SCRIPTS_DIR" && ./init.sh # You can run ./init.sh --help first to know the available options
```

`init.sh` verifies dependencies (needs `fd`), prompts to confirm, and adds the hook source line to `~/.bashrc` or `~/.zshrc`. Restart your shell (or `source` the config) to activate.

## Highlights

A few categories to give you the shape of the repo:

### File & Text Manipulation

- `trunc` — truncate strings to length with ellipsis
- `strip-ext` — strip file extensions
- `no-dups` — remove duplicate lines
- `get-unique` — filter lines that appear once
- `remove-blanks` — drop blank lines

### Git Workflow

- `gitsync` — automated add/commit/push with timestamp
- `git-commit` — conventional commit messages, AI-generated or manual
- `rmbranch` — delete a branch locally and remotely
- `switch-branch` — interactive branch switcher
- `git-root` — print the repo root from anywhere

### Development Tooling

- `mkscript` — scaffold new bash scripts with signatures and conventions
- `mkpython` — scaffold Python projects with a wrapper script
- `clangc` / `cppc` — compile-and-run C/C++ in one step
- `shellfmt` — format and lint bash
- `ts-starter` — bootstrap TypeScript projects with biome + husky

### System Administration

- `clean-pacman` — drop unused pacman/paru cache
- `no-orphans` — remove orphan AUR packages
- `aur-install` — interactive AUR installer (fzf + paru)
- `cpu-usage` — current CPU usage percentage
- `system-stats` — CPU, RAM, disk at a glance

### CLI Affordances

Lives in `lib/` and is sourced by other scripts:

- `lib/loggers.sh` — `log-info`, `log-success`, `log-warning`, `log-error`
- `lib/helpers.sh` — `yesNo`, `Trims`, `print-args`, and dozens more
- `lib/cmdarg.sh` — argument parsing
- `spinner.sh` — colored terminal spinners

### Media & Documents

- `ocr` / `ocrcp` — extract text from images (Tesseract)
- `piper-say` — text-to-speech via Piper TTS
- `blank-image` / `image-text` — quick image generation
- `md2docx` — markdown to Word via pandoc

### Network

- `get-ip` — IP of the active interface
- `net-interface` — name of the active interface
- `net-speed` — live download/upload monitoring
- `vercel-status` — latest deployments on Vercel

For every script's flags, parameters, and full usage, see the [wiki](https://github.com/AhmedOsman101/shellScripts/wiki).

## Feedback

File issues and PRs on the repo. See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.
