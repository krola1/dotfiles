#!/usr/bin/env bash
# Sett opp ny maskin fra dotfiles
# Kjør én gang på ny maskin:
# bash ~/dotfiles/scripts/install-system.sh

set -Eeuo pipefail

trap 'echo "❌ Feil på linje $LINENO: $BASH_COMMAND"' ERR

DOTFILES="$HOME/dotfiles"

# ── Hjelpefunksjoner ──────────────────────────────────────────────────────────

read_pkglist() {
  local file="$1"

  if [[ ! -f "$file" ]]; then
    echo "⚠️  Fant ikke pakkeliste: $file"
    return 0
  fi

  # Fjern tomme linjer og kommentarer
  grep -vE '^\s*($|#)' "$file"
}

install_pacman_packages() {
  local file="$1"
  local packages=()
  local missing=()

  mapfile -t packages < <(read_pkglist "$file")

  if [[ "${#packages[@]}" -eq 0 ]]; then
    echo "Ingen pacman-pakker å installere."
    return 0
  fi

  # Finn bare pakker som mangler.
  # `|| true` er viktig fordi pacman -T returnerer non-zero når noe mangler.
  mapfile -t missing < <(pacman -T "${packages[@]}" || true)

  if [[ "${#missing[@]}" -eq 0 ]]; then
    echo "Alle pacman-pakker er allerede installert."
    return 0
  fi

  sudo pacman -S --needed --noconfirm "${missing[@]}"
}

install_aur_packages() {
  local file="$1"
  local packages=()
  local missing=()

  mapfile -t packages < <(read_pkglist "$file")

  if [[ "${#packages[@]}" -eq 0 ]]; then
    echo "Ingen AUR-pakker å installere."
    return 0
  fi

  # Finn AUR-pakker som ikke allerede er installert lokalt.
  mapfile -t missing < <(pacman -T "${packages[@]}" || true)

  if [[ "${#missing[@]}" -eq 0 ]]; then
    echo "Alle AUR-pakker er allerede installert."
    return 0
  fi

  if ! command -v yay >/dev/null 2>&1; then
    echo "❌ yay er ikke installert, men AUR-pakker mangler."
    echo "Installer yay først, eller bytt AUR-helper i skriptet."
    exit 1
  fi

  yay -S --needed --noconfirm "${missing[@]}"
}

# ── Pakker ────────────────────────────────────────────────────────────────────

echo "📦 Installerer pakker..."
install_pacman_packages "$DOTFILES/pkglist.txt"

echo "📦 Installerer AUR-pakker..."
install_aur_packages "$DOTFILES/pkglist-aur.txt"

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
sudo mkdir -p /etc/xdg
sudo ln -sfn "$HOME/.config/moltengamepad" /etc/xdg/moltengamepad

echo ""
echo "✅ Alt ferdig! Koble til kontrolleren og test."
