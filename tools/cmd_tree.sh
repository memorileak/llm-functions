#!/usr/bin/env bash

set -euo pipefail

# @describe List directory contents as a tree. Pass all tree arguments via --args as a string, e.g. a directory path, -L <depth>, -I <pattern>, -a, -d.
# @option --args A string contains arguments passed to tree as-is (directory paths and flags).

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

    if ! command -v tree >/dev/null 2>&1; then
        die "error: tree is not installed"
    fi

    # `< <(cmd)` is "process substitution": bash runs cmd in the background and
    # exposes its stdout as a file-like path (/dev/fd/N). The first `<`
    # redirects it into mapfile's stdin, so no temp file is needed. ($(cmd)
    # can't be used: it drops NUL bytes.)
    # `-d ''` splits on NUL, `-t` strips the delimiter, `args` is the array.
    mapfile -d '' -t args < <(python3 "$ROOT_DIR/utils/parse_shargs.py" -- "${argc_args:-}")
    # The exit status of cmd is hidden inside `<(...)`. `$!` is the PID of the
    # last background process (the python3 above); `wait "$!"` returns its
    # status. Non-zero means the parse failed. Using `||` also keeps `set -e`
    # from aborting the script before die() runs.
    wait "$!" || die "error: invalid --args"

    tree "${args[@]}" >>"$LLM_OUTPUT" 2>&1 || die "error: tree failed with exit code $?"
}

eval "$(argc --argc-eval "$0" "$@")"
