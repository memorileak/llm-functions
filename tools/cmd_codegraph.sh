#!/usr/bin/env bash

set -euo pipefail

# @describe Explore a codebase using a pre-built `codegraph` index (code intelligence / knowledge graph). Available sub-commands: status, query, explore, context, node, files, callers, callees, impact, affected. Pass sub-command arguments as a shell-like string via --args; quote multiword arguments. The project directory MUST already be indexed with `codegraph init`/`codegraph index`.
#
# Usage:
#   --path /project/dir  --command status                        Show index status and statistics
#   --path /project/dir  --command query     --args <search>     Search for symbols in the codebase
#   --path /project/dir  --command explore   --args <query...>   Explore an area: relevant symbols' source + call paths in one shot
#   --path /project/dir  --command context   --args <task...>    Build context for a task: relevant symbols, relationships, and code blocks
#   --path /project/dir  --command node      --args [name]       One symbol's source + caller/callee trail, or read a file with line numbers + dependents (same output as the codegraph_node MCP tool)
#   --path /project/dir  --command files                         Show project file structure from the index
#   --path /project/dir  --command callers   --args <symbol>     Find all functions/methods that call a specific symbol
#   --path /project/dir  --command callees   --args <symbol>     Find all functions/methods called by a specific symbol
#   --path /project/dir  --command impact    --args <symbol>     Analyze what code is affected by changing a symbol
#   --path /project/dir  --command affected  --args [files...]   Find test files affected by changed source files
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
