#!/usr/bin/env bash
# Sync dotfiles mot GitHub
# Kjør regelmessig: ~/dotfiles/scripts/sync-dotfiles.sh

DOTFILES="$HOME/dotfiles"

cd "$DOTFILES" || {
  echo "❌ Finner ikke $DOTFILES"
  exit 1
}

# Oppdater pakkelister før sync
echo "📦 Oppdaterer pakkelister..."
bash "$DOTFILES/scripts/update-pkglists_Version2.sh"

# Sjekk om det er noe å committe
if git diff --quiet && git diff --cached --quiet; then
  echo "✅ Ingen endringer å committe"
else
  echo "📝 Endringer funnet:"
  git status --short
  echo ""

  # Spør om commit-melding
  read -rp "Commit-melding (enter for auto): " MSG
  if [ -z "$MSG" ]; then
    MSG="chore: sync dotfiles $(date '+%Y-%m-%d %H:%M')"
  fi

  git add -A
  git commit -m "$MSG"
fi

# Push
echo "⬆️  Pusher til GitHub..."
git push && echo "✅ Synced!" || echo "❌ Push feilet"

