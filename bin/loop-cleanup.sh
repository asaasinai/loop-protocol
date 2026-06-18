#!/usr/bin/env bash
# loop-cleanup.sh <project> — tear down a finished loop's worktree + branch.
# Warns if the branch has unmerged commits.
set -euo pipefail

PB="$HOME/playbooks"
MANIFEST="$PB/loops.manifest"
die() { echo "ERROR: $*" >&2; exit 1; }
[ $# -eq 1 ] || die "usage: loop-cleanup.sh <project>"
name="$1"

repo=$(awk -F'|' -v n="$name" '$1==n{print $2}' "$MANIFEST")
[ -n "$repo" ] || die "no manifest entry named '$name'"
wt="$(dirname "$repo")/${name}-loop"
branch="loop/${name}"

if git -C "$repo" rev-parse --verify "$branch" >/dev/null 2>&1; then
  unmerged=$(git -C "$repo" log --oneline main.."$branch" 2>/dev/null | wc -l | tr -d ' ')
  [ "$unmerged" != "0" ] && echo "WARNING: $branch has $unmerged commit(s) not on main."
fi
read -r -p "Remove worktree $wt and branch $branch? [y/N] " ans
[ "$ans" = "y" ] || { echo "aborted"; exit 0; }

git -C "$repo" worktree remove "$wt" --force
git -C "$repo" branch -D "$branch" 2>/dev/null || true
echo "removed $name"
