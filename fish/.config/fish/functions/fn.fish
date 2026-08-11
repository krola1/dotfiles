# Finn fil med fd/fzf og åpne den i nvim.
function fn --description 'Finn fil med fd/fzf og åpne i nvim'
    nvim (fd --type f --hidden (__fd_excludes) | fzf)
end
