# Filsøk: fd + fzf, utelater støy-mapper (se conf.d/30-search-tools.fish).
function ff --description 'Søk etter filnavn med fd/fzf'
    fd --type f --hidden (__fd_excludes) | fzf
end
