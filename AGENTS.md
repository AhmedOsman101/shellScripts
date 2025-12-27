# Agent Guidelines for Scripts Repository

This document provides guidelines for AI coding agents working on this repository. It contains build/lint/test commands, code style conventions, and development practices.

## Build/Lint/Test Commands

### Deno/TypeScript Projects

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

- **Includes**: Use `eval "$(include "lib/library.sh")"` for including libraries
- **Script Signature**: Include ASCII art signature with description and dependencies using `./make-signature` script
- **Exit Codes**: Use appropriate exit codes (0 for success, 1 for errors)

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

- **Use Templates**: Use `./mkpython` script to initalize a new python script
- **Virtual Environment**: Use venv for isolation
- **Requirements**: Document dependencies in `requirements.txt`
- **Imports**: Group imports (stdlib, third-party, local)
- **Error Handling**: Use try-except blocks with specific exceptions
- **Type Hints**: Use type hints where beneficial

### C/C++ Code

- **Compilation**: Use clang for C, g++ for C++
- **Headers**: Include necessary headers
- **Error Handling**: Check return values and use appropriate error codes
- **Memory Management**: Proper memory allocation/deallocation
- **Naming**: Use camelCase for variables and functions and PascalCase for type, interfaces, classes, etc.

## Development Practices

### Git Workflow

- **Commits**: Use descriptive commit messages with the `./git-commit --ai --yes` script
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

# --- Main script logic --- #
# Implementation here

exit 0
```

### Error Handling Patterns

```bash
# Bash: Check for command existence
if ! command -v some_command &>/dev/null; then
  log-error "some_command is required but not installed"
fi
```

```typescript
// TypeScript: Error handling
try {
  // risky operation
} catch (error) {
  console.error(`Error: ${error.message}`);
  Deno.exit(1);
}
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

```typescript
// TypeScript: Read from stdin
async function input(prompt: string): Promise<string> {
  const rl = createInterface({
    input: process.stdin,
    output: process.stdout,
  });
  return new Promise(resolve => {
    rl.question(prompt, answer => {
      rl.close();
      resolve(answer);
    });
  });
}
```

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
