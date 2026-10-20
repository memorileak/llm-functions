#!/usr/bin/awk -f

# Apply a diff to an original file. Line numbers in @@ headers are ignored.
# Usage: awk -f patch.awk target-file patch-file
#
# - Each hunk is located by searching the whole file (exact match first,
#   then ignoring trailing whitespace / CR). Zero or multiple matches is an error.
# - Hunks may appear in any order, but must not overlap.
# - A hunk with no original lines (pure addition) is appended to the end of the file.

BEGIN {
    # Remember the first input file so the target can be read even when it is empty.
    targetFile = ARGV[1]
}

# Remove trailing spaces, tabs, and CR only for the fallback comparison.
function norm(s) {
    sub(/[ \t\r]+$/, "", s)
    return s
}

# Return whether hunk h's original lines match at file position pos.
function matchAt(h, pos, loose,    i, a, b) {
    for (i = 1; i <= origCount[h]; i++) {
        a = lines[pos + i - 1]
        b = orig[h, i]
        if (loose) { a = norm(a); b = norm(b) }
        if (a != b) return 0
    }
    return 1
}

function fail(msg) {
    print "error: " msg > "/dev/stderr"
    failed = 1
    exit 1
}

# AWK reads the target first and the patch second. Keep the target unchanged
# in memory; all matching and output below are based on this original content.
FILENAME == targetFile {
    lines[FNR] = $0
    totalLines = FNR
    next
}

# Parse unified-diff hunk lines into parallel original/new line arrays.
# Context and removed lines form the text that must match; context and added
# lines form the replacement. Hunk header line numbers are deliberately ignored.
{
    sub(/\r$/, "", $0)
    if (!inHunk) {
        if ($0 ~ /^@@/) { inHunk = 1; hunks++ }
        next
    }
    if ($0 ~ /^@@/) { hunks++; next }
    if ($0 ~ /^\\/) next          # "\ No newline at end of file"
    c = substr($0, 1, 1)
    text = substr($0, 2)
    if ($0 == "") { c = " "; text = "" }
    if (c == " " || c == "-") {
        origCount[hunks]++
        orig[hunks, origCount[hunks]] = text
    }
    if (c == " " || c == "+") {
        newCount[hunks]++
        new[hunks, newCount[hunks]] = text
        # context lines are re-read from the original file (keeps CR etc.)
        newSrc[hunks, newCount[hunks]] = (c == " ") ? origCount[hunks] : 0
    }
}

END {
    if (failed) exit 1
    if (hunks == 0) fail("no patch (no @@ hunk found)")

    # Locate every hunk against the original file. Try exact bytes first, then
    # permit trailing whitespace/CR differences. Reject ambiguous matches rather
    # than risk applying a patch at the wrong occurrence.
    for (h = 1; h <= hunks; h++) {
        # A hunk containing only additions has no text to search for, so it is
        # assigned the position just after the original file.
        if (origCount[h] == 0) {
            start[h] = totalLines + 1
            len[h] = 0
            continue
        }
        for (pass = 0; pass <= 1; pass++) {
            found = 0
            for (p = 1; p + origCount[h] - 1 <= totalLines; p++) {
                if (matchAt(h, p, pass)) {
                    found++
                    if (found == 1) pos = p
                }
            }
            if (found > 0) break
        }
        if (found == 0) fail("hunk " h " not found; first original line: \"" orig[h, 1] "\"")
        if (found > 1) fail("hunk " h " matches " found " places; add more context lines. First line: \"" orig[h, 1] "\"")
        start[h] = pos
        len[h] = origCount[h]
    }

    # Patches need not list hunks in file order. Sort their located positions so
    # the output pass can copy and replace the file from top to bottom.
    for (h = 1; h <= hunks; h++) order[h] = h
    for (i = 2; i <= hunks; i++) {
        v = order[i]
        j = i - 1
        while (j >= 1 && start[order[j]] > start[v]) { order[j + 1] = order[j]; j-- }
        order[j + 1] = v
    }
    # Two hunks cannot safely replace any of the same original lines.
    for (i = 2; i <= hunks; i++) {
        if (start[order[i]] < start[order[i - 1]] + len[order[i - 1]])
            fail("hunks " order[i - 1] " and " order[i] " overlap")
    }

    # Rebuild the file in original-line order. At a hunk's start, emit its
    # replacement; skip the original lines consumed by that hunk. Lines outside
    # hunks pass through unchanged. The extra iteration permits additions at EOF.
    k = 1
    for (ln = 1; ln <= totalLines + 1; ln++) {
        while (k <= hunks && start[order[k]] == ln) {
            h = order[k]
            cr = (len[h] > 0 && lines[ln] ~ /\r$/) ? "\r" : ""
            for (i = 1; i <= newCount[h]; i++) {
                if (newSrc[h, i] > 0) print lines[ln + newSrc[h, i] - 1]
                else print new[h, i] cr
            }
            skipTo = ln + len[h]
            k++
            if (len[h] > 0) break
        }
        if (ln < skipTo) continue
        if (ln <= totalLines) print lines[ln]
    }
}
