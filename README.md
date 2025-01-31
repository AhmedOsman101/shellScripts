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

# 2. Add to PATH (add to your .bashrc/zshrc)
echo 'export PATH="$HOME/scripts:$PATH"' >> ~/.bashrc  # or ~/.zshrc

# 3. Refresh shell
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
clangc <filename>
```

#### Parameters:

- `<filename>`: (Required) C source file to compile and execute

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
cppc filename.cpp
```

#### Parameters:

- `filename.cpp`: (Required) C++ source file to process

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

#### Description/Features:

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

#### Description/Features:

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

#### Description/Features:

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

#### Description/Features:

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

## How to Contribute

We welcome contributions! If you have scripts you'd like to share or improvements for existing ones, please:

1. Fork the repository.
2. Add your script in the appropriate folder.
3. Update this `README.md` with details about your script.
4. Submit a pull request.

---

## Feedback

We'd love to hear from you! If you have suggestions, feedback, or feature requests, feel free to open an issue or reach out to the maintainers.
