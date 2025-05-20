# Shell Scripts and Utilities

Welcome to the `shellScripts` repository! This repository contains a collection of scripts designed to simplify and automate daily tasks for developers, system administrators, and anyone looking to enhance productivity.

## Repository Purpose

This repository is a curated collection of scripts that help us in:

- Automating repetitive tasks
- Simplifying workflows
- Enhancing coding productivity
- Providing solutions to common challenges in development and other domains

## Installation:

Add the repository to your `PATH` for easy access to all scripts:

```bash
# 1. Clone repository
git clone https://github.com/yourusername/scripts.git $HOME/scripts

# 2. Run the init script
./init.sh

# 3. Refresh shell (if needed)
source ~/.bashrc  # or source ~/.zshrc
```

**Benefits:**

- Automatic updates via `git pull`
- Access all scripts without `./` prefix
- Add new scripts without reconfiguring PATH

## Available Scripts

Below is a list of some useful scripts included in this repository:

Here's the documentation for your clangc script to add to the Available Scripts section:

### 1. clangc

Rapid C code compiler/executor with automatic cleanup.

#### Features:

- Compiles C source files with clang in one step
- Executes the program immediately after successful compilation
- Uses temporary files to avoid cluttering the filesystem
- Automatically cleans up compiled binaries after execution
- Immediate error checking during compilation
- Preserves compiler error messages

#### Usage:

```bash
clangc <filename> <args>
```

#### Parameters:

- `<filename>`: (Required) C source file to compile and execute
- `<args>`: (Optional) Compiler arguments

#### Dependencies:

- clang compiler
- Standard UNIX utilities (mktemp, rm, basename)

#### Example:

```bash
clangc hello_world.c
```

#### Notes:

- Add execute permission first: `chmod u+x clangc`
- For repeated executions, consider adding the repository to your `$PATH` enviroment variable.
- Tested with bash/zsh on Linux/macOS

---

### 2. cppc

C++ equivalent compiler/executor using g++.

#### Features:

- Compiles C++ files with g++ and runs output immediately
- Automatic temporary file management with cleanup
- Streamlined development workflow for quick testing
- Preserves compiler errors while eliminating manual cleanup

#### Usage:

```bash
cppc <filename> <args>
```

#### Parameters:

- `filename.cpp`: (Required) C++ source file to process
- `<args>`: (Optional) Compiler arguments

#### Dependencies:

- g++ compiler
- Standard UNIX utilities (mktemp, rm, basename)

#### Example:

```bash
cppc app.cpp
```

#### Notes:

- Ensure execute permissions: `chmod u+x cppc`
- Temp files follow pattern: `cppc-XXXXXX.out`

---

### 3. down-ext-file

VSCode extension bulk downloader from JSON manifest.

#### Features:

- Downloads `.vsix` files for extensions specified in JSON format
- Automatically creates `extensions` directory if missing
- Skips already downloaded files
- Shows progress bar during downloads
- Handles publisher/extension URL construction automatically
- Comprehensive error handling for missing files/invalid JSON

#### Usage:

```bash
down-ext-file <filename>
```

#### Requirements:

- JSON file named `extensions.json` in current directory or a valid JSON file name
- File format: Array of `"publisher.extensionName"` strings

#### Dependencies:

- `jq` for JSON parsing
- `wget` for downloads
- `cut` for string processing
- Logging utilities (log-error, log-info, etc.)

#### Example `extensions.json`:

```json
[
  "ms-vscode.cpptools",
  "aaron-bond.better-comments",
  "adam-bender.commit-message-editor",
  "adrianwilczynski.alpine-js-intellisense",
  "amodio.toggle-excluded-files"
]
```

#### Typical Output:

```
Downloading ms-vscode.cpptools.vsix...
[INFO]: Downloaded cpptools
Downloading golang.go.vsix...
[INFO]: Downloaded go

Done 🚀
```

#### Notes:

- Creates files in `./extensions/` directory, it creates it if not available
- File names follow `<extensionName>.vsix` pattern
- Requires valid internet connection
- Recommended for offline VSCode installation setups

---

### 4. get-ext

VS Code extension manifest generator with safe file handling.

#### Features:

- Creates JSON manifest of installed VS Code extensions
- Automatically formats output as `["publisher.extension"]` array
- Prevents accidental file overwrites with confirmation prompt
- Supports custom output filenames and forced overwrites (`-o`)
- Compatible with `down-ext-file` script format

#### Usage:

```bash
get-ext [filename] [-o]
```

#### Parameters:

- `filename`: (Optional) Output file name (default: `extensions.json`)
- `-o`: Force overwrite without confirmation

#### Dependencies:

