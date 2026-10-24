#!/usr/bin/env bash

set -euo pipefail

# @describe Collect the final (latest) version of every code-explorer report into the finals directory.
# Reports are read from $HOME/.local/share/llm-functions/agents/code-explorer/reports/<project>/<task-slug>.<yymmdd-HHMMSS>.md
# and the latest one of each task slug is copied to $HOME/.local/share/llm-functions/agents/code-explorer/finals/<project>/<task-slug>.md (overwriting existing copies).

# @env LLM_OUTPUT=/dev/stdout The output path

reports_dir="$HOME/.local/share/llm-functions/agents/code-explorer/reports"
finals_dir="$HOME/.local/share/llm-functions/agents/code-explorer/finals"

die() {
    echo "$1" >>"$LLM_OUTPUT"
    exit 0
}

main() {
    local pdir project f base slug count=0
    local -A latest

    if [[ ! -d "$reports_dir" ]]; then
        die "Error: reports directory not found: $reports_dir"
    fi

    shopt -s nullglob
    for pdir in "$reports_dir"/*/; do
        project="$(basename "$pdir")"
        latest=()
        # Glob results are sorted alphabetically; the timestamp makes that chronological,
        # so a later file of the same task slug overwrites the earlier one.
        for f in "$pdir"*.[0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9][0-9][0-9].md; do
            base="$(basename "$f")"
            slug="${base%.[0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9][0-9][0-9].md}"
            latest["$slug"]="$f"
        done
        if [[ ${#latest[@]} -eq 0 ]]; then
            continue
        fi
        mkdir -p "$finals_dir/$project" >>"$LLM_OUTPUT" 2>&1 ||
            die "Error: failed to create directory '$finals_dir/$project'"
        for slug in "${!latest[@]}"; do
            cp -f "${latest[$slug]}" "$finals_dir/$project/$slug.md" >>"$LLM_OUTPUT" 2>&1 ||
                die "Error: failed to copy '${latest[$slug]}' to '$finals_dir/$project/$slug.md'"
            count=$((count + 1))
        done
    done

    echo "Collected $count final report(s) to '$finals_dir'" >>"$LLM_OUTPUT"
}

eval "$(argc --argc-eval "$0" "$@")"
