#!/usr/bin/env bash
set -e

# @describe Find code-explorer reports by keyword. Matches the project name or the task slug and returns unique "<project><TAB><task-slug>" lines.
# Reports are stored as <project>/<task-slug>.<yymmdd-HHMMSS>.md under $HOME/.local/share/llm-functions/agents/code-explorer/reports/
# @option --keyword! Keyword to search for (a slug or a single word), case-insensitive

# @env LLM_OUTPUT=/dev/stdout The output path

reports_dir="$HOME/.local/share/llm-functions/agents/code-explorer/reports"

# List .md files as paths relative to reports_dir (<project>/<file>.md)
list_reports() {
    # Preference order: fd, fdfind (Debian/Ubuntu name), find
    if command -v fd >/dev/null 2>&1; then
        (cd "$reports_dir" && fd --type f --extension md --no-ignore .)
    elif command -v fdfind >/dev/null 2>&1; then
        (cd "$reports_dir" && fdfind --type f --extension md --no-ignore .)
    else
        (cd "$reports_dir" && find . -type f -name '*.md' | sed 's|^\./||')
    fi
}

main() {
    if [[ -z "$argc_keyword" ]]; then
        echo "Error: keyword must not be empty" >&2
        exit 1
    fi
    if [[ ! -d "$reports_dir" ]]; then
        echo "Error: reports directory not found: $reports_dir" >&2
        exit 1
    fi
    # 1. list report paths
    # 2. keep only <project>/<task-slug>.<timestamp>.md paths and turn them into <project>\t<task-slug>
    # 3. keep rows matching the keyword (fixed string, case-insensitive)
    # 4. deduplicate
    list_reports |
        sed -n 's|^\([^/]*\)/\(.*\)\.[0-9]\{6\}-[0-9]\{6\}\.md$|\1\t\2|p' |
        { grep -iF -- "$argc_keyword" || true; } |
        sort -u >>"$LLM_OUTPUT"
}

eval "$(argc --argc-eval "$0" "$@")"
