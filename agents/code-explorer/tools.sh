#!/usr/bin/env bash
set -e

# @env LLM_OUTPUT=/dev/stdout The output path

# @cmd Save a markdown report. The file name is auto-computed as <task-slug>.<yymmdd-HHMMSS>.md
# @option --task-slug! Short slug of the task (letters, digits, '-', '_')
# @option --contents! The markdown contents of the report
fs_write_report() {
    local slug reports_dir ts file
    slug="$(printf "%s" "$argc_task_slug" | tr -c 'A-Za-z0-9._-' '-' | sed -e 's/^[-.]*//' -e 's/-*$//')"
    if [[ -z "$slug" ]]; then
        echo "Error: invalid task-slug" >&2
        exit 1
    fi
    reports_dir="$HOME/.local/share/llm-functions/agents/code-explorer/reports"
    mkdir -p "$reports_dir"
    ts="$(date +%y%m%d-%H%M%S)"
    file="$reports_dir/$slug.$ts.md"
    if [[ -e "$file" ]]; then
        echo "Error: file already exists: $file" >&2
        exit 1
    fi
    printf "%s" "$argc_contents" > "$file"
    echo "Report saved: $file" >> "$LLM_OUTPUT"
}

# See more details at https://github.com/sigoden/argc
eval "$(argc --argc-eval "$0" "$@")"
