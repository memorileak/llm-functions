#!/usr/bin/env bash

set -euo pipefail

# @describe Extract the content from a given URL.
# @option --url! The URL to scrape.

# @meta require-tools pandoc

# @env LLM_OUTPUT=/dev/stdout The output path

die() {
    echo "$1" >>"$LLM_OUTPUT"
    exit 0
}

main() {
    if ! command -v curl >/dev/null 2>&1; then
        die "Error: curl is not installed"
    fi

    if ! command -v pandoc >/dev/null 2>&1; then
        die "Error: pandoc is not installed"
    fi

    # span and div tags are dropped from the HTML https://pandoc.org/MANUAL.html#raw-htmltex and sed removes any inline SVG images in image tags from the Markdown content.
    curl -fsSL "$argc_url" |
        pandoc -f html-native_divs-native_spans -t gfm-raw_html --wrap=none |
        sed -E 's/!\[[^]]*\]\([^)]*\)//g' \
            >>"$LLM_OUTPUT" 2>&1 || die "Error: failed to fetch URL '$argc_url'"
}

eval "$(argc --argc-eval "$0" "$@")"
