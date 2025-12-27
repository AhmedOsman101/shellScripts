#!/usr/bin/env bash

declare -A DIFF_TOOLS=(
  ["code"]="code --diff"
  ["cursor"]="cursor --diff"
  ["ag"]="ag --diff"
  ["codium"]="codium --diff"
  ["vscode"]="vscode --diff"
  ["meld"]="meld"
  ["kdiff3"]="kdiff3"
  ["diffmerge"]="diffmerge"
  ["kompare"]="kompare"
  ["vimdiff"]="vimdiff"
  ["colordiff"]="colordiff -u"
  ["diff"]="diff -u --color=always"
)

getDiffTools() {
  local available_tools=()

  for tool in "${!DIFF_TOOLS[@]}"; do
    if command -v "${tool}" >/dev/null 2>&1; then
      available_tools+=("${tool}")
    fi
  done

  if ! ((${#available_tools[@]})); then
    available_tools=("diff")
  fi

  for tool in "${available_tools[@]}"; do
    echo "${tool}"
  done
}

getCachedDiffTool() {
  local cache_file="${XDG_CACHE_HOME:-${HOME}/.cache}/diff-handler/diff-tool.txt"

  if [[ -f ${cache_file} ]]; then
    cat "${cache_file}"
  fi
}

setCachedDiffTool() {
  local tool="$1"
  local cache_dir="${XDG_CACHE_HOME:-${HOME}/.cache}/diff-handler"
  local cache_file="${cache_dir}/diff-tool.txt"

  mkdir -p "${cache_dir}"
  echo "${tool}" >"${cache_file}"
}

selectDiffTool() {
  local available_tools
  mapfile -t available_tools < <(getDiffTools)
  local cached_tool
  cached_tool=$(getCachedDiffTool)

  if [[ -n ${cached_tool} ]]; then
    for tool in "${available_tools[@]}"; do
      if [[ ${tool} == "${cached_tool}" ]]; then
        echo "${cached_tool}"
        return
      fi
    done
  fi

  if command -v gum >/dev/null 2>&1; then
    local choice
    choice=$(gum choose --header="Select a diff tool:" "${available_tools[@]}")
    setCachedDiffTool "${choice}"
    echo "${choice}"
  else
    local PS3=$'\nSelect a diff tool: '

    select choice in "${available_tools[@]}"; do
      if [[ -n ${choice} ]]; then
        setCachedDiffTool "${choice}"
        echo "${choice}"
        return
      fi
    done
  fi
}

showDiff() {
  local original="$1" new="$2"
  local tool

  tool=$(selectDiffTool)
  local tool_cmd="${DIFF_TOOLS[${tool}]}"

  if [[ ${tool} == "diff" ]]; then
    log-info "Difference between original and new:"
    ${tool_cmd} "${original}" "${new}" | less -R -F -X || true
  elif [[ ${tool} == "colordiff" ]]; then
    log-info "Difference between original and new:"
    ${tool_cmd} "${original}" "${new}" | less -R -F -X || true
  else
    log-info "Opening diff tool: ${tool_cmd}"
    ${tool_cmd} "${original}" "${new}"
  fi
}

handleExistingFile() {
  local dest="$1" tempFile="$2"
  local choice

  log-warning "File '${dest}' already exists."

  if command -v gum >/dev/null 2>&1; then
    choice=$(gum choose --header="What would you like to do?" "Merge" "Overwrite" "Keep original")
  else
    local PS3=$'\nWhat would you like to do: '

    select choice in "Merge" "Overwrite" "Keep original"; do
      if [[ -n ${choice} ]]; then
        break
      fi
    done
  fi

  case "${choice}" in
  "Merge")
    log-info "Showing diff between files..."
    showDiff "${dest}" "${tempFile}"
    log-info "Please merge manually. Press Enter when done."
    read -r
    rm -f "${tempFile}"
    ;;
  "Overwrite")
    log-info "Overwriting ${dest}"
    mv "${tempFile}" "${dest}"
    ;;
  "Keep original")
    log-info "Keeping original ${dest}"
    rm -f "${tempFile}"
    ;;
  *)
    log-info "Keeping original ${dest}"
    rm -f "${tempFile}"
    ;;
  esac
}
