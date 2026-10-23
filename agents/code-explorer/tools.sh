#!/usr/bin/env bash

set -euo pipefail

# @env LLM_OUTPUT=/dev/stdout The output path

reports_dir="$HOME/.local/share/llm-functions/agents/code-explorer/reports"

die() {
    echo "$1" >>"$LLM_OUTPUT"
    exit 0
}

# Keep only letters, digits, '.', '-', '_'; trim leading/trailing '-' and '.'
slugify() {
    printf "%s" "$1" | tr -c 'A-Za-z0-9._-' '-' | sed -e 's/^[-.]*//' -e 's/-*$//'
}

# @cmd Save a markdown report. The file is saved as <project>/<task-slug>.<yymmdd-HHMMSS>.md
# @option --project! Project name in slug format (letters, digits, '-', '_')
# @option --task-slug! Short slug of the task (letters, digits, '-', '_')
# @option --contents! The markdown contents of the report
cerp_write() {
    local project slug dir ts file

    project="$(slugify "$argc_project" || true)"
    if [[ -z "$project" ]]; then
        die "Error: invalid project"
    fi

    slug="$(slugify "$argc_task_slug" || true)"
    if [[ -z "$slug" ]]; then
        die "Error: invalid task-slug"
    fi

    dir="$reports_dir/$project"
    mkdir -p "$dir" || die "Error: failed to create directory '$dir'"

    ts="$(date +%y%m%d-%H%M%S)"
    file="$dir/$slug.$ts.md"
    if [[ -e "$file" ]]; then
        die "Error: file already exists: $file"
    fi

    printf "%s" "$argc_contents" >"$file" || die "Error: failed to write report to '$file'"
    echo "Report saved: $file" >>"$LLM_OUTPUT"
}

# See more details at https://github.com/sigoden/argc
eval "$(argc --argc-eval "$0" "$@")"
