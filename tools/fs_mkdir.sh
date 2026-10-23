#!/usr/bin/env bash

set -euo pipefail

# @describe Create a new directory at the specified path.

# @option --path! The path of the directory to create

# @env LLM_OUTPUT=/dev/stdout The output path

die() {
    echo "$1" >>"$LLM_OUTPUT"
    exit 0
}

main() {
    mkdir -p "$argc_path" || die "Error: failed to create directory '$argc_path'"
    echo "Directory created: $argc_path" >>"$LLM_OUTPUT"
}

eval "$(argc --argc-eval "$0" "$@")"
