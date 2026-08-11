# ==============================================================================
# Generelle abbreviations (utvides til full kommando når du trykker mellomrom).
# Søk-relaterte kommandoer (ff, fcd, ffcd, fc, fn) ligger som egne funksjoner,
# se functions/ og conf.d/30-search-tools.fish.
# ==============================================================================

# --- Git ---
abbr -a gs 'git status'
abbr -a ga 'git add .'
abbr -a gc 'git commit -m'
abbr -a gp 'git push'
abbr -a gb 'git branch | fzf | xargs git checkout'

# --- Dotfiles / systemoppdatering ---
abbr -a sm 'cd ~/.dotfiles; and sudo nixos-rebuild switch --flake . --show-trace'
abbr -a hm 'cd ~/.dotfiles; and home-manager switch --flake . --show-trace'
abbr -a dot 'cd ~/.dotfiles'

# --- Erstatt vanlige kommandoer med bedre defaults ---
# (abbr-navnet er identisk med ekte kommandonavn med vilje: fungerer som en
# "smart default" som utvides synlig på kommandolinjen før den kjøres)
abbr -a ls 'lsd -a'
abbr -a lt "lsd -X -r --tree --ignore-glob='.git|node_modules'"
abbr -a mkdir 'mkdir -p'
abbr -a grep 'grep -i'
abbr -a npm pnpm

# --- Diverse ---
abbr -a calendar 'gcalcli calw'
abbr -a fk "ps aux | fzf | awk '{print \$2}' | xargs kill -9"
abbr -a steam "steam -system-composer"
