#!/usr/bin/env bash
set -e

# @describe Get the content of the latest code-explorer report for a task slug.
# Reports are stored as <task-slug>.<yymmdd-HHMMSS>.md under $HOME/.local/share/llm-functions/agents/code-explorer/reports/
# @option --task-slug! The task slug used when the report was written

# @env LLM_OUTPUT=/dev/stdout The output path

main() {
    local slug reports_dir latest f
    # Same sanitization as fs_write_report in agents/code-explorer/tools.sh
    slug="$(printf "%s" "$argc_task_slug" | tr -c 'A-Za-z0-9._-' '-' | sed -e 's/^[-.]*//' -e 's/-*$//')"
    if [[ -z "$slug" ]]; then
        echo "Error: invalid task-slug" >&2
        exit 1
    fi
    reports_dir="$HOME/.local/share/llm-functions/agents/code-explorer/reports"
    latest=""
    shopt -s nullglob
    # Glob results are sorted alphabetically; the timestamp makes that chronological.
    for f in "$reports_dir/$slug".[0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9][0-9][0-9].md; do
        latest="$f"
    done
    if [[ -z "$latest" ]]; then
        echo "Error: no report found for task-slug '$slug' in $reports_dir" >&2
        exit 1
    fi
    {
        echo "Report file: $latest"
        echo
        cat "$latest"
    } >> "$LLM_OUTPUT"
}

eval "$(argc --argc-eval "$0" "$@")"
