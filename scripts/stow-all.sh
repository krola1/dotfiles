
#!/usr/bin/env bash
# Stow alle dotfiles – bruker-config og system-config
# Kjør: ~/dotfiles/scripts/stow-all.sh

set -euo pipefail

DOTFILES="$HOME/dotfiles"

USER_PACKAGES=(
  niri
  waybar
  fuzzel
  nvim
  fish
  kitty
  moltengamepad
  mako
  code-oss
  swaylock
  qbittorrent
)

SYSTEM_PACKAGES=(
  systemd
  keyd
  udev
)

echo "🔗 Stow bruker-config (~/)..."
for dir in "${USER_PACKAGES[@]}"; do
  if [ -d "$DOTFILES/$dir" ]; then
    echo "  stow $dir"
    stow -d "$DOTFILES" -t "$HOME" "$dir"
  else
    echo "  ⚠️  $dir ikke funnet, hopper over"
  fi
done

echo ""
echo "🔗 Stow system-config (/etc)..."
for dir in "${SYSTEM_PACKAGES[@]}"; do
  if [ -d "$DOTFILES/$dir" ]; then
    echo "  stow $dir"
    sudo stow -d "$DOTFILES" -t / "$dir"
  else
    echo "  ⚠️  $dir ikke funnet, hopper over"
  fi
done

echo ""
echo "📦 Installerer Code - OSS extensions hvis liste finnes..."

EXTENSIONS_FILE="$DOTFILES/scripts/code-oss-extensions.txt"

if [ -f "$EXTENSIONS_FILE" ]; then
  if command -v code-oss >/dev/null 2>&1; then
    VSCODE_CLI="code-oss"
  elif command -v code >/dev/null 2>&1; then
    VSCODE_CLI="code"
  else
    VSCODE_CLI=""
  fi

  if [ -n "$VSCODE_CLI" ]; then
    while IFS= read -r extension || [ -n "$extension" ]; do
      # Hopper over tomme linjer og kommentarer
      [[ -z "$extension" || "$extension" =~ ^# ]] && continue

      echo "  installerer $extension"
      "$VSCODE_CLI" --install-extension "$extension" || true
    done < "$EXTENSIONS_FILE"
  else
    echo "  ⚠️  Fant verken code-oss eller code, hopper over extensions"
  fi
else
  echo "  ℹ️  Ingen extension-liste funnet: $EXTENSIONS_FILE"
fi

echo ""
echo "✅ Stow ferdig!"
```
