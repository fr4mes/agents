#!/usr/bin/env bash
# Prints every (path, line, side) triple the GitHub review API accepts as a
# comment anchor for a PR, one per line as "path<TAB>line<TAB>side".
# Anchors outside this set are rejected with 422.
set -euo pipefail

if [ "$#" -gt 1 ]; then
  echo "usage: anchors.sh [<pr-number|url|branch>]" >&2
  exit 2
fi

gh pr diff ${1:+"$1"} | awk '
  # Header lines are only headers outside a hunk. Inside one, a removed
  # "-- sql comment" reads as "--- sql comment" and must stay content.
  function in_hunk() { return oldleft > 0 || newleft > 0 }

  !in_hunk() && /^--- / {
    oldpath = ($0 == "--- /dev/null") ? "" : substr($0, 7)
    next
  }
  !in_hunk() && /^\+\+\+ / {
    newpath = ($0 == "+++ /dev/null") ? "" : substr($0, 7)
    path = (newpath != "") ? newpath : oldpath
    next
  }
  !in_hunk() && /^@@ / {
    if ($0 !~ /^@@ -[0-9]+(,[0-9]+)? \+[0-9]+(,[0-9]+)? @@/) next
    split(substr($2, 2), o, ",")
    split(substr($3, 2), n, ",")
    old = o[1]; oldleft = (2 in o) ? o[2] : 1
    new = n[1]; newleft = (2 in n) ? n[2] : 1
    next
  }

  !in_hunk() || path == "" { next }

  /^\\/ { next }                                                    # \ No newline at end of file
  /^\+/ { print path "\t" new "\tRIGHT"; new++; newleft--; next }
  /^-/  { print path "\t" old "\tLEFT";  old++; oldleft--; next }
  /^ /  { print path "\t" new "\tRIGHT"; old++; new++; oldleft--; newleft--; next }
'
