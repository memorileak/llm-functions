#!/usr/bin/env bash

set -euo pipefail

# @describe Apply a patch to a file at the specified path.
# This can be used to edit the file, without having to rewrite the whole file.

# @option --path! The path of the file to apply to
# @option --contents! The patch to apply to the file
#
# Here is an example of a patch block that can be applied to modify the file to request the user's name:
# --- a/hello.py
# +++ b/hello.py
# \@@ ... @@
#  def hello():
# -    print("Hello World")
# +    name = input("What is your name? ")
# +    print(f"Hello {name}")

# @env LLM_OUTPUT=/dev/stdout The output path

ROOT_DIR="${LLM_ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

die() {
    echo "$1" >>"$LLM_OUTPUT"
    exit 0
}

main() {
    if [ ! -f "$argc_path" ]; then
        die "Error: file '$argc_path' does not exist"
    fi

    tmp="$(mktemp)"

    # Make sure the temp files are cleaned up on exit, even if the script is interrupted.
    trap 'rm -f "$tmp" "$tmp.2"' EXIT

    # The patch may already end with a newline. A second one would be parsed by
    # patch.awk as a blank context line and make the last hunk fail to match
    # ("hunk N not found"). So drop one trailing newline, then add exactly one.
    awk -f "$ROOT_DIR/utils/patch.awk" "$argc_path" <(printf "%s\n" "${argc_contents%$'\n'}") \
        >"$tmp" 2>>"$LLM_OUTPUT" || die "Error: failed to apply patch to '$argc_path'"

    if [ -s "$argc_path" ] && [ -n "$(tail -c1 "$argc_path")" ]; then
        # original had no trailing newline: preserve that
        printf "%s" "$(cat "$tmp")" >"$tmp.2"
        mv "$tmp.2" "$tmp"
    fi

    git diff --no-index "$argc_path" "$tmp" || true

    "$ROOT_DIR/utils/guard_operation.sh" "Apply changes?"

    cat "$tmp" >"$argc_path" 2>>"$LLM_OUTPUT" || die "Error: failed to write patched file '$argc_path'"

    echo "The patch applied to: $argc_path" >>"$LLM_OUTPUT"
}

eval "$(argc --argc-eval "$0" "$@")"
