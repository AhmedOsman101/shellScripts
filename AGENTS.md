# Agent Guidelines for Scripts Repository

This document provides guidelines for AI coding agents working on this repository. It contains build/lint/test commands, code style conventions, and development practices.

## Session Guidelines

- **Read AGENTS.md First**: Always read this document at the start of any session to understand the project's conventions and patterns.
- **Check Existing Functionality**: Before writing new code, search the repository for existing functionality. For example:
  - Instead of manually echoing `[DEBUG] Some message`, use the `log-debug` script. Instead of truncating a string manually use the `trunc` script, and so on.
  - Check for utility functions in `lib/helpers.sh`, `lib/cmdarg.sh`, and other shared libraries
  - Look for similar patterns in existing scripts before implementing from scratch

## Build/Lint/Test Commands

### TypeScript Projects

```bash
# Run with watch mode (development)
deno run --watch --allow-env <file>

# Compile to executable
deno compile -o <file>.out --allow-env <file>.ts

# Type checking
deno check

# Linting (enabled by default in VSCode settings)
deno lint
```

### Bash Scripts

```bash
# Lint with shellcheck
shellcheck script.sh

# Test individual script
./script.sh [args]
```

### C/C++ Compilation

```bash
# Compile and run C code
clangc hello.c

# Compile and run C++ code
cppc hello.cpp

# Build all C/C++ binaries
./c/release.sh
./cpp/release.sh
```

### TypeScript Compilation

```bash
# Build all TypeScript binaries
./typescript/release.sh
```

## Code Style Guidelines

### General

- **EditorConfig**: Follow `.editorconfig` settings (2-space indentation, LF line endings, UTF-8)
- **Line Length**: No strict limit, but prefer readable line lengths
- **File Extensions**: Use appropriate extensions (.sh, .ts, .py, .c, .cpp)

### Bash Scripts

- **Shebang**: Use `#!/usr/bin/env bash`
- **Shellcheck**: Follow rules in `.shellcheckrc`
- **Error Handling**: Use `set -e` for strict error checking
- **Functions**: Use `function_name() { ... }` syntax
- **Variables**: Use `local` for function variables
- **Logging**: Use repository logging utilities:

```bash
log-error "Fatal error message"  # Exits with code 1
log-warning "Warning message"
log-info "Info message"
log-success "Success message"
log-debug "Debug message"
```

**Important**: Never use raw ANSI escape codes (e.g., `\e[33m`) for colored output. Always use the log-\* functions above or functions available in `./lib/loggers.sh` if you need more colors.

- **Includes**: Use `eval "$(include "lib/library.sh")"` for including libraries
- **Script Signature**: Include ASCII art signature with description and dependencies using `./make-signature` script
- **Exit Codes**: Use appropriate exit codes (0 for success, 1 for errors)
- **Creating New Scripts**: Use `./mkscript` script to create new bash scripts. When creating as an agent, set `EDITOR=cat` before running:

```bash
# create a new script in ~/scripts:
EDITOR=cat mkscript -q <script-name>
# create a new script in the current directory:
EDITOR=cat mkscript -q -f test.sh
```

This allows the agent to edit the script immediately after creation.

#### Script Signature & Metadata

- Keep the existing script signature structure intact (ASCII art, DESCRIPTION, DEPENDENCIES sections)
- Add a clear, multiline description if needed using the `#` comment format
- Follow the **Dependencies Rules** strictly (see below)

#### Dependency Declaration Format

- **Exclude** coreutils and basic commands available on any distro (e.g., `grep`, `sed`, `awk`, `cut`, `tr`, `cat`, `echo`)
- **Format examples:**

  ```bash
  # Single dependency, same executable & package name:
  # - ansifilter

  # Single dependency, different executable name:
  # - sponge (moreutils)

  # Multiple alternatives (chooses the first available option):
  # - mpv | aplay
  # - xclip | wl-copy (wl-clipboard) | copyq
  ```

#### Using `cmdarg` for Argument Parsing

