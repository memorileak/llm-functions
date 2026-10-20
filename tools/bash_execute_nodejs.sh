#!/usr/bin/env bash
set -e

# @describe Execute a complete Node.js script using the node command. Use this for complex JavaScript automation that needs multiple steps, such as reading or writing many files, processing data, calling APIs, or chaining several operations. Pass the entire script content (multi-line is fine). The script runs in a new node process, inherits all environment variables, and its stdout and stderr are returned together with its exit code. The user is shown the script and must confirm before it runs.

# @option --script! The full Node.js script to execute

# @env LLM_OUTPUT=/dev/stdout The output path

ROOT_DIR="${LLM_ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

main() {
  # Preview the script for the user, with real newlines and line numbers
  {
    echo "============ Script to execute ============"
    printf '%s\n' "$argc_script" | cat -n
    echo "==========================================="
  } >&2

  "$ROOT_DIR/utils/guard_operation.sh" "Execute this script?"

  if ! command -v node >/dev/null 2>&1; then
    echo "node is not installed or not found in PATH" >>"$LLM_OUTPUT"
    return 1
  fi

  # Write the script to a temporary .js file so node reports accurate line numbers.
  # Resolve the temp directory to an absolute path so any reported path is absolute.
  local tmp_dir script_file
  tmp_dir="$(cd "${TMPDIR:-/tmp}" && pwd)"
  script_file="$(mktemp "$tmp_dir/bash_execute_nodejs.XXXXXX.js")"
  printf '%s\n' "$argc_script" >"$script_file"

  # Run in a child node process: it inherits all exported environment variables
  local status=0
  node "$script_file" >>"$LLM_OUTPUT" 2>&1 || status=$?

  if [[ $status -eq 0 ]]; then
    # Success: remove the temporary script
    rm -f "$script_file"
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
