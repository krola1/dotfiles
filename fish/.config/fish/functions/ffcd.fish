# Finn fil med fd/fzf, cd til mappen filen ligger i (samme søk som fn/ff,
# men åpner foreldremappen i stedet for filen).
function ffcd --description 'Finn fil med fd/fzf, cd til mappen filen ligger i'
    cd (dirname (fd --type f --hidden (__fd_excludes) | fzf))
end
