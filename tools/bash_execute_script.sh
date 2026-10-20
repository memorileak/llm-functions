#!/usr/bin/env bash
set -e

# @describe Execute a complete bash script. Use this for complex automation that needs multiple steps, such as creating or editing many files, running conditional checks, for/while loops, pipelines, or chaining several commands together. Pass the entire script content (multi-line is fine, a shebang is optional). The script runs in a new bash process, inherits all environment variables, and its stdout and stderr are returned together with its exit code. The user is shown the script and must confirm before it runs.

# @option --script! The full bash script to execute

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

  # Run in a child bash: it inherits all exported environment variables
  local status=0
  bash -c "$argc_script" >>"$LLM_OUTPUT" 2>&1 || status=$?

  if [[ $status -ne 0 ]]; then
    echo "Script exited with non-zero status: $status" >>"$LLM_OUTPUT"
    return $status
  fi
}

eval "$(argc --argc-eval "$0" "$@")"
