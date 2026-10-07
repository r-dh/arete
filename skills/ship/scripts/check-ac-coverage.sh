#!/usr/bin/env bash
# Asymmetric AC coverage: every AC in the Spec must be named in the
# `**Satisfies:**` line of at least one Plan task that has a non-empty `**Verify:**`.
# Usage: check-ac-coverage.sh <spec.md> <plan.md>
set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <spec.md> <plan.md>" >&2
    exit 2
fi
spec="$1"
plan="$2"

# ACs under a `## Deferred` heading are out of scope for this Plan.
acs=$(awk '/^## Deferred/ { exit } { print }' "$spec" | { grep -oE '^\*\*AC-[0-9]+' || true; } | sed 's/^\*\*//' | sort -u -t- -k2n)
if [[ -z "$acs" ]]; then
    echo "FAIL: no '**AC-N' entries found in $spec" >&2
    exit 1
fi

# One line per task: "<task number> <AC IDs...>", only for tasks with a non-empty Verify.
covered=$(awk '
    function flush() { if (task != "" && verify && sat != "") print task, sat }
    /^### Task [0-9]+:/ { flush(); task = $3; sub(":", "", task); sat = ""; verify = 0; next }
    /^\*\*Satisfies:\*\*/ { line = $0; while (match(line, /AC-[0-9]+/)) { sat = sat " " substr(line, RSTART, RLENGTH); line = substr(line, RSTART + RLENGTH) } }
    /^\*\*Verify:\*\*[[:space:]]*[^[:space:]]/ { verify = 1 }
    END { flush() }
' "$plan")

missing=0
for ac in $acs; do
    tasks=$(echo "$covered" | awk -v ac="$ac" '{ for (i = 2; i <= NF; i++) if ($i == ac) { print "Task " $1; break } }' | paste -sd, -)
    if [[ -n "$tasks" ]]; then
        echo "OK    $ac <- $tasks"
    else
        echo "MISS  $ac has no Plan task with Satisfies: $ac and a Verify line"
        missing=1
    fi
done
exit $missing
