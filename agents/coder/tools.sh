#!/usr/bin/env bash

set -euo pipefail

# @env LLM_OUTPUT=/dev/stdout The output path

ROOT_DIR="${LLM_ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
plans_dir="$HOME/.local/share/llm-functions/agents/coder/plans"

die() {
    echo "$1" >>"$LLM_OUTPUT"
    exit 0
}

# Keep only letters, digits, '.', '-', '_'; trim leading/trailing '-' and '.'
slugify() {
    printf "%s" "$1" | tr -c 'A-Za-z0-9._-' '-' | sed -e 's/^[-.]*//' -e 's/-*$//'
}

# Print the path of a new plan file for dir/slug, using the current timestamp.
new_plan_file() {
    local dir="$1" slug="$2" ts
    ts="$(date +%y%m%d-%H%M%S)"
    printf "%s/%s.%s.md" "$dir" "$slug" "$ts"
}

# Print the path of the latest plan for dir/slug, or nothing if none exists.
latest_plan_file() {
    local dir="$1" slug="$2" f latest=""
    shopt -s nullglob
    # Glob results are sorted alphabetically; the timestamp makes that chronological.
    for f in "$dir/$slug".[0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9][0-9][0-9].md; do
        latest="$f"
    done
    printf "%s" "$latest"
}

# Write plan contents to file_path, creating its directory. Refuses to overwrite.
write_plan_file() {
    local file_path="${1?write_plan_file: file_path is required}"
    local contents="${2?write_plan_file: contents is required}"
    local dir

    dir="$(dirname "$file_path")"
    mkdir -p "$dir" || die "Error: failed to create directory '$dir'"
    if [[ -e "$file_path" ]]; then
        die "Error: file already exists: $file_path"
    fi

    printf "%s" "$contents" >"$file_path" || die "Error: failed to write plan to '$file_path'"
    echo "Plan saved: $file_path" >>"$LLM_OUTPUT"
}

# List .md files as paths relative to plans_dir (<project>/<file>.md)
list_plans() {
    # Preference order: fd, fdfind (Debian/Ubuntu name), find
    if command -v fd >/dev/null 2>&1; then
        (cd "$plans_dir" && fd --type f --extension md --no-ignore .)
    elif command -v fdfind >/dev/null 2>&1; then
        (cd "$plans_dir" && fdfind --type f --extension md --no-ignore .)
    else
        (cd "$plans_dir" && find . -type f -name '*.md' | sed 's|^\./||')
    fi
}

# @cmd Create a new file at the specified path with contents.
# @option --path! The path where the file should be created
# @option --contents! The contents of the file
fs_create() {
    if [[ -d "$argc_path" ]]; then
        die "Error: path '$argc_path' is a directory"
    fi

    local against="/dev/null"
    local action="Create"
    if [[ -f "$argc_path" ]]; then
        against="$argc_path"
        action="Overwrite existing file"
    fi

    printf "%s" "$argc_contents" | git diff --no-index "$against" - || true

    "$ROOT_DIR/utils/guard_path.sh" "$argc_path" "$action '$argc_path'?" ||
        die "User cancelled writing file '$argc_path'"

    mkdir -p "$(dirname "$argc_path")" >>"$LLM_OUTPUT" 2>&1 ||
        die "Error: failed to create directory '$(dirname "$argc_path")'"

    printf "%s" "$argc_contents" >"$argc_path" ||
        die "Error: failed to write file '$argc_path'"

    echo "File written ($action): $argc_path" >>"$LLM_OUTPUT"
}

# @cmd Find saved plans by keyword. Matches the project name or the task slug and returns unique "<project><TAB><task-slug>" lines.
# Plans are stored as <project>/<task-slug>.<yymmdd-HHMMSS>.md under $HOME/.local/share/llm-functions/agents/coder/plans/
# @option --keyword! Keyword to search for (a slug or a single word), case-insensitive
plan_find() {
    if [[ -z "$argc_keyword" ]]; then
        die "Error: keyword must not be empty"
    fi
    if [[ ! -d "$plans_dir" ]]; then
        die "Error: plans directory not found: $plans_dir"
    fi
    # Keep <project>/<task-slug>.<timestamp>.md paths as <project>\t<task-slug>, filter by keyword, deduplicate.
    list_plans |
        sed -n 's|^\([^/]*\)/\(.*\)\.[0-9]\{6\}-[0-9]\{6\}\.md$|\1\t\2|p' |
        { grep -iF -- "$argc_keyword" || true; } |
        sort -u >>"$LLM_OUTPUT" 2>&1 || die "Error: failed to search plans for keyword '$argc_keyword'"
}