Define arguments between `cmdarg_info "header"` and `cmdarg_parse "$@"`:

```bash
cmdarg_info "header" "$(get-desc "$0")"
# Add cmdarg definitions here
cmdarg_parse "$@"
```

- Use `${argv[index]}` for positional arguments and `${cmdarg_cfg['flag']}` for flags
- Avoid using `$@`, `$*`, `$#` after `cmdarg_parse` - these are consumed by the parser
- Use `${argc}` for argument count
- `argv` and `argc` variables are auto-generated after running `cmdarg_parse "$@"` - you don't define them, they come automatically

Example:

```bash
cmdarg_info "header" "$(get-desc "$0")"
cmdarg "v" "verbose" "Enable verbose output"
cmdarg "m:" "message" "The text to be written on the image"
cmdarg "d?" "debounce" "Time to wait for new events" "5s"
cmdarg "c?" "color" "Color of the banner"

cmdarg_parse "$@"

color="${cmdarg_cfg['color']}"
debounce="${cmdarg_cfg['debounce']}"
verbose="${cmdarg_cfg['verbose']}"
message="${cmdarg_cfg['message']}"

# Access positional arguments via argv array
for ((i = 0; i < argc; i++)); do
  echo "Positional arg $i: ${argv[$i]}"
done
```

The `cmdarg` function signature:

- `<option>`: Short option letter, append `?` to make it optional (e.g., "c?") and append `:` to make it required.
- `<key>`: Long option name (used to access value from `cmdarg_cfg`)
- `<description>`: Text description for help output
- `[default value]`: Optional default value for the argument
- `[validator function]`: Optional validator function name

#### Modern Bash Best Practices

- Use Bash 5.x+ features
- Prefer pure Bash string manipulation over external commands where beneficial (see reference tables below)
- Use `(( ))` for all arithmetic operations and conditionals
- Keep scripts modular, readable, and well-commented
- Use `[[ ]]` for string and file tests instead of `[ ]`
- Use `(( ))` for arithmetic comparisons instead of `[ ]` or `test`
- **Naming**: Use only `kebab-case` or `camelCase` for variable and function names
  - Functions: `kebab-case` or `camelCase` (e.g., `get-deps` or `getDeps`)
  - Variables: `camelCase` (e.g., `configPath`, `userName`)
  - Avoid snake_case (`get_deps`) or PascalCase (`GetDeps`) for functions and variables

### TypeScript/Deno

- **Imports**: Use Deno-style imports

```typescript
import process from "node:process";
import { createInterface } from "node:readline";
```

- **NPM Packages**: Use npm: prefix for external packages installation

```bash
deno add npm:emoji-regex
```

```typescript
import emojiRegex from "emoji-regex";
```

- **Types**: Use TypeScript types explicitly

```typescript
type CleanedUrl = { cleanedUrl: string; furtherCleanedUrl?: string };
```

- **Error Handling**: Use try-catch blocks and proper error types
- **Async/Await**: Prefer async/await over promises
- **Functions**: Use named functions where appropriate

### Python Scripts

- **Use Templates**: Use `EDITOR=bat mkpython` script to initalize a new python script
- **Virtual Environment**: Use `uv` and `venv` for isolation
- **Requirements**: Document dependencies in `requirements.txt`
- **Imports**: Group imports (stdlib, third-party, local)
- **Error Handling**: Use try-except blocks with specific exceptions
- **Type Hints**: Use type hints

### C/C++ Code

- **Compilation**: Use `clangc` for C, `cppc` for C++
- **Headers**: Include necessary headers
- **Error Handling**: Check return values and use appropriate error codes
- **Memory Management**: Proper memory allocation/deallocation
- **Naming**: Use camelCase for variables and functions and PascalCase for type, interfaces, classes, etc.

## Reference Tables

### Pure Bash vs. External Commands

