#!/usr/bin/env bash
# Oppdater pakkelister i dotfiles
# Kjør regelmessig: ~/dotfiles/scripts/update-pkglists.sh

set -Eeuo pipefail

DOTFILES="${DOTFILES:-$HOME/dotfiles}"

echo "📦 Oppdaterer pakkelister..."

tmp_native="$(mktemp)"
tmp_aur="$(mktemp)"
trap 'rm -f "$tmp_native" "$tmp_aur"' EXIT

# -Qqen = eksplisitt installerte pakker fra repo (native)
# -Qqem = eksplisitt installerte pakker som ikke finnes i repo (foreign/AUR)
# Dette erstatter grep-Fxv-trikset og er både raskere og korrekt når
# pacman -Qqm returnerer tom liste.
pacman -Qqen | sort > "$tmp_native"
pacman -Qqem | sort > "$tmp_aur"

# Sikkerhetsnett: skriv aldri en tom liste over en eksisterende.
# Uten dette kan en feilende pacman etterlate deg med tomme pkglists.
if [ ! -s "$tmp_native" ]; then
  echo "❌ Fikk tom liste fra pacman -Qqen. Avbryter uten å skrive."
  exit 1
fi

install -m 0644 "$tmp_native" "$DOTFILES/pkglist.txt"
install -m 0644 "$tmp_aur" "$DOTFILES/pkglist-aur.txt"

echo "✅ pkglist.txt     – $(wc -l < "$DOTFILES/pkglist.txt") pakker"
echo "✅ pkglist-aur.txt – $(wc -l < "$DOTFILES/pkglist-aur.txt") AUR-pakker"