# @cmd Get the content of the latest plan for a project and task slug.
# Plans are stored as <project>/<task-slug>.<yymmdd-HHMMSS>.md under $HOME/.local/share/llm-functions/agents/coder/plans/
# @option --project! Project name used when the plan was written
# @option --task-slug! The task slug used when the plan was written
plan_get() {
    local project slug dir latest

    project="$(slugify "$argc_project" || true)"
    if [[ -z "$project" ]]; then
        die "Error: invalid project"
    fi
    slug="$(slugify "$argc_task_slug" || true)"
    if [[ -z "$slug" ]]; then
        die "Error: invalid task-slug"
    fi

    dir="$plans_dir/$project"
    latest="$(latest_plan_file "$dir" "$slug")"
    if [[ -z "$latest" ]]; then
        die "Error: no plan found for project '$project', task-slug '$slug' in $dir"
    fi
    {
        echo "Plan file: $latest"
        echo
        cat "$latest"
    } >>"$LLM_OUTPUT" 2>&1 || die "Error: failed to read plan file '$latest'"
}

# @cmd Save a markdown plan. The file is saved as <project>/<task-slug>.<yymmdd-HHMMSS>.md
# @option --project! Project name in slug format (letters, digits, '-', '_')
# @option --task-slug! Short slug of the task (letters, digits, '-', '_')
# @option --contents! The markdown contents of the plan
plan_write() {
    local project slug dir file latest against tmp contents

    project="$(slugify "$argc_project" || true)"
    if [[ -z "$project" ]]; then
        die "Error: invalid project"
    fi

    slug="$(slugify "$argc_task_slug" || true)"
    if [[ -z "$slug" ]]; then
        die "Error: invalid task-slug"
    fi

    dir="$plans_dir/$project"
    file="$(new_plan_file "$dir" "$slug")"
    if [[ -e "$file" ]]; then
        die "Error: file already exists: $file"
    fi

    # Write the new contents to a temp file first, so they can be previewed.
    tmp="$(mktemp)"
    trap "rm -f '$tmp'" EXIT
    printf "%s" "$argc_contents" >"$tmp" || die "Error: failed to write temp file '$tmp'"

    # Preview against the latest plan if there is one, otherwise against an empty file.
    latest="$(latest_plan_file "$dir" "$slug")"
    against="/dev/null"
    if [[ -n "$latest" ]]; then
        against="$latest"
    fi

    git diff --no-index "$against" "$tmp" || true

    "$ROOT_DIR/utils/guard_operation.sh" "Save plan '$file'?" ||
        die "User cancelled saving plan '$file'"

    # The sentinel keeps trailing newlines, which $(...) would otherwise strip.
    contents="$(
        cat "$tmp"
        printf x
    )"
    contents="${contents%x}"

    write_plan_file "$file" "$contents"
}

# @cmd Patch the latest plan of a project/task and save the result as a new plan (new timestamp).
# The patch uses unified diff format; file names in the header lines are ignored. Example:
# --- a/plan.md
# +++ b/plan.md
# \@@ ... @@
#  unchanged line
# -old line
# +new line
# @option --project! Project name used when the plan was written
# @option --task-slug! The task slug used when the plan was written
# @option --contents! The patch to apply to the latest plan
plan_patch() {
    local project slug dir latest tmp patched file

    project="$(slugify "$argc_project" || true)"
    if [[ -z "$project" ]]; then
        die "Error: invalid project"
    fi
    slug="$(slugify "$argc_task_slug" || true)"
    if [[ -z "$slug" ]]; then
        die "Error: invalid task-slug"
    fi

    dir="$plans_dir/$project"
    latest="$(latest_plan_file "$dir" "$slug")"
    if [[ -z "$latest" ]]; then
        die "Error: no plan found for project '$project', task-slug '$slug' in $dir"
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

    file="$(new_plan_file "$dir" "$slug")"
    echo "Patched from: $latest" >>"$LLM_OUTPUT"
    write_plan_file "$file" "$patched"
}

# See more details at https://github.com/sigoden/argc
eval "$(argc --argc-eval "$0" "$@")"
