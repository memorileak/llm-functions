#!/usr/bin/env bash

set -euo pipefail

# @env LLM_OUTPUT=/dev/stdout The output path

ROOT_DIR="${LLM_ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
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

# @cmd Patch the latest report of a project/task and save the result as a new report (new timestamp).
# The patch uses unified diff format; file names in the header lines are ignored. Example:
# --- a/report.md
# +++ b/report.md
# \@@ ... @@
#  unchanged line
# -old line
# +new line
# @option --project! Project name used when the report was written
# @option --task-slug! The task slug used when the report was written
# @option --contents! The patch to apply to the latest report
cerp_patch() {
    local project slug dir latest f tmp patched

    project="$(slugify "$argc_project" || true)"
    if [[ -z "$project" ]]; then
        die "Error: invalid project"
    fi
    slug="$(slugify "$argc_task_slug" || true)"
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

    tmp="$(mktemp)"
    trap "rm -f '$tmp'" EXIT

    # Drop one trailing newline from the patch, then add exactly one (see tools/fs_patch.sh).
    awk -f "$ROOT_DIR/utils/patch.awk" "$latest" <(printf "%s\n" "${argc_contents%$'\n'}") \
        >"$tmp" 2>>"$LLM_OUTPUT" || die "Error: failed to apply patch to '$latest'"

    git diff --no-index "$latest" "$tmp" || true

    "$ROOT_DIR/utils/guard_operation.sh" "Apply changes?"

    # The sentinel keeps trailing newlines, which $(...) would otherwise strip.
    patched="$(
        cat "$tmp"
        printf x
    )"
    patched="${patched%x}"

    argc_project="$project"
    argc_task_slug="$slug"
    argc_contents="$patched"
    {
        echo "Patched from: $latest"
        cerp_write
    } >>"$LLM_OUTPUT"
}

# See more details at https://github.com/sigoden/argc
eval "$(argc --argc-eval "$0" "$@")"
