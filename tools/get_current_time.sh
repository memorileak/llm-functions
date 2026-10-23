#!/usr/bin/env bash

set -euo pipefail

# @describe Get the current time.

# @env LLM_OUTPUT=/dev/stdout The output path

die() {
    echo "$1" >>"$LLM_OUTPUT"
    exit 0
}

main() {
    date >>"$LLM_OUTPUT" 2>&1 || die "Error: failed to get current time"
}

eval "$(argc --argc-eval "$0" "$@")"
