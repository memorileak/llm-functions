#!/usr/bin/env python3
r"""Parse a raw argument string into a list of arguments with shell word rules.

Tools that accept their arguments as one string (e.g. `--args "-L 2 'my dir'"`)
can use this instead of xargs or eval. Parsing is done by shlex in POSIX mode:
quotes and backslash escapes are honored, but no variable, command, tilde or
glob expansion is performed, and `#` does not start a comment. Inside double
quotes, shlex only unescapes `\"` and `\\`; other backslashes stay literal
(so `"\$x"` yields `\$x`, unlike sh). Also unlike sh, `$'..'` is not
supported and `;|&<>` are ordinary word characters.

Exit codes: 0 ok, 2 usage error (argparse), 3 invalid argument string.

Shell usage (tokens are NUL-separated so spaces and newlines survive):

    # `< <(cmd)` is "process substitution": bash runs cmd in the background and
    # exposes its stdout as a file-like path (/dev/fd/N). The first `<`
    # redirects it into mapfile's stdin, so no temp file is needed. ($(cmd)
    # can't be used: it drops NUL bytes.)
    # `-d ''` splits on NUL, `-t` strips the delimiter, `args` is the array.
    mapfile -d '' -t args < <(python3 "$ROOT_DIR/utils/parse_shargs.py" -- "$argc_args")
    # The exit status of cmd is hidden inside `<(...)`. `$!` is the PID of the
    # last background process (the python3 above); `wait "$!"` returns its
    # status. Non-zero means the parse failed. (Needs bash >= 4.4.)
    wait "$!" || { echo "error: invalid --args" >&2; exit 1; }

Python usage (requires Python 3.7+):

    import os, sys
    sys.path.insert(0, os.path.join(root_dir, "utils"))
    from parse_shargs import parse_shargs
    args = parse_shargs(raw)
"""

from __future__ import annotations

import argparse
import shlex
import sys


def parse_shargs(string: str) -> list[str]:
    """Split a shell-like argument string into a list of arguments.

    Raises ValueError on an unclosed quote or a trailing backslash.
    """
    if not isinstance(string, str):
        # shlex.split(None) would read stdin
        raise ValueError("argument string must be a str")
    return shlex.split(string, comments=False, posix=True)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Parse a raw argument string and print one argument per NUL-terminated record."
    )
    parser.add_argument("string", help="raw argument string, e.g. \"-L 2 -I 'my dir'\"")
    args = parser.parse_args(argv)

    try:
        tokens = parse_shargs(args.string)
    except ValueError as err:
        print(f"error: invalid argument string: {err}", file=sys.stderr)
        return 3

    # Write raw bytes. argv was decoded with surrogateescape, so encode the same way.
    out = sys.stdout.buffer
    for token in tokens:
        out.write(token.encode("utf-8", "surrogateescape") + b"\0")
    out.flush()
    return 0


if __name__ == "__main__":
    sys.exit(main())
