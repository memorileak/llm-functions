#!/usr/bin/env bash

# Print code from stdin to stderr with syntax highlighting.
# Usage: preview_code.sh <language>
# Uses batcat, then bat; falls back to a markdown code fence.

main() {
    local lang="${1:-bash}" cmd
    for cmd in batcat bat; do
        if command -v "$cmd" >/dev/null 2>&1; then
            "$cmd" --paging=never --color=always --style=plain --language="$lang" >&2
            return
        fi
    done
    {
        echo "\`\`\`$lang"
        cat
        echo '```'
    } >&2
}

main "$@"
