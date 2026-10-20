#!/usr/bin/env bash
set -e

# @describe Execute a complete bash script. Use this for complex automation that needs multiple steps, such as creating or editing many files, running conditional checks, for/while loops, pipelines, or chaining several commands together. Pass the entire script content (multi-line is fine, a shebang is optional). The script runs in a new bash process, inherits all environment variables, and its stdout and stderr are returned together with its exit code. By default the script keeps going after a failing command and its exit code is that of the last command; to make it stop at the first failure, start it with `set -euo pipefail` and guard commands that are expected to fail (e.g. grep with no match) using `|| true` or an `if` condition. If the script exits with a non-zero status, it is kept in a temporary file whose path is reported in the output. The user is shown the script and must confirm before it runs.

# @option --script! The full bash script to execute

# @env LLM_OUTPUT=/dev/stdout The output path

ROOT_DIR="${LLM_ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

main() {
  # Preview the script for the user with shell syntax highlighting
  {
    echo "============ Script to execute ============"
  } >&2
  printf '%s\n' "$argc_script" | "$ROOT_DIR/utils/preview_code.sh" bash
  {
    echo "==========================================="
  } >&2

  "$ROOT_DIR/utils/guard_operation.sh" "Execute this script?"

  # Write the script to a private temp dir (absolute path) so it can be kept on failure
  local tmp_dir script_dir script_file
  tmp_dir="$(cd "${TMPDIR:-/tmp}" && pwd)"
  script_dir="$(mktemp -d "$tmp_dir/bash_execute_script.XXXXXX")"
  script_file="$script_dir/script.sh"
  printf '%s\n' "$argc_script" >"$script_file"

  # Run in a child bash: it inherits all exported environment variables
  local status=0
  bash "$script_file" >>"$LLM_OUTPUT" 2>&1 || status=$?

  if [[ $status -eq 0 ]]; then
    rm -rf "$script_dir"
    return 0
  fi

  # Failure: keep the temporary script and tell the user where it is
  {
    echo "Script exited with non-zero status: $status"
    echo "The temporary script was kept at: $script_file"
    echo "Please take a look at this file to find the cause of the failure."
  } >>"$LLM_OUTPUT"
  return $status
}

eval "$(argc --argc-eval "$0" "$@")"