- VS Code CLI (`code` command)
- `jq` JSON processor
- Basic UNIX utilities (readarray, touch)
- Logging utilities (log-info, log-warning) available in the repo

#### Example Output File:

```json
[
  "ms-vscode.cpptools",
  "aaron-bond.better-comments",
  "adam-bender.commit-message-editor",
  "adrianwilczynski.alpine-js-intellisense",
  "amodio.toggle-excluded-files"
]
```

#### Common Use Cases:

1. Create default manifest:

```bash
get-ext
```

2. Force-overwrite existing file:

```bash
get-ext -o
```

3. Custom filename:

```bash
get-ext my-extensions.json
```

---

### 5. install-ext

VS Code extension bulk installer from `.vsix` files.

#### Features:

- Installs all extensions from a directory of `.vsix` packages
- Works with output from `down-ext-file` script
- Automatic directory navigation and error handling
- Shows individual installation status for each extension
- Defaults to `extensions` directory when no argument specified

#### Usage:

```bash
install-ext [directory]
```

#### Parameters:

- `directory`: (Optional) Target directory containing `.vsix` files (default: `extensions`)

#### Dependencies:

- VS Code CLI (`code` command)
- Logging utilities (log-error, log-success)

#### Example:

```bash
install-ext my-extensions
```

#### Typical Workflow:

1. Download extensions using `down-ext-file`
2. Install all with one command:

```bash
install-ext
```

#### Notes:

- Requires VS Code to be installed and in system PATH
- Maintains compatibility with extension packages from:
  - Marketplace (via `down-ext-file`)
  - Manual downloads
- Combines with `get-ext`/`down-ext-file` for full backup/restore cycle

---

### 6. repeat-it

Command retry utility with exponential persistence.

#### Features:

- Repeats commands until successful exit (0 status code)
- Automatic 5-second retry interval with counter
- Clean screen between attempts for better visibility
- Shows progress updates and final success summary
- Universal compatibility with any CLI command

#### Usage:

```bash
repeat-it "your_command"
```

#### Parameters:

- `your_command`: (Required) Command to execute and retry

#### Dependencies:

- Basic POSIX-compliant shell utilities
- Standard Linux/Unix core utilities
- Logging utilities (log-info, log-success)

#### Example:

```bash
repeat-it "curl -sS http://flaky-server/api"
```

#### Notes:

- Handles complex commands with arguments/quoting:
  ```bash
  repeat-it "docker compose up --build"
  ```
- Success message only appears after retries
- Exits with final command's status code

---

### 7. which-cpp

C++ compiler detector and version reporter.

#### Features:

- Detects installed C++ compilers in priority order (clang++ > g++ > c++)
- Parses and formats version information consistently
- Standardizes output format across different compilers
- Silent operation with only version output

#### Usage:

```bash
which-cpp
```

#### Parameters:

- No parameters required

#### Dependencies:

- At least one C++ compiler (clang++/g++)
- `awk` for version parsing
- Standard UNIX utilities (command, head)

#### Example Output:

```text
clang++ v15.0.7
```

#### Notes:

- Priority order detection ensures consistent reporting
- Handles multiple compiler aliases (g++/c++)
- Possible outputs include:
  - `clang++ vX.X.X`
  - `g++ vX.X.X`
  - Fallback to raw compiler output if unknown format

---

### 8. net-interface

Primary network interface detector with fallback logic.

#### Features:

- Identifies active network interface through routing tables
- Checks connectivity to Cloudflare (1.1.1.1) and Google DNS (8.8.8.8)
- Returns first available interface name without error messages
- Silent failure mode (empty output when no interface found)

#### Usage:

```bash
net-interface
```

#### Parameters:

- No parameters required

#### Dependencies:

- `ip` command (from iproute2 core package)
- `awk` for output parsing

#### Example Output:

```text
wlan0
```

#### Notes:

- Linux-specific (uses modern `ip` command syntax)
- Prioritizes interfaces with internet connectivity
- Typical outputs: `eth0`, `wlan0`, `enp0s3`
- Returns empty string if no network connection detected
- Useful for scripting network configuration tasks

---

### 9. get-ip

Network IP address fetcher with interface context.

#### Features:

- Retrieves current IP address for active network interface
- Uses `net-interface` script to determine primary connection
- Combines IPv4/IPv6 detection in single command
- Returns address with CIDR notation (e.g., 192.168.1.10/24)

#### Usage:

```bash
get-ip
```

#### Parameters:

- No parameters required

#### Dependencies:

- `net-interface` script (from the repository)
- `ip` command (iproute2 core package)
- `rg` (ripgrep)
- `awk` for output parsing

#### Example Output:

```text
192.168.1.15/24
```

#### Notes:

- Returns first found IP address for active interface
- Combine with subnet trimmer if needed:
  `get-ip | cut -d'/' -f1`
