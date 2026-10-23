#!/usr/bin/env bash

set -euo pipefail

# @describe List all files and directories at the specified path.

# @option --path! The path of the directory to list

# @env LLM_OUTPUT=/dev/stdout The output path

die() {
    echo "$1" >>"$LLM_OUTPUT"
    exit 0
}

main() {
    ls -1 "$argc_path" >>"$LLM_OUTPUT" 2>&1 || die "Error: failed to list directory '$argc_path'"
}

eval "$(argc --argc-eval "$0" "$@")"
