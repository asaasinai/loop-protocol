#!/usr/bin/env bash
# loop-status.sh — the board. Aggregates every worktree's ROADMAP.md status
# counts + last LOOP_LOG line. Read-only.
set -euo pipefail

PB="$HOME/playbooks"
MANIFEST="$PB/loops.manifest"

printf '%-14s %4s %5s %5s %5s %5s   %s\n' PROJECT todo prog done fail blkd LAST
printf '%.0s-' {1..78}; echo

while IFS='|' read -r name repo deploy rule; do
  [[ "$name" =~ ^#.*$ || -z "${name// }" ]] && continue
  name="${name// }"
  wt="$(dirname "$repo")/${name}-loop"
  rm="$wt/ROADMAP.md"
  [ -f "$rm" ] || { printf '%-14s   (no worktree)\n' "$name"; continue; }

  # status is the 4th data column: | # | Task | Goal | Status | Notes |
  # Status is the 2nd-to-last column (Notes is last). Using NF-2 instead of a
  # fixed field index survives pipes inside earlier cells (e.g. `||` in code).
  counts=$(awk -F'|' '$2 ~ /^ *[0-9]+ *$/ {s=$(NF-2); gsub(/ /,"",s); print s}' "$rm" \
    | sort | uniq -c)
  g() { echo "$counts" | awk -v k="$1" '$2==k{print $1}' | head -1; }
  todo=$(g todo); prog=$(g in_progress); done=$(g done); fail=$(g failed); blkd=$(g blocked)
  last=""; [ -f "$wt/LOOP_LOG.md" ] && last=$(tail -1 "$wt/LOOP_LOG.md" 2>/dev/null)
  printf '%-14s %4s %5s %5s %5s %5s   %s\n' \
    "$name" "${todo:-0}" "${prog:-0}" "${done:-0}" "${fail:-0}" "${blkd:-0}" "${last:0:30}"
done < "$MANIFEST"
