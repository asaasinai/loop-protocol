#!/usr/bin/env bash
# loop-backup.sh [project|--all]
# Redundancy: push every loop repo's committed work to a PRIVATE GitHub remote.
# - Ensures each manifest repo has an `origin` remote (auto-creates asaasinai/<basename>
#   PRIVATE, but ONLY after a secret scan passes — never pushes a repo whose history
#   contains an env/secret file).
# - Pushes ALL local branches + tags (covers loop/* worktree branches, which live in
#   the parent repo's refs). Uncommitted work can't be pushed — that's the loop's job
#   (it commits per row); this is the off-machine safety net for committed work.
# Idempotent + cron-safe: once a remote exists it just pushes.
set -uo pipefail

PB="$HOME/playbooks"
MANIFEST="$PB/loops.manifest"
LOG="$PB/loop-backup.log"
ORG="asaasinai"
# Real secret-bearing files only. Excludes safe templates (.example/.sample/.template/.dist)
# and source files merely named "secret".
SECRET_RE='(^|/)\.env($|\.local|\.production|\.development|\.prod)|\.pem$|\.p12$|(^|/)id_rsa|service[-_]account[^/]*\.json|[^/]*credentials?[^/]*\.json|\.key$'
SAFE_RE='\.(example|sample|template|dist|md)$'

ts() { date '+%Y-%m-%d %H:%M:%S'; }
log() { echo "[$(ts)] $*" | tee -a "$LOG"; }

backup_one() {
  local name="$1" repo="$2"
  [ -d "$repo/.git" ] || { log "SKIP $name — not a git repo ($repo)"; return; }

  # 1. secret scan over full history — refuse to push if anything sensitive was ever added
  local hits
  hits="$(git -C "$repo" log --all --pretty=format: --name-only --diff-filter=A 2>/dev/null \
          | sort -u | grep -iE "$SECRET_RE" | grep -ivE "$SAFE_RE" || true)"
  if [ -n "$hits" ]; then
    log "BLOCK $name — secret-like files in history, NOT pushing: $(echo "$hits" | tr '\n' ' ')"
    return
  fi

  # 2. ensure origin remote (create private repo if missing)
  if ! git -C "$repo" remote get-url origin >/dev/null 2>&1; then
    local slug="$ORG/$(basename "$repo")"
    if gh repo create "$slug" --private --source="$repo" --remote=origin >/dev/null 2>&1; then
      log "CREATED private remote $slug for $name"
    else
      log "FAIL $name — could not create remote $slug (check gh auth/org access)"; return
    fi
  fi

  # 3. push all branches + tags
  if git -C "$repo" push origin --all --follow-tags >/dev/null 2>&1; then
    local n; n="$(git -C "$repo" ls-remote --heads origin 2>/dev/null | wc -l)"
    log "OK $name — pushed all branches ($n on origin)"
  else
    log "FAIL $name — push errored (see: git -C $repo push origin --all)"
  fi
}

TARGET="${1:---all}"
found=0
while IFS='|' read -r name repo deploy rule; do
  [[ "$name" =~ ^#.*$ || -z "${name// }" ]] && continue
  name="${name// }"; repo="${repo// }"
  if [ "$TARGET" = "--all" ] || [ "$TARGET" = "$name" ]; then
    found=1; backup_one "$name" "$repo"
  fi
done < "$MANIFEST"
[ "$TARGET" = "--all" ] || [ "$found" = 1 ] || { echo "no manifest entry named '$TARGET'" >&2; exit 1; }
