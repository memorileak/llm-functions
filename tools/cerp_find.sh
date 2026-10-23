#!/usr/bin/env bash

set -euo pipefail

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

die() {
    echo "$1" >>"$LLM_OUTPUT"
    exit 0
}

main() {
    if [[ -z "$argc_keyword" ]]; then
        die "Error: keyword must not be empty"
    fi
    if [[ ! -d "$reports_dir" ]]; then
        die "Error: reports directory not found: $reports_dir"
    fi
    # 1. list report paths
    # 2. keep only <project>/<task-slug>.<timestamp>.md paths and turn them into <project>\t<task-slug>
    # 3. keep rows matching the keyword (fixed string, case-insensitive)
    # 4. deduplicate
    list_reports |
        sed -n 's|^\([^/]*\)/\(.*\)\.[0-9]\{6\}-[0-9]\{6\}\.md$|\1\t\2|p' |
        { grep -iF -- "$argc_keyword" || true; } |
        sort -u >>"$LLM_OUTPUT" 2>&1 || die "Error: failed to search reports for keyword '$argc_keyword'"
}

eval "$(argc --argc-eval "$0" "$@")"
