#!/usr/bin/env bash

set -euo pipefail

# @env LLM_OUTPUT=/dev/stdout The output path

ROOT_DIR="${LLM_ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

die() {
    echo "$1" >>"$LLM_OUTPUT"
    exit 0
}

# @cmd Create a new file at the specified path with contents.
# @option --path! The path where the file should be created
# @option --contents! The contents of the file
fs_create() {
    if [[ -d "$argc_path" ]]; then
        die "Error: path '$argc_path' is a directory"
    fi

    local against="/dev/null"
    local action="Create"
    if [[ -f "$argc_path" ]]; then
        against="$argc_path"
        action="Overwrite existing file"
    fi

    printf "%s" "$argc_contents" | git diff --no-index "$against" - || true

    "$ROOT_DIR/utils/guard_path.sh" "$argc_path" "$action '$argc_path'?" ||
        die "User cancelled writing file '$argc_path'"

    mkdir -p "$(dirname "$argc_path")" >>"$LLM_OUTPUT" 2>&1 ||
        die "Error: failed to create directory '$(dirname "$argc_path")'"

    printf "%s" "$argc_contents" >"$argc_path" ||
        die "Error: failed to write file '$argc_path'"

    echo "File written ($action): $argc_path" >>"$LLM_OUTPUT"
}

# See more details at https://github.com/sigoden/argc
eval "$(argc --argc-eval "$0" "$@")"
