#!/usr/bin/env bash
set -e

# @describe Execute a complete Node.js script using the node command. Use this for complex JavaScript automation that needs multiple steps, such as reading or writing many files, processing data, calling APIs, or chaining several operations. Pass the entire script content (multi-line is fine). The script MUST be written as CommonJS: use require() and module.exports, and do NOT use ES module syntax (import/export, import.meta) or top-level await; wrap async code in an async function, e.g. (async () => { ... })(). Modules are resolved from the node_modules directory of the current working directory, then from globally available modules; Node.js built-ins (fs, path, child_process, etc.) are always available. The script runs in a new node process, inherits all environment variables, and its stdout and stderr are returned together with its exit code. The user is shown the script and must confirm before it runs.

# @option --script! The full Node.js script to execute

# @env LLM_OUTPUT=/dev/stdout The output path

ROOT_DIR="${LLM_ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

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
    echo "node is not installed or not found in PATH" >>"$LLM_OUTPUT"
    return 1
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
