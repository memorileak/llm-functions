#!/usr/bin/env bash

set -euo pipefail

# @describe Execute a complete Node.js script for complex JavaScript automation: many files, data processing, API calls, chained operations. **ALWAYS** include comments explaining the overall logic and the intention of each statement. Must be CommonJS (`require`, `module.exports`); no `import`/`export`, `import.meta` or top-level await; wrap async code in `(async () => { ... })()`. Modules resolve from the cwd's `node_modules`, then globals; Node.js built-ins are available. Runs in a new node process, inherits all environment variables, and returns stdout, stderr and exit code. A failed script is kept in a temp file whose path is reported. The user must confirm before it runs.

# @option --script! The full Node.js script to execute

# @env LLM_OUTPUT=/dev/stdout The output path

ROOT_DIR="${LLM_ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

die() {
    echo "$1" >>"$LLM_OUTPUT"
    exit 0
}

main() {
    # Preview the script for the user with JavaScript syntax highlighting
    {
        echo "============ Script to execute ============"
    } >&2
    printf '%s\n' "$argc_script" | "$ROOT_DIR/utils/preview_code.sh" javascript
    {
        echo "==========================================="
    } >&2

    "$ROOT_DIR/utils/guard_operation.sh" "Execute this script?"

    if ! command -v node >/dev/null 2>&1; then
        die "node is not installed or not found in PATH"
    fi

    # Write the script to a private temp dir as script.js (CommonJS) so node reports accurate
    # line numbers. A directory is used because mktemp templates with a suffix are not portable.
    # The path is made absolute so any reported path is absolute.
    local tmp_dir script_dir script_file
    tmp_dir="$(cd "${TMPDIR:-/tmp}" && pwd)"
    script_dir="$(mktemp -d "$tmp_dir/bash_execute_nodejs.XXXXXX")"
    script_file="$script_dir/script.js"
    printf '%s\n' "$argc_script" >"$script_file"

    # Run in a child node process: it inherits all exported environment variables.
    # The script lives in the temp dir, so point module resolution at the cwd's node_modules.
    local status=0
    NODE_PATH="$PWD/node_modules${NODE_PATH:+:$NODE_PATH}" node "$script_file" >>"$LLM_OUTPUT" 2>&1 || status=$?

    if [[ $status -eq 0 ]]; then
        # Success: remove the temporary script
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
