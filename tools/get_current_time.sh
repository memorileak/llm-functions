#!/usr/bin/env bash

set -euo pipefail

# @describe Get the current time.

# @env LLM_OUTPUT=/dev/stdout The output path

main() {
    date >>"$LLM_OUTPUT" 2>&1 || die "Error: failed to get current time"
}

eval "$(argc --argc-eval "$0" "$@")"
