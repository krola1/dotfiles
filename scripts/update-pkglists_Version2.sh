#!/usr/bin/env bash
# Oppdater pakkelister i dotfiles
# Kjør regelmessig: ~/dotfiles/scripts/update-pkglists.sh

DOTFILES="$HOME/dotfiles"

echo "📦 Oppdaterer pakkelister..."

pacman -Qqe | grep -Fxv "$(pacman -Qqm)" > "$DOTFILES/pkglist.txt"
pacman -Qqm > "$DOTFILES/pkglist-aur.txt"

echo "✅ pkglist.txt     – $(wc -l < "$DOTFILES/pkglist.txt") pakker"
echo "✅ pkglist-aur.txt – $(wc -l < "$DOTFILES/pkglist-aur.txt") AUR-pakker"