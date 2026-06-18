#!/usr/bin/env bash
# loop-launch.sh <project>|--all
# Opens one tmux window per project in session "loops", cds into its worktree,
# starts `claude`, and loads its loop prompt into that pane's tmux paste buffer.
# Then: tmux attach -t loops ; in each pane press  prefix + ]  to paste, Enter.
set -euo pipefail

PB="$HOME/playbooks"
MANIFEST="$PB/loops.manifest"
SESSION="loops"
die() { echo "ERROR: $*" >&2; exit 1; }
command -v tmux >/dev/null || die "tmux not installed"

tmux has-session -t "$SESSION" 2>/dev/null || tmux new-session -d -s "$SESSION" -n _bootstrap

launch() {
  local name="$1" repo="$2"
  local wt; wt="$(dirname "$repo")/${name}-loop"
  [ -d "$wt" ] || { echo "SKIP $name — no worktree (run loop-new.sh $name)"; return; }
  [ -f "$wt/LOOP_PROMPT.txt" ] || { echo "SKIP $name — no LOOP_PROMPT.txt"; return; }
  tmux new-window -t "$SESSION" -n "$name" -c "$wt"
  tmux load-buffer -b "loop-$name" "$wt/LOOP_PROMPT.txt"
  tmux send-keys -t "$SESSION:$name" "claude" Enter
  echo "window  $name  (paste prompt: prefix + ] , then Enter)"
}

[ $# -eq 1 ] || die "usage: loop-launch.sh <project>|--all"
while IFS='|' read -r name repo deploy rule; do
  [[ "$name" =~ ^#.*$ || -z "${name// }" ]] && continue
  name="${name// }"
  if [ "$1" = "--all" ] || [ "$1" = "$name" ]; then launch "$name" "$repo"; fi
done < "$MANIFEST"

tmux kill-window -t "$SESSION:_bootstrap" 2>/dev/null || true
echo "---"
echo "attach:  tmux attach -t $SESSION"
