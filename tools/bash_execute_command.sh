#!/usr/bin/env bash

set -euo pipefail

# @describe Execute a short single-line bash command (e.g. `ls -la`, `git status`, `grep -rn foo src/`) for quick one-off tasks; for multi-line logic, loops or many edits use bash_execute_script. **ALWAYS** append a trailing `# comment` explaining the intention of the command. Inherits all environment variables and returns stdout and stderr. The user must confirm before it runs.

# @option --command! The single-line bash command to execute

# @env LLM_OUTPUT=/dev/stdout The output path

ROOT_DIR="${LLM_ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

die() {
    echo "$1" >>"$LLM_OUTPUT"
    exit 0
}

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
        die "Error: command exited with non-zero status: $status"
    fi
}

eval "$(argc --argc-eval "$0" "$@")"