- Handles both wired and wireless connections
- Returns error if no network interface has IP assignment
- Linux-specific implementation (uses modern `ip` syntax)

---

### 10. get-unique

Unique line filter with in-place file modification.

#### Features:

- Removes lines with duplicates (keeps only single-occurrence entries)
- Preserves original order of first unique occurrences
- Supports both files and stdin input
- Optional backup creation with `-b` flag
- Temp file handling with automatic cleanup

#### Usage:

```bash
# File mode (modifies directly)
get-unique filename.txt

# File mode (creates a backup of the file)
get-unique -b filename.txt

# STDIN mode (non-destructive)
cat input.txt | get-unique
```

#### Parameters:

- `filename`: (Optional) Target file (use "-" for explicit stdin)
- `-b`: Create backup file with `.bak` extension

#### Dependencies:

- `awk` for efficient line processing
- Coreutils (mktemp, cp, cat)
- Logging utilities (log-info, log-error)

#### Example:

```bash
# Original file:
# apple
# orange
# apple

get-unique -b fruits.txt

# Resulting file:
# orange

# [INFO]: Backup created as fruits.txt.bak
```

#### Notes:

- Order-preserving operation (maintains original line sequence)
- Empty lines are treated as valid entries
- Case-sensitive comparison ("Apple" ≠ "apple")
- For CLI use without modification:

```bash
get-unique < input.txt > output.txt
```

- Combines well with sort/uniq workflows
- The `-b` (backup) flag must precede the filename. For example, `get-unique -b file.txt` creates a backup; `get-unique file.txt -b` will not.

---

### 11. no-dups

Order-preserving duplicate remover with backup capability.

#### Features:

- Removes subsequent duplicates while keeping first occurrence
- Maintains original line order of remaining entries
- Supports both file modification and stdin/stdout workflows
- Creates `.bak` backups with `-b` flag (must precede filename)
- Temp file handling with automatic cleanup

#### Usage:

```bash
# File modification mode
no-dups -b input.txt  # Creates input.txt.bak

# Piping mode (non-destructive)
cat data.txt | no-dups
```

#### Parameters:

- `-b`: Create backup before modification (must come first)
- `filename`: Target file (optional, uses stdin if omitted)

#### Dependencies:

- `awk` for efficient deduplication
- Coreutils (mktemp, mv, cp)
- Logging utilities (log-info, log-error)

#### Example:

```text
Original File       Processed File
apple              apple
apple              orange
orange             banana
banana
orange
```

#### Notes:

- Case-sensitive comparison ("Foo" ≠ "foo")
- Empty lines are considered valid entries
- Backup flag syntax is strict: `no-dups -b file.txt`
- Combine with other tools for sorted deduplication:

```bash
sort file.txt | no-dups > deduped.txt
```

---

### 12. gitsync

Git workflow automator with timestamped commits.

#### Features:

- Automated `stage -> commit -> push` workflow
- Timestamp-preserved commit messages (ISO 8601 + 12h format)
- Current branch detection or manual branch specification
- Built-in help documentation
- Auto-verifies Git repository status
- Branch switching validation

#### Usage:

```bash
# Default mode (current branch)
gitsync

# Specific branch mode
gitsync -b develop

# Help documentation
gitsync -h
```

#### Parameters:

- `-h`: Show help message
- `-b <branch>`: Target branch (switches if needed)

#### Dependencies:

- Git CLI
- Coreutils (date)
- Logging utilities

#### Example Workflow:

```bash
# On feature/x123 branch
gitsync -b main
# Switches to main, commits, pushes
```

#### Notes:

- Commit message format:
  `Updated Files 2025-02-2@03:35AM`
- Uses `git add "*"` (explicit glob pattern)
- Recommend combine with PATH setup for global access:
  ```bash
  gitsync -b release
  ```
- Verifies Git repo status before operations
- Fails gracefully on non-Git directories

---

### 13. install-ext-online

VSCode extension sync tool for online installations.

#### Features:

- Compares installed extensions with a reference JSON file
- Installs missing extensions from the VSCode Marketplace
- Uses `repeat-it` for resilient installation attempts
- Preserves existing extensions while adding new ones
- Automatic temp file cleanup

#### Usage:

```bash
install-ext-online reference.json
```

#### Parameters:

- `reference.json`: (Required) File containing desired extensions in `["publisher.extension"]` format

#### Dependencies:

- `get-ext` (from the repo)
- `get-unique` (from the repo)
- `repeat-it` (from the repo)
- VSCode CLI (`code` command)
- `jq` JSON processor

#### Notes:

- Requires active internet connection
- Reference file format must match `get-ext` output
- Installation output suppressed for cleanliness
- Force-installs extensions (`--force` flag)
- Combines with other scripts for full extension management:
  `get-ext -> edit -> install-ext-online`

