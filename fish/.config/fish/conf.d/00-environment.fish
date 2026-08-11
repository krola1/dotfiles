# ==============================================================================
# Miljøvariabler og grunnleggende shell-oppsett.
# Lastes automatisk av fish ved hver shell-start (før config.fish).
# ==============================================================================

set -gx EDITOR nvim
set -gx VISUAL nvim
set -gx MANPAGER "nvim +Man!"

# Skru av standard fish-hilsen ved oppstart
set -g fish_greeting
