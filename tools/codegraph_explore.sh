#!/usr/bin/env bash
set -e

# @describe Explore a codebase using a pre-built `codegraph` index (code intelligence / knowledge graph).
# The project directory MUST already be indexed with `codegraph init`/`codegraph index`.
#
# Commands (pass one as --command, with its arguments in --args):
#   status    Show index status and statistics (files, symbols, languages). Use first to check the index is ready. No args.
#   query     Search symbols (functions, classes, ...) by name. Args: <search>. Returns matching symbols with file locations.
#   explore   Explore an area in one shot: relevant symbols' source code plus call paths. Args: <query...> (natural-language or keywords). Best starting point for understanding a feature.
#   context   Build task context: relevant symbols, relationships and code blocks in markdown. Args: <task...> (description of the task).
#   node      Show one symbol's source with its caller/callee trail. Args: <symbol-name>. Use to read a specific function/class.
#   files     Show the indexed project file structure as a tree with language/symbol counts. No args.
#   callers   List all functions/methods that call a symbol. Args: <symbol>.
#   callees   List all functions/methods called by a symbol. Args: <symbol>.
#   impact    Analyze what code is affected if a symbol is changed (transitive, depth 2). Args: <symbol>.
#   affected  Find test files affected by changed source files. Args: [files...] (paths relative to the project).
#
# @option --path! The path of the project directory that is already indexed with codegraph
# @option --command![status|query|explore|context|node|files|callers|callees|impact|affected] The codegraph sub-command to run
# @option --args* Positional arguments for the sub-command (e.g. the search text, symbol name, task description or file list)

main() {
    if ! command -v codegraph >/dev/null 2>&1; then
        echo "error: codegraph is not installed" >&2
        exit 1
    fi
    if [[ ! -d "$argc_path" ]]; then
        echo "error: path '$argc_path' is not a directory" >&2
        exit 1
    fi
    if [[ ! -d "$argc_path/.codegraph" ]]; then
        echo "error: '$argc_path' is not indexed; run 'codegraph init' there first" >&2
        exit 1
    fi

    local args=("${argc_args[@]}")
    local cmd="$argc_command"

    case "$cmd" in
    status | files) ;;
    query | explore | context | callers | callees | impact)
        if [[ ${#args[@]} -eq 0 ]]; then
            echo "error: '$cmd' requires at least one argument" >&2
            exit 1
        fi
        ;;
    node | affected) ;;
    *)
        echo "error: unsupported command '$cmd'" >&2
        exit 1
        ;;
    esac

    cd "$argc_path"
    # Disable colors so output is clean for the LLM. For `status`, path is positional.
    if [[ "$cmd" == "status" ]]; then
        codegraph --no-color status >>"$LLM_OUTPUT"
    elif [[ "$cmd" == "files" ]]; then
        codegraph --no-color files "${args[@]}" >>"$LLM_OUTPUT"
    else
        codegraph --no-color "$cmd" "${args[@]}" >>"$LLM_OUTPUT"
    fi
}

eval "$(argc --argc-eval "$0" "$@")"
