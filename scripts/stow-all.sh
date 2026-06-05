#!/usr/bin/env bash
# Stow alle dotfiles – bruker-config og system-config
# Kjør: ~/dotfiles/scripts/stow-all.sh

DOTFILES="$HOME/dotfiles"

# ── Bruker-config (~/) ────────────────────────────────────────────────────────
echo "🔗 Stow bruker-config (~/)..."
for dir in niri waybar fuzzel nvim fish kitty moltengamepad, mako; do
  if [ -d "$DOTFILES/$dir" ]; then
    echo "  stow $dir"
    stow -d "$DOTFILES" -t "$HOME" "$dir"
  else
    echo "  ⚠️  $dir ikke funnet, hopper over"
  fi
done

# ── System-config (/etc) ──────────────────────────────────────────────────────
echo "🔗 Stow system-config (/etc)..."
for dir in systemd keyd udev; do
  if [ -d "$DOTFILES/$dir" ]; then
    echo "  stow $dir"
    sudo stow -d "$DOTFILES" -t / "$dir"
  else
    echo "  ⚠️  $dir ikke funnet, hopper over"
  fi
done

echo ""
echo "✅ Stow ferdig!"

