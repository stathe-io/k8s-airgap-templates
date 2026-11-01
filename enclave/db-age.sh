#!/bin/sh
# Prints the age of the bundled vulnerability database and fails when it is
# older than the maximum. Inside an enclave the scanner knows only what was
# true at the last transfer, so an old database is refused rather than trusted.
#
# GATE_NOW (seconds since the epoch) overrides the clock, so verify.sh can show
# the refusal without waiting a week.
set -eu
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/../versions.env"
meta="$here/../bundle/trivy-cache/db/metadata.json"
updated=$(sed -E 's/.*"UpdatedAt":"([0-9T:-]+)[^"]*".*/\1/' "$meta")

# GNU date on Linux; the BSD form where that is not available.
epoch() { date -u -d "$1" +%s 2>/dev/null || date -j -u -f "%Y-%m-%dT%H:%M:%S" "$1" +%s; }

now=${GATE_NOW:-$(date -u +%s)}
age=$(( (now - $(epoch "$updated")) / 3600 ))
echo "vulnerability database updated $updated UTC, ${age}h old, maximum ${TRIVY_DB_MAX_AGE_HOURS}h"
[ "$age" -le "$TRIVY_DB_MAX_AGE_HOURS" ]
