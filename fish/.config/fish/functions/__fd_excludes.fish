# Intern hjelpefunksjon (dobbel understrek = ikke tenkt kalt direkte av bruker).
# Bygger --exclude-flagg for fd fra $fish_search_excludes (satt i
# conf.d/30-search-tools.fish), slik at listen bare finnes ett sted.
# Brukes som: fd ... (__fd_excludes) | fzf
function __fd_excludes --description 'Bygger --exclude-flagg for fd fra $fish_search_excludes'
    for pattern in $fish_search_excludes
        printf '%s\n' --exclude $pattern
    end
end