---

### 14. net-speed

Real-time network speed monitor with icon visualization.

#### Features:

- Displays live download/upload speeds in Kbps
- Uses kernel-level network interface statistics
- Auto-detects primary network interface
- Continuous refresh (1-second interval)
- Nerd Font icon integration for visual display

#### Usage:

```bash
net-speed
```

#### Parameters:

- No parameters required

#### Dependencies:

- `net-interface` (from the repo)
- `/sys` filesystem (Linux kernel interface)
- Nerd Fonts for icon display (recommended)

#### Example Output:

```text
 14 Kbps  60 Kbps
 19 Kbps  27 Kbps
```

#### Notes:

- Linux-specific implementation
- Runs indefinitely until interrupted (Ctrl+C or Ctrl+D)
- Speed calculation formula:
  - `(bytes_diff * 8 bits) / 1024 = Kbps`
- Icons represent:
  -  (Download)
  -  (Upload)
- Interface detection matches `net-interface` script logic

---

### 15. load-fonts

Font management utility for system-wide font installation.

#### Features:

- Automates font installation from user's `~/fonts` directory
- Creates standard font directories if missing
- Handles both TTF and OTF font formats
- Automatic font cache refresh
- Silent operation with selective warnings

#### Usage:

```bash
load-fonts
```

#### Parameters:

- No parameters required

#### Dependencies:

- `fc-cache` (fontconfig)
- Standard font directories (automatically created if not present):
  - `/usr/share/fonts/TTF`
  - `/usr/share/fonts/OTF`
- Logging utilities (log-info, log-warning)

#### Notes:

- Requires `sudo` privileges
- Source directory: `~/fonts`
- Installation paths:
  - `.ttf` → `/usr/share/fonts/TTF/`
  - `.otf` → `/usr/share/fonts/OTF/`
- Automatic cache refresh ensures immediate availability
- Recommended workflow:
  1. Place fonts in `~/fonts`
  2. Run `load-fonts`
  3. Verify with `fc-list`

---

### 16. Logging Utilities

**Color-coded message handlers for script feedback:**

#### **log-error**

- Color: Red (31m)
- Usage: `log-error "message"`
- Effect: Prints error message and exits with code 1
- Example:

```bash
log-error "File not found"
# Output: [ERROR]: File not found
```

#### **log-warning**

- Color: Yellow (33m)
- Usage: `log-warning "message"`
- Effect: Prints warning message (non-blocking)
- Example:

```bash
log-warning "Low disk space"
# Output: [WARNING]: Low disk space
```

#### **log-info**

- Color: Blue (34m)
- Usage: `log-info "message"`
- Effect: Prints informational message
- Example:

```bash
log-info "Processing data"
# Output: [INFO]: Processing data
```

#### **log-success**

- Color: Green (32m)
- Usage: `log-success "message"`
- Effect: Prints success confirmation
- Example:

```bash
log-success "Operation completed"
# Output: [SUCCESS]: Operation completed
```

**Common Features:**

- ANSI color codes for visual distinction
- Standardized message formatting
- Terminal output compatibility
- Used by other scripts in the repository

**Implementation Notes:**

- Designed for bash/zsh environments
- Color codes reset automatically after each message
- Essential for unified script feedback system

---

### 17. md2docx

Markdown-to-DOCX converter with template support.

#### Features:

- Converts markdown files to DOCX format
- Supports custom templates via `MRT` environment variable
- Preserves original filename for output
- Automatic error handling for failed conversions

#### Usage:

```bash
md2docx input.md
```

#### Parameters:

- `input.md`: (Required) Markdown file to convert

#### Dependencies:

- `pandoc` (primary conversion engine)
- `sed` for filename processing

#### Environment Variable:

- `MRT`: Path to custom `.dotx` template file (optional)

#### Example Workflow:

```bash
# Basic conversion
md2docx README.md  # Creates README.docx

# Template-based conversion
export MRT="$HOME/templates/custom.dotx"
md2docx REPORT.md  # Uses custom template
```

#### Notes:

- Output file matches input name (e.g., `file.md` -> `file.docx`)
- Template file must exist if `MRT` is set
- Conversion errors show detailed pandoc messages
- Common use cases:
  - Technical documentation
  - Academic paper formatting
  - Standardized report generation

## How to Contribute

We welcome contributions! If you have scripts you'd like to share or improvements for existing ones, please:

1. Fork the repository.
2. Add your script in the appropriate folder.
3. Update this `README.md` with details about your script.
4. Submit a pull request.

---

## Feedback

I'd love to hear from you! If you have suggestions, feedback, or feature requests, feel free to open an issue or reach out to the maintainers.
