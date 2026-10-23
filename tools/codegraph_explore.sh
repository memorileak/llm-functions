#!/usr/bin/env bash

set -euo pipefail

# @describe Explore a codebase using a pre-built `codegraph` index (code intelligence / knowledge graph). Pass sub-command arguments as a shell-like string via --args; quote multiword arguments.
# The project directory MUST already be indexed with `codegraph init`/`codegraph index`.
#
# Commands (pass one as --command, with its arguments as a shell-like string in --args):
#   status    Show index status and statistics (files, symbols, languages). Use first to check the index is ready. No args.
#   query     Search symbols (functions, classes, ...) by name. Args: <search>. Returns matching symbols with file locations.
#   explore   Explore an area in one shot: relevant symbols' source code plus call paths. Args: <query...> (natural-language or keywords). Best starting point for understanding a feature.
#   context   Build task context: relevant symbols, relationships and code blocks in markdown. Args: <task...> (description of the task).
#   node      Show one symbol's source with its caller/callee trail. Args: <symbol-name>. Use to read a specific function/class.
#   files     Show the indexed project file structure as a tree with language/symbol counts. No args.
#   callers   List all functions/methods that call a symbol. Args: <symbol>.
#   callees   List all functions/methods called by a symbol. Args: <symbol>.
#   impact    Analyze what code is affected if a symbol is changed (transitive, depth 2). Args: <symbol>.
#   affected  Find test files affected by changed source files. Args: <files...> (paths relative to the project).
#
# @option --path! The path of the project directory that is already indexed with codegraph
# @option --command![status|query|explore|context|node|files|callers|callees|impact|affected] The codegraph sub-command to run
# @option --args A shell-like string of arguments for the sub-command; quote multiword arguments.
#
# @env LLM_OUTPUT=/dev/stdout The output path

ROOT_DIR="${LLM_ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

die() {
    echo "$1" >>"$LLM_OUTPUT"
    exit 0
}

main() {
    if ! command -v python3 >/dev/null 2>&1; then
        die "error: python3 is not installed"
    fi

    if ! command -v codegraph >/dev/null 2>&1; then
        die "error: codegraph is not installed"
    fi

    mapfile -d '' -t args < <(python3 "$ROOT_DIR/utils/parse_shargs.py" -- "${argc_args:-}")
    wait "$!" || die "error: invalid --args"

    if [[ ! -d "$argc_path" ]]; then
        die "error: path '$argc_path' is not a directory"
    fi
    if [[ ! -d "$argc_path/.codegraph" ]]; then
        die "error: '$argc_path' is not indexed; run 'codegraph init' there first"
    fi

    local cmd="$argc_command"

    case "$cmd" in
    status | files) ;;
    query | explore | context | node | callers | callees | impact | affected)
        if [[ ${#args[@]} -eq 0 ]]; then
            die "error: '$cmd' requires at least one argument"
        fi
        ;;
    *)
        die "error: unsupported command '$cmd'"
        ;;
    esac

    cd "$argc_path" || die "error: unable to access path '$argc_path'"
    if [[ "$cmd" == "status" ]]; then
        codegraph --no-color status >>"$LLM_OUTPUT" 2>&1 || die "error: codegraph failed with exit code $?"
    else
        codegraph --no-color "$cmd" "${args[@]}" >>"$LLM_OUTPUT" 2>&1 || die "error: codegraph failed with exit code $?"
    fi
}

eval "$(argc --argc-eval "$0" "$@")"
