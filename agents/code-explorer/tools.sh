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

# Print the path of a new report file for dir/slug, using the current timestamp.
new_report_file() {
    local dir="$1" slug="$2" ts
    ts="$(date +%y%m%d-%H%M%S)"
    printf "%s/%s.%s.md" "$dir" "$slug" "$ts"
}

# Print the path of the latest report for dir/slug, or nothing if none exists.
latest_report_file() {
    local dir="$1" slug="$2" f latest=""
    shopt -s nullglob
    # Glob results are sorted alphabetically; the timestamp makes that chronological.
    for f in "$dir/$slug".[0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9][0-9][0-9].md; do
        latest="$f"
    done
    printf "%s" "$latest"
}

# Write report contents to file_path, creating its directory. Refuses to overwrite.
write_report_file() {
    local file_path="${1?write_report_file: file_path is required}"
    local contents="${2?write_report_file: contents is required}"
    local dir

    dir="$(dirname "$file_path")"
    mkdir -p "$dir" || die "Error: failed to create directory '$dir'"
    if [[ -e "$file_path" ]]; then
        die "Error: file already exists: $file_path"
    fi

    printf "%s" "$contents" >"$file_path" || die "Error: failed to write report to '$file_path'"
    echo "Report saved: $file_path" >>"$LLM_OUTPUT"
}

# @cmd Save a markdown report. The file is saved as <project>/<task-slug>.<yymmdd-HHMMSS>.md
# @option --project! Project name in slug format (letters, digits, '-', '_')
# @option --task-slug! Short slug of the task (letters, digits, '-', '_')
# @option --contents! The markdown contents of the report
cerp_write() {
    local project slug dir file latest against tmp contents

    project="$(slugify "$argc_project" || true)"
    if [[ -z "$project" ]]; then
        die "Error: invalid project"
    fi

    slug="$(slugify "$argc_task_slug" || true)"
    if [[ -z "$slug" ]]; then
        die "Error: invalid task-slug"
    fi

    dir="$reports_dir/$project"
    file="$(new_report_file "$dir" "$slug")"
    if [[ -e "$file" ]]; then
        die "Error: file already exists: $file"
    fi

    # Write the new contents to a temp file first, so they can be previewed.
    tmp="$(mktemp)"
    trap "rm -f '$tmp'" EXIT
    printf "%s" "$argc_contents" >"$tmp" || die "Error: failed to write temp file '$tmp'"

    # Preview against the latest report if there is one, otherwise against an empty file.
    latest="$(latest_report_file "$dir" "$slug")"
    against="/dev/null"
    if [[ -n "$latest" ]]; then
        against="$latest"
    fi

    git diff --no-index "$against" "$tmp" || true

    "$ROOT_DIR/utils/guard_operation.sh" "Save report '$file'?" ||
        die "User cancelled saving report '$file'"

    # The sentinel keeps trailing newlines, which $(...) would otherwise strip.
    contents="$(
        cat "$tmp"
        printf x
    )"
    contents="${contents%x}"

    write_report_file "$file" "$contents"
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
    local project slug dir latest f tmp patched file

    project="$(slugify "$argc_project" || true)"
    if [[ -z "$project" ]]; then
        die "Error: invalid project"
    fi
    slug="$(slugify "$argc_task_slug" || true)"
    if [[ -z "$slug" ]]; then
        die "Error: invalid task-slug"
    fi

    dir="$reports_dir/$project"
    latest="$(latest_report_file "$dir" "$slug")"
    if [[ -z "$latest" ]]; then
        die "Error: no report found for project '$project', task-slug '$slug' in $dir"
    fi

    tmp="$(mktemp)"
    trap "rm -f '$tmp'" EXIT

    # Drop one trailing newline from the patch, then add exactly one (see tools/fs_patch.sh).
    awk -f "$ROOT_DIR/utils/patch.awk" "$latest" <(printf "%s\n" "${argc_contents%$'\n'}") \
        >"$tmp" 2>>"$LLM_OUTPUT" || die "Error: failed to apply patch to '$latest'"

    git diff --no-index "$latest" "$tmp" || true

    "$ROOT_DIR/utils/guard_operation.sh" "Apply changes?" ||
        die "User cancelled applying patch to '$latest'"

    # The sentinel keeps trailing newlines, which $(...) would otherwise strip.
    patched="$(
        cat "$tmp"
        printf x
    )"
    patched="${patched%x}"

    file="$(new_report_file "$dir" "$slug")"
    echo "Patched from: $latest" >>"$LLM_OUTPUT"
    write_report_file "$file" "$patched"
}

# See more details at https://github.com/sigoden/argc
eval "$(argc --argc-eval "$0" "$@")"
