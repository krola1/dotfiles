#!/usr/bin/env bash
# Stow alle dotfiles – bruker-config og system-config
# Kjør: ~/dotfiles/scripts/stow-all.sh

set -Eeuo pipefail

DOTFILES="${DOTFILES:-$HOME/dotfiles}"

USER_PACKAGES=(
  niri
  waybar
  fuzzel
  nvim
  fish
  kitty
  moltengamepad
  mako
  code
  swaylock
  qbittorrent
)

SYSTEM_PACKAGES=(
  systemd
  keyd
)

# Mapper som MÅ eksistere som ekte mapper før stow kjører.
# Finnes de ikke, symlinker stow hele mappa inn i repoet, og appen
# begynner å skrive cache, logger og state rett i git-historikken.
PREMAKE_DIRS=(
  "$HOME/.config/Code/User/snippets"
  "$HOME/.vscode"
)

command -v stow >/dev/null 2>&1 || {
  echo "❌ stow er ikke installert. sudo pacman -S stow"
  exit 1
}

# ── Forbered mapper ───────────────────────────────────────────────────────────

echo "📁 Oppretter mapper som ikke skal symlinkes..."
for d in "${PREMAKE_DIRS[@]}"; do
  if [ -L "$d" ]; then
    echo "  ⚠️  $d er en symlink – fjerner den så stow kan folde ned til filnivå"
    rm "$d"
  fi
  mkdir -p "$d"
done

# ── Bruker-config ─────────────────────────────────────────────────────────────

echo ""
echo "🔗 Stow bruker-config (~/)..."
for pkg in "${USER_PACKAGES[@]}"; do
  if [ -d "$DOTFILES/$pkg" ]; then
    echo "  stow $pkg"
    # -R (restow) rydder bort døde symlinks fra filer du har slettet i repoet
    stow -R -d "$DOTFILES" -t "$HOME" "$pkg"
  else
    echo "  ⚠️  $pkg ikke funnet, hopper over"
  fi
done

# ── System-config ─────────────────────────────────────────────────────────────

echo ""
echo "🔗 Stow system-config (/etc)..."
for pkg in "${SYSTEM_PACKAGES[@]}"; do
  if [ -d "$DOTFILES/$pkg" ]; then
    echo "  stow $pkg"
    sudo stow -R -d "$DOTFILES" -t / "$pkg"
  else
    echo "  ⚠️  $pkg ikke funnet, hopper over"
  fi
done

# ── VS Code extensions ────────────────────────────────────────────────────────

echo ""
echo "📦 Installerer VS Code extensions..."

EXTENSIONS_FILE="$DOTFILES/scripts/vscode-extensions.txt"

if [ ! -f "$EXTENSIONS_FILE" ]; then
  echo "  ℹ️  Ingen extension-liste funnet: $EXTENSIONS_FILE"
elif ! command -v code >/dev/null 2>&1; then
  echo "  ⚠️  'code' ikke i PATH – installer visual-studio-code-bin først"
else
  # Hent installerte én gang i stedet for per extension
  INSTALLED="$(code --list-extensions | tr '[:upper:]' '[:lower:]')"

  while IFS= read -r line || [ -n "$line" ]; do
    ext="${line%%#*}"                       # strip kommentar
    ext="$(printf '%s' "$ext" | tr -d '[:space:]')"
    if [ -z "$ext" ]; then
      continue
    fi

    if printf '%s\n' "$INSTALLED" | grep -qixF "$ext"; then
      echo "  ✓ $ext"
    else
      echo "  ↓ $ext"
      code --install-extension "$ext" >/dev/null || echo "  ⚠️  feilet: $ext"
    fi
  done < "$EXTENSIONS_FILE"
fi

echo ""
echo "✅ Stow ferdig!"
