#!/usr/bin/env bash
# loop-new.sh <project>|--all
# Scaffold a project's loop: worktree + branch + ROADMAP.md + LOOP_LOG.md + LOOP_PROMPT.txt
# Idempotent: re-running never clobbers an existing ROADMAP.md.
set -euo pipefail

PB="$HOME/playbooks"
MANIFEST="$PB/loops.manifest"
PROMPT_TPL="$PB/LOOP_PROMPT.template.txt"
ROADMAP_TPL="$PB/ROADMAP.template.md"

die() { echo "ERROR: $*" >&2; exit 1; }
[ -f "$MANIFEST" ] || die "no manifest at $MANIFEST"

scaffold() {
  local name="$1" repo="$2" rule="$3" deploy="${4:-git}"
  [ -d "$repo/.git" ] || { echo "SKIP $name — not a git repo at $repo"; return; }
  local wt; wt="$(dirname "$repo")/${name}-loop"
  local branch="loop/${name}"

  if [ ! -d "$wt" ]; then
    if git -C "$repo" show-ref --verify --quiet "refs/heads/$branch"; then
      git -C "$repo" worktree add "$wt" "$branch"
    else
      git -C "$repo" worktree add "$wt" -b "$branch"
    fi
    echo "worktree  $name -> $wt ($branch)"
  else
    echo "worktree  $name already exists -> $wt"
  fi

  # ROADMAP.md — never overwrite if present
  if [ ! -f "$wt/ROADMAP.md" ]; then
    sed "s/{APP}/$name/g" "$ROADMAP_TPL" > "$wt/ROADMAP.md"
    echo "  + ROADMAP.md (blank — run /loop-roadmap $name to fill it)"
  fi
  [ -f "$wt/LOOP_LOG.md" ] || { printf '# %s loop log\n' "$name" > "$wt/LOOP_LOG.md"; }

  # LOOP_PROMPT.txt — always re-render from template (cheap, keeps rule fresh)
  sed -e "s|{{APP}}|$name|g" \
      -e "s|{{ROADMAP}}|ROADMAP.md|g" \
      -e "s|{{RULE}}|$rule|g" \
      -e "s|{{DEPLOY}}|$deploy|g" \
      "$PROMPT_TPL" > "$wt/LOOP_PROMPT.txt"
  echo "  + LOOP_PROMPT.txt"
}

run_one() {
  local target="$1" found=0
  while IFS='|' read -r name repo deploy rule; do
    [[ "$name" =~ ^#.*$ || -z "${name// }" ]] && continue
    name="${name// }"
    if [ "$target" = "--all" ] || [ "$target" = "$name" ]; then
      found=1; scaffold "$name" "$repo" "$rule" "${deploy// }"
    fi
  done < "$MANIFEST"
  [ "$target" = "--all" ] || [ "$found" = 1 ] || die "no manifest entry named '$target'"
}

[ $# -eq 1 ] || die "usage: loop-new.sh <project>|--all"
run_one "$1"
