# Finn mappe med fd/fzf og cd inn i den. Ingen exclude-liste her
# (uendret fra original) - søker gjennom alt inkl. skjulte mapper.
function fcd --description 'Finn mappe med fd/fzf og cd inn i den'
    cd (fd -H --type d | fzf)
end
