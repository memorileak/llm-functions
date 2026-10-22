#!/usr/bin/env bash
set -e

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

main() {
    local project slug dir latest f
    project="$(slugify "$argc_project")"
    if [[ -z "$project" ]]; then
        echo "Error: invalid project" >&2
        exit 1
    fi
    slug="$(slugify "$argc_task_slug")"
    if [[ -z "$slug" ]]; then
        echo "Error: invalid task-slug" >&2
        exit 1
    fi
    dir="$reports_dir/$project"
    latest=""
    shopt -s nullglob
    # Glob results are sorted alphabetically; the timestamp makes that chronological.
    for f in "$dir/$slug".[0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9][0-9][0-9].md; do
        latest="$f"
    done
    if [[ -z "$latest" ]]; then
        echo "Error: no report found for project '$project', task-slug '$slug' in $dir" >&2
        exit 1
    fi
    {
        echo "Report file: $latest"
        echo
        cat "$latest"
    } >>"$LLM_OUTPUT"
}

eval "$(argc --argc-eval "$0" "$@")"
