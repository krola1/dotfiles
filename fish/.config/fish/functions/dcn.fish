# Søk etter en config-fil i dotfiles og åpne den i nvim - uansett hvor
# terminalen står (se dcd.fish for samme prinsipp).
function dcn --description 'Søk etter config-fil i dotfiles og åpne i nvim'
    nvim (fd --type f --hidden (__fd_excludes) --search-path $dotfiles_dir | fzf)
end
