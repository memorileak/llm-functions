#!/usr/bin/env bash
set -e

# @describe Execute a short, simple, single-line bash command, such as `ls -la`, `git status`, `grep -rn foo src/` or `mkdir -p build`. Use it for quick one-off commands. For multi-line logic, loops, conditionals or editing many files, use bash_execute_script instead. The command inherits all environment variables, and its stdout and stderr are returned. The user is shown the command and must confirm before it runs.

# @option --command! The single-line bash command to execute

# @env LLM_OUTPUT=/dev/stdout The output path

ROOT_DIR="${LLM_ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

main() {
  # Preview the command for the user with shell syntax highlighting (stderr, not tool output)
  {
    echo "============ Command to execute ============"
  } >&2
  printf '$ %s\n' "$argc_command" | "$ROOT_DIR/utils/preview_code.sh" bash
  {
    echo "============================================"
  } >&2

  "$ROOT_DIR/utils/guard_operation.sh" "Execute this command?"

  # Run in a child bash: it inherits all exported environment variables
  local status=0
  bash -c "$argc_command" >>"$LLM_OUTPUT" 2>&1 || status=$?

  if [[ $status -ne 0 ]]; then
    echo "Command exited with non-zero status: $status" >>"$LLM_OUTPUT"
    return 0
  fi
}

eval "$(argc --argc-eval "$0" "$@")"
