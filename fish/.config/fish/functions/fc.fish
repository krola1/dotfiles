# Finn mappe med fd/fzf og åpne den i VS Code.
function fc --description 'Finn mappe med fd/fzf og åpne i VS Code'
    code (fd --type d --exclude .git --exclude node_modules | fzf)
end
