#!/usr/bin/env bash
# Sett opp ny maskin fra dotfiles
# Kjør én gang på ny maskin: bash ~/dotfiles/scripts/install-system.sh

set -e  # stopp ved feil
DOTFILES="$HOME/dotfiles"

# ── Pakker ────────────────────────────────────────────────────────────────────
echo "📦 Installerer pakker..."
sudo pacman -S --needed - < "$DOTFILES/pkglist.txt"

echo "📦 Installerer AUR-pakker..."
# Bytt ut yay med din AUR-helper hvis annen
yay -S --needed - < "$DOTFILES/pkglist-aur.txt"

# ── Stow ──────────────────────────────────────────────────────────────────────
echo "🔗 Kjører stow..."
bash "$DOTFILES/scripts/stow-all.sh"

# ── Systemd ───────────────────────────────────────────────────────────────────
echo "⚙️  Aktiverer systemd-tjenester..."
sudo systemctl daemon-reload
sudo systemctl enable --now moltengamepad.service

# ── udev ──────────────────────────────────────────────────────────────────────
echo "⚙️  Laster udev-regler..."
sudo udevadm control --reload-rules
sudo udevadm trigger

# ── moltengamepad /etc/xdg symlink ───────────────────────────────────────────
echo "🔗 Setter opp /etc/xdg/moltengamepad symlink..."
sudo ln -sf "$HOME/.config/moltengamepad" /etc/xdg/moltengamepad

echo ""
echo "✅ Alt ferdig! Koble til kontrolleren og test."