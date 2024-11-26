#!/usr/bin/env bash
# shellcheck disable=SC2199

# Exit immediately if any command exits with a non-zero status.
set -e

# Define a function for cloning the repository.
start_clone() {
  local path="$1"
  local cloneCommand="$2"
  local folderName="$3"

  # Change to the specified directory.
  if ! cd "$path"; then
    echo "Error: Unable to change directory to $path" >&2
    exit 1
  fi

  # Execute the clone command.
  if ! eval "$cloneCommand"; then
    echo "Error: Command failed" >&2
    exit 1
  fi

  # Change to the newly created directory.
  if ! cd "$path/$folderName"; then
    echo "Error: Unable to change directory to $path" >&2
    exit 1
  fi
}

# Parse command-line arguments.
path=""
for arg in "$@"; do
  case $arg in
  --path=*)
    path="${arg#*=}"
    ;;
  esac
done

read -rp 'Enter the repo URL: ' repoUrl

# Get the repo URL and remove the '.git' at the end.
repoUrl="${repoUrl%.git}"

folderName=$(basename "$repoUrl")

# Determine the clone command based on the arguments (use git or GitHub CLI).
cloneCommand="git clone $repoUrl" # Default to git.
if [[ "$@" == *"-gh"* ]]; then
  cloneCommand="gh repo clone $repoUrl"
fi

# Check if the path is an empty string.
if [[ -z "$path" ]]; then
  if ! eval "$cloneCommand"; then
    echo "Git Error: Command failed" >&2
    exit 1
  fi
  # Change to the newly created directory.
  if ! cd "$folderName"; then
    echo "Error: Unable to change directory to $folderName" >&2
    exit 1
  fi
else
  # Use the provided path.
  mkdir -p "$path"
  path=$(realpath "$path")

  # Clone the repository.
  start_clone "$path" "$cloneCommand" "$folderName"
fi

# Open in VS Code.
if ! (code . || subl . || open .); then
  echo "Error: Unable to open the folder" >&2
  exit 1
fi
