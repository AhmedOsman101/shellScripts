#!/usr/bin/env bash

# inputs=()

# # If no arguments, read from stdin
# if [[ $# -eq 0 || $1 == "-" ]]; then
#   # read from stdin
#   str=$(cat)
#   print-args "${str}" && exit
# fi

# # Process each argument
# for arg in "$@"; do
#   # Special case: "-" means stdin
#   if [[ "${arg}" == "-" ]]; then
#     input=$(cat)
#   # Check if it's a file descriptor from process substitution
#   elif [[ -r "${arg}" ]] && [[ "${arg}" =~ ^/dev/fd/ ]] || [[ "${arg}" =~ ^/proc/self/fd/ ]]; then
#     input=$(cat -- "${arg}")
#   # Check if it's a regular file
#   elif [[ -f "${arg}" ]]; then
#     input=$(cat -- "${arg}")
#   else
#     # Treat as literal text
#     input="${arg}"
#   fi
#   inputs+=("${input}")
# done

# print-args "${inputs[@]}"

inputs=()

# Track if we should read stdin (when no args or when - is used)
stdin_content=""

# Read stdin once and store it
if ! [[ -t 0 ]]; then # Check if stdin is not a terminal (has data)
  stdin_content=$(cat)
  # If no arguments, we'll use this stdin content directly
  if [[ $# -eq 0 ]]; then
    inputs+=("${stdin_content}")
    print-args "${inputs[@]}"
    exit 0
  fi
fi

# Process each argument
for arg in "$@"; do
  # Special case: "-" means use stdin content
  if [[ "${arg}" == "-" ]]; then
    if [[ -n "${stdin_content}" ]]; then
      inputs+=("${stdin_content}")
    else
      # No stdin was provided, but - was specified
      log-warning "'-' specified but no stdin input"
    fi
  # Check if it's a file descriptor from process substitution
  elif [[ -r "${arg}" ]] && { [[ "${arg}" =~ ^/dev/fd/ ]] || [[ "${arg}" =~ ^/proc/self/fd/ ]]; }; then
    inputs+=("$(cat -- "${arg}")")
  # Check if it's a regular file
  elif [[ -f "${arg}" ]]; then
    inputs+=("$(cat -- "${arg}")")
  else
    # Treat as literal text
    inputs+=("${arg}")
  fi
done

print-args "${inputs[@]}"
