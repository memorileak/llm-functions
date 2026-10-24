#!/usr/bin/env bash

set -euo pipefail

# @describe Execute a complete bash script (shebang optional) for multi-step automation: file edits, conditionals, loops, pipelines. **ALWAYS** include comments explaining the overall logic and the intention of each statement or command. Runs in a new bash process, inherits all environment variables, and returns stdout, stderr and exit code. By default it continues after a failing command and exits with the last command's code; to stop at the first failure, start with `set -euo pipefail` and guard expected failures with `|| true` or `if`. A failed script is kept in a temp file whose path is reported. The user must confirm before it runs.

# @option --script! The full bash script to execute

# @env LLM_OUTPUT=/dev/stdout The output path

ROOT_DIR="${LLM_ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# die() {
#     echo "$1" >>"$LLM_OUTPUT"
#     exit 0
# }

main() {
    # Preview the script for the user with shell syntax highlighting
    {
        echo "============ Script to execute ============"
    } >&2
    printf '%s\n' "$argc_script" | "$ROOT_DIR/utils/preview_code.sh" bash
    {
        echo "==========================================="
    } >&2

    "$ROOT_DIR/utils/guard_operation.sh" "Execute this script?" ||
        die "User cancelled script execution"

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
        exit 0
    fi

    # Failure: keep the temporary script and tell the user where it is
    {
        echo "Script exited with non-zero status: $status"
        echo "The temporary script was kept at: $script_file"
        echo "Please take a look at this file to find the cause of the failure."
    } >>"$LLM_OUTPUT"
    exit 0
}

eval "$(argc --argc-eval "$0" "$@")"
