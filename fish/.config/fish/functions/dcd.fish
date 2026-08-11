# Søk etter en config-mappe i dotfiles (f.eks. "fish") og cd inn i den -
# uansett hvor terminalen står, siden --search-path peker fast på
# $dotfiles_dir i stedet for $PWD. Samme exclude-liste som ff/fn/ffcd.
function dcd --description 'Søk etter config-mappe i dotfiles og cd inn i den'
    cd (fd --type d --hidden (__fd_excludes) --search-path $dotfiles_dir | fzf)
end
