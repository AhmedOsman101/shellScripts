#!/usr/bin/env bash

source "$(include 'lib/helpers.sh')"

# ---  Main script logic --- #
# Common compiler helpers for cppc and clangc
# - safe array passing via namerefs
# - cache key includes compiler version
# - optional NO_CACHE to disable caching
# - writes stderr of failed builds to cache dir (stderr.log)

# generate_cache_key <cmd_array_name> <files_array_name>
# Uses namerefs so caller passes an array name (not a joined string).
generate_cache_key() {
  local -n _gen_key_cmd="$1"
  local -n _gen_key_files="$2"

  # include compiler version (if possible) to avoid stale cache when compiler changes
  local compiler_ver=""
  if [[ -n "${_gen_key_cmd[0]:-}" ]] && command -v "${_gen_key_cmd[0]}" >/dev/null 2>&1; then
    compiler_ver="$("${_gen_key_cmd[0]}" --version 2>/dev/null | head -n1 || true)"
  fi

  # Build a binary-safe stream for hashing. Use NULL separators to avoid ambiguity.
  # Format:
  #   <compiler-version>\0
  #   <cmd arg 0>\0<cmd arg 1>\0...\0
  #   for each file: <filename>\0<file-contents>\0
  {
    printf '%s\0' "${compiler_ver}"
    for arg in "${_gen_key_cmd[@]}"; do
      printf '%s\0' "${arg}"
    done

    for f in "${_gen_key_files[@]}"; do
      printf '%s\0' "${f}"
      if [[ -r "${f}" && -f "${f}" ]]; then
        # stream the file raw
        cat -- "${f}"
        printf '\0'
      else
        printf '\0'
      fi
    done
  } | hasher | awk '{print $1}'
}

# get_cache <cache_name_prefix> <cmd_array_name> <files_array_name>
# returns path to cached binary (stdout)
get_cache() {
  local cache_prefix="$1"
  shift
  local -n _cache_cmd="$1"
  shift
  local -n _cache_files="$1"
  shift

  # compute id
  local buildID
  buildID="$(generate_cache_key _cache_cmd _cache_files)"

  local cacheDir="/tmp/${cache_prefix}/builds/${buildID}"
  mkdir -p -- "${cacheDir}"
  printf '%s\n' "${cacheDir}/output"
}

# compile_and_run <compiler> <default_flags_array_name> <files_array_name> <compile_flag> <quiet_flag> <output> <compiler_args_array_name>
# Example call:
#   declare -a dflags=( -std=c++23 -Wall )
#   declare -a files=( main.cpp foo.cpp )
#   declare -a extras=( -O2 )
#   compile_and_run "g++" dflags files true false "a.out" extras
compile_and_run() {
  local compiler="$1"
  shift
  local -n _default_flags="$1"
  shift
  local -n _files="$1"
  shift

  local compile_flag="$1"
  shift
  local quiet_flag="$1"
  shift
  local output="$1"
  shift

  local -n _compiler_args="$1"
  shift || true

  # validate files
  if ((${#files[@]} == 0)); then
    log-error "No input files provided."
  fi

  local filename="${files[0]%.*}"
  local outfile="${output}"

  # If NO_CACHE is set or empty cache prefix, skip caching
  if [[ -n "${NO_CACHE:-}" ]]; then
    local cached_output=""
  else
    local cache_prefix
    # sanitize compiler name for path (use basename)
    cache_prefix="$(basename "${compiler}")"
    local cached_output
    cached_output="$(get_cache "${cache_prefix}" cmdArray files)"
  fi

  # If we're in compile-only mode, compile into outfile, else into cached_output
  if [[ -n "${cached_output:-}" ]]; then
    if "${compile_flag}"; then
      outfile="${outfile:-${filename}.out}"
    else
      outfile="${cached_output}"
    fi
  fi

  # Build the full command array safely
  local -a cmdArray=()
  cmdArray+=("${compiler}")

  if ((${#_default_flags[@]})); then
    cmdArray+=("${_default_flags[@]}")
  fi

  cmdArray+=("${_files[@]}")
  cmdArray+=(-o "${outfile}" -lm)

  if ((${#compiler_args[@]})); then
    cmdArray+=("${compiler_args[@]}")
  fi

  # If cache exists and we're in compile-only mode, copy and exit; if run mode, execute cached file
  if [[ -n "${cached_output:-}" && -f "${cached_output}" ]]; then
    if "${compile_flag}"; then
      [[ "${cached_output}" != "${outfile}" ]] && cp -f -- "${cached_output}" "${outfile}"
      log-success "Using cached binary: ${outfile}"
      return 0
    else
      ${outfile}
      exit $?
    fi
  fi

  # Run compiler
  local compile_exit=0
  local stderr_log=""
  if [[ -n "${cached_output:-}" ]]; then
    stderr_log="$(dirname "${cached_output}")/stderr.log"
  fi

  if "${quiet_flag}"; then
    if [[ -n "${stderr_log}" ]]; then
      "${cmdArray[@]}" >/dev/null 2>"${stderr_log}" || compile_exit=$?
    else
      "${cmdArray[@]}" &>/dev/null || compile_exit=$?
    fi
  else
    if [[ -n "${stderr_log}" ]]; then
      "${cmdArray[@]}" 2>"${stderr_log}" || compile_exit=$?
    else
      "${cmdArray[@]}" || compile_exit=$?
    fi
  fi

  if ((compile_exit)); then
    # If there is a stderr log, show it for debugging
    if [[ -n "${stderr_log}" && -s "${stderr_log}" ]]; then
      log-error --safe "Compilation failed. Compiler output:"
      less -FRX "${stderr_log}"
      exit "${compile_exit}"
    fi
    log-error "Compilation failed."
  fi

  # If binary created, install to cache (if enabled) and either return or exec it
  if [[ -f "${outfile}" ]]; then
    if [[ -n "${cached_output:-}" ]]; then
      [[ "${cached_output}" != "${outfile}" ]] && cp -f -- "${outfile}" "${cached_output}"
    fi

    if "${compile_flag}"; then
      log-success "Compilation succeeded!"
      return 0
    else
      ${outfile}
      exit $?
    fi
  else
    log-error "Compilation finished but expected output '${outfile}' not found."
  fi
}