| Task                | Old (external)               | New (pure Bash) |
| ------------------- | ---------------------------- | --------------- |
| Get part before `=` | `cut -d= -f1`                | `${var%%=*}`    |
| Get part after `=`  | `cut -d= -f2-`               | `${var#*=}`     |
| Get filename        | `basename "$path"`           | `${path##*/}`   |
| Get directory       | `dirname "$path"`            | `${path%/*}`    |
| Get file extension  | `rev \| cut -d. -f1 \| rev`  | `${file##*.}`   |
| Remove extension    | `cut -d. -f1`                | `${file%.*}`    |
| Lowercase string    | `tr '[:upper:]' '[:lower:]'` | `${var,,}`      |
| Uppercase string    | `tr '[:lower:]' '[:upper:]'` | `${var^^}`      |

### Bash Parameter Expansion Cheatsheet

| Syntax             | Description                                              | Example                                   | Output         |
| ------------------ | -------------------------------------------------------- | ----------------------------------------- | -------------- |
| `${#var}`          | String length (character count).                         | `s="hello"; echo ${#s}`                   | `5`            |
| `${var:pos}`       | Substring starting from position `pos` (0-based).        | `s="abcdef"; echo ${s:2}`                 | `cdef`         |
| `${var:pos:len}`   | Substring of length `len` from `pos`.                    | `echo ${s:1:3}`                           | `bcd`          |
| `${var: -n}`       | Last `n` characters (note space before `-`).             | `echo ${s: -2}`                           | `ef`           |
| `${var^}`          | Uppercase **first** character.                           | `s="foo"; echo ${s^}`                     | `Foo`          |
| `${var^^}`         | Uppercase **all** characters.                            | `echo ${s^^}`                             | `FOO`          |
| `${var,}`          | Lowercase first character.                               | `S="Bar"; echo ${S,}`                     | `bar`          |
| `${var,,}`         | Lowercase all characters.                                | `S="BAR"; echo ${S,,}`                    | `bar`          |
| `${var#pattern}`   | Remove _shortest_ match from start.                      | `f="foo/bar/baz"; echo ${f#*/}`           | `bar/baz`      |
| `${var##pattern}`  | Remove _longest_ match from start.                       | `echo ${f##*/}`                           | `baz`          |
| `${var%pattern}`   | Remove _shortest_ match from end.                        | `f="foo/bar/baz"; echo ${f%/*}`           | `foo/bar`      |
| `${var%%pattern}`  | Remove _longest_ match from end.                         | `echo ${f%%/*}`                           | `foo`          |
| `${var/pat/repl}`  | Replace **first** match of `pat` with `repl`.            | `s="foo bar"; echo ${s/o/a}`              | `fao bar`      |
| `${var//pat/repl}` | Replace **all** matches.                                 | `echo ${s//o/a}`                          | `faa bar`      |
| `${var/#pat/repl}` | Replace only if `pat` matches **start**.                 | `s="foobar"; echo ${s/#foo/xxx}`          | `xxxbar`       |
| `${var/%pat/repl}` | Replace only if `pat` matches **end**.                   | `s="foobar"; echo ${s/%bar/zzz}`          | `foozzz`       |
| `${var##*/}`       | Basename (strip longest prefix ending with `/`).         | `p="/usr/bin/bash"; echo ${p##*/}`        | `bash`         |
| `${var%/*}`        | Dirname (strip shortest suffix starting with `/`).       | `echo ${p%/*}`                            | `/usr/bin`     |
| `${file%%.*}`      | Strip **extension** (everything after first dot).        | `file="archive.tar.gz"; echo ${file%%.*}` | `archive`      |
| `${file%.*}`       | Strip **last** extension (after last dot).               | `echo ${file%.*}`                         | `archive.tar`  |
| `${!prefix*}`      | Expands all variable names starting with `prefix`.       | `U_RED=#f00; echo ${!U_*}`                | `U_RED`        |
| `${!name}`         | Indirect expansion (value of variable named by `$name`). | `ref="PATH"; echo ${!ref}`                | (your `$PATH`) |

## Development Practices

### Git Workflow

