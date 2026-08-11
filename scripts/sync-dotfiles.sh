#!/usr/bin/env bash
# Sync dotfiles mot GitHub
# Kjør regelmessig: ~/dotfiles/scripts/sync-dotfiles.sh
#
# Bruk -m "melding" for å hoppe over prompten (nyttig fra timer/keybind).

set -Eeuo pipefail

DOTFILES="${DOTFILES:-$HOME/dotfiles}"
MSG=""

while getopts "m:" opt; do
  case "$opt" in
    m) MSG="$OPTARG" ;;
    *) echo "Bruk: $0 [-m \"commit-melding\"]"; exit 1 ;;
  esac
done

cd "$DOTFILES" || {
  echo "❌ Finner ikke $DOTFILES"
  exit 1
}

# Sikre at vi faktisk står i et git-repo, ikke bare en mappe med samme navn
git rev-parse --git-dir >/dev/null 2>&1 || {
  echo "❌ $DOTFILES er ikke et git-repo"
  exit 1
}

echo "📦 Oppdaterer pakkelister..."
"$DOTFILES/scripts/update-pkglists.sh"

# --porcelain fanger også untracked files, som git diff ikke gjør
if [ -z "$(git status --porcelain)" ]; then
  echo "✅ Ingen endringer å committe"
else
  echo "📝 Endringer funnet:"
  git status --short
  echo ""

  if [ -z "$MSG" ]; then
    if [ -t 0 ]; then
      read -rp "Commit-melding (enter for auto): " MSG
    fi
  fi

  if [ -z "$MSG" ]; then
    MSG="chore: sync dotfiles $(date '+%Y-%m-%d %H:%M')"
  fi

  git add -A
  git commit -m "$MSG"
fi

echo "⬆️  Pusher til GitHub..."
if git push; then
  echo "✅ Synced!"
else
  echo "❌ Push feilet"
  exit 1
fi
