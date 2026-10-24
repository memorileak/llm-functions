#!/usr/bin/env bash

set -euo pipefail

# @describe Run `jq`, a command-line JSON processor. Pass all jq arguments as a string via --args, e.g. a filter followed by input file path(s), or flags like -r, -c, -e. Input is read from files only; stdin is not available to this tool.
# @option --args A string contains arguments passed to jq as-is (filter, flags and input file paths)

# @env LLM_OUTPUT=/dev/stdout The output path

ROOT_DIR="${LLM_ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

die() {
    echo "$1" >>"$LLM_OUTPUT"
    exit 0
}

main() {
    if ! command -v python3 >/dev/null 2>&1; then
        die "error: python3 is not installed"
    fi

    if ! command -v jq >/dev/null 2>&1; then
        die "error: jq is not installed"
    fi

    mapfile -d '' -t args < <(python3 "$ROOT_DIR/utils/parse_shargs.py" -- "${argc_args:-}")
    wait "$!" || die "error: invalid --args"

    if [[ ${#args[@]} -eq 0 ]]; then
        die "error: jq requires at least one argument (a filter, e.g. '.')"
    fi

    # Close stdin so jq never blocks waiting for input when no file is given.
    jq "${args[@]}" </dev/null >>"$LLM_OUTPUT" 2>&1 || die "error: jq failed with exit code $?"
}

eval "$(argc --argc-eval "$0" "$@")"
