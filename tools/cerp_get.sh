#!/usr/bin/env bash

set -euo pipefail

# @describe Get the content of the latest code-explorer report for a project and task slug.
# Reports are stored as <project>/<task-slug>.<yymmdd-HHMMSS>.md under $HOME/.local/share/llm-functions/agents/code-explorer/reports/
# @option --project! Project name used when the report was written
# @option --task-slug! The task slug used when the report was written

# @env LLM_OUTPUT=/dev/stdout The output path

reports_dir="$HOME/.local/share/llm-functions/agents/code-explorer/reports"

# Same sanitization as slugify in agents/code-explorer/tools.sh
slugify() {
    printf "%s" "$1" | tr -c 'A-Za-z0-9._-' '-' | sed -e 's/^[-.]*//' -e 's/-*$//'
}

die() {
    echo "$1" >>"$LLM_OUTPUT"
    exit 0
}

main() {
    local project slug dir latest f
    project="$(slugify "$argc_project")"
    if [[ -z "$project" ]]; then
        die "Error: invalid project"
    fi
    slug="$(slugify "$argc_task_slug")"
    if [[ -z "$slug" ]]; then
        die "Error: invalid task-slug"
    fi
    dir="$reports_dir/$project"
    latest=""
    shopt -s nullglob
    # Glob results are sorted alphabetically; the timestamp makes that chronological.
    for f in "$dir/$slug".[0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9][0-9][0-9].md; do
        latest="$f"
    done
    if [[ -z "$latest" ]]; then
        die "Error: no report found for project '$project', task-slug '$slug' in $dir"
    fi
    {
        echo "Report file: $latest"
        echo
        cat "$latest"
    } >>"$LLM_OUTPUT" 2>&1 || die "Error: failed to read report file '$latest'"
}

eval "$(argc --argc-eval "$0" "$@")"
