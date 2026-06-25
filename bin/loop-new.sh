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
  [ -f "$wt/LOOP_LOG.md" ] || { printf '# %s loop log\n\n## Outcome ledger\n<!-- one line per shipped row: timestamp | row# | outcome | sha | deploy | ~tokens -->\n\n## Attempts & lessons\n<!-- append-only. on any retry/fail/blocked row, log 3 lines:\n     Tried: <approach>  Result: <what happened>  Lesson: <cause + symptom to watch for>.\n     PLAN reads this first every cycle — never re-try an approach already recorded failed. -->\n' "$name" > "$wt/LOOP_LOG.md"; }

  # specs/ — the spec engine writes specs/<name>-spec.md here. Create the dir but
  # never fabricate a spec; the loop's SPEC CHECK decides spec vs roadmap-only.
  mkdir -p "$wt/specs"
  if ls "$wt"/specs/*.md >/dev/null 2>&1; then
    echo "  = spec present in specs/ (loop will build against it)"
  else
    echo "  + specs/ (empty — run /loop-spec $name to triage + lock a spec, or build roadmap-only)"
  fi

  # LOOP_PROMPT.txt — always re-render from template (cheap, keeps rule fresh)
  sed -e "s|{{APP}}|$name|g" \
      -e "s|{{ROADMAP}}|ROADMAP.md|g" \
      -e "s|{{RULE}}|$rule|g" \
      -e "s|{{DEPLOY}}|$deploy|g" \
      "$PROMPT_TPL" > "$wt/LOOP_PROMPT.txt"
  echo "  + LOOP_PROMPT.txt"

  # DB-safety reminder: a worktree starts with NO .env.local (gitignored). If this
  # project touches a DB, point the worktree's DATABASE_URL at a DEV DB BEFORE
  # launching — never let the loop inherit a prod URL (it will migrate it).
  if [ ! -f "$wt/.env.local" ] && ls "$repo"/.env* >/dev/null 2>&1; then
    echo "  ! $name has no .env.local in the worktree. If it uses a DB, create one"
    echo "    with a NON-PROD DATABASE_URL (dev/branch) before loop-launch.sh."
  fi
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
