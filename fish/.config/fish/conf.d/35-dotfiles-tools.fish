# ==============================================================================
# Delt variabel for dotfiles-baserte søk (dcd, dcn - se functions/).
# Disse skal alltid søke i dotfiles-repoet, uansett hvilken mappe terminalen
# står i - derfor peker de på denne faste stien, ikke $PWD.
# ==============================================================================

set -g dotfiles_dir $HOME/dotfiles
