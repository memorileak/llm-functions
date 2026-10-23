#!/usr/bin/env bash

set -euo pipefail

# @describe Read the contents of a file at the specified path.
# Use this when you need to examine the contents of an existing file.

# @option --path! The path of the file to read

# @env LLM_OUTPUT=/dev/stdout The output path

die() {
    echo "$1" >>"$LLM_OUTPUT"
    exit 0
}

main() {
    cat "$argc_path" >>"$LLM_OUTPUT" 2>&1 || die "Error: failed to read file '$argc_path'"
}

eval "$(argc --argc-eval "$0" "$@")"