- **Commits**: Use descriptive commit messages with the `git-commit --ai --yes` script
- **Branching**: Feature branches for new work
- **Pre-commit**: Use provided pre-commit hooks for formatting (if any)

### Testing

- **Manual Testing**: Test scripts manually before committing
- **Edge Cases**: Consider error conditions and edge cases
- **Dependencies**: Ensure all dependencies are available

### Documentation

- **README Updates**: Update README.md when adding/modifying scripts
- **Comments**: Add comments for complex logic
- **Usage Examples**: Provide clear usage examples in script documentation

## File Organization

```
/scripts/
├── lib/           # Shared libraries
├── bin/           # Compiled binaries
├── c/             # C source files
├── cpp/           # C++ source files
├── python/        # Python scripts
├── lua/           # Lua scripts
├── typescript/    # TypeScript/Deno projects
├── rofi/          # Rofi scripts
├── templates/     # Template files
└── external/      # External tools/binaries
```

## Common Patterns

### Script Template (Bash)

```bash
#!/usr/bin/env bash
#
# --- SCRIPT SIGNATURE --- #
#
# [ASCII ART]
#
# --- DESCRIPTION --- #
# Brief description of what the script does
#
# --- DEPENDENCIES --- #
# - dependency1
# - dependency2
#
# --- END SIGNATURE --- #

set -eo pipefail
trap 'exit 1' SIGUSR1

eval "$(include "lib/cmdarg.sh")"
eval "$(include "lib/helpers.sh")"

# --- cmdarg setup --- #
cmdarg_info "header" "$(get-desc "$0")"
# Add cmdarg definitions here

cmdarg_parse "$@"

# Access cmdarg_cfg values
# local value="${cmdarg_cfg['option-name']}"
# local positional_arg="${argv[0]}"

# --- Main script logic --- #
# Implementation here
```

### Input/Output Patterns

```bash
# Bash: Handle stdin or arguments (this function available in ./lib/helpers.sh)
input() {
  local str
  if [[ $# -eq 0 || $1 == "-" ]]; then
    str=$(cat)  # read from stdin
  else
    str="$*"   # read from arguments
  fi
  echo "${str}"
}
```

### Reusable Libraries

When creating functionality that might be useful across multiple scripts, extract it to a shared library in `lib/`:

```bash
# Example: Creating a new library
cd "${SCRIPTS_DIR:-"$HOME/scripts"}"
EDITOR=cat mkscript -q -f lib/testing.sh

# Include the library in other scripts
eval "$(include "lib/my-library.sh")"
```

**Available Reusable Libraries**:

- `lib/diff-handler.sh`: Functions for handling file diffs when files exist (`getDiffTools`, `selectDiffTool`, `showDiff`, `handleExistingFile`)
- `lib/cmdarg.sh`: Command line argument parsing
- `lib/helpers.sh`: Helper functions for common tasks
- `lib/loggers.sh`: Logging utilities

## Security Considerations

- **Input Validation**: Always validate user inputs (check ./lib/helpers.sh for validation functions for bash)
- **Command Injection**: Use proper quoting and avoid eval when possible
- **Secrets**: Never commit sensitive information
- **Sandboxing**: Use appropriate Deno permissions (--allow-\* flags)

## Performance Guidelines

- **Efficiency**: Prefer efficient algorithms and tools
- **Resource Usage**: Be mindful of memory and CPU usage
- **Caching**: Implement caching where beneficial
- **Async Operations**: Use async operations for I/O bound tasks

## Contributing

When adding new scripts:

1. Follow the established patterns and conventions
2. Add appropriate documentation to README.md
3. Include dependencies in script signature
4. Test thoroughly before committing
5. Update this AGENTS.md if new patterns are established

## Tool-Specific Notes

- **Biome**: Used for JavaScript/TypeScript/JSON formatting and linting
- **Shellcheck**: Primary linter for bash scripts
- **Deno**: Runtime for TypeScript projects with built-in tooling
- **EditorConfig**: Ensures consistent formatting across editors
