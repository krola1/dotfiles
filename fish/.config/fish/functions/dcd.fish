# Søk blant toppnivå-pakkene i dotfiles (f.eks. "fish", "niri") - uansett
# hvor terminalen står, siden --search-path peker fast på $dotfiles_dir i
# stedet for $PWD - og cd inn i selve config-mappen (f.eks. .config/niri),
# ikke bare pakke-rota. Samme exclude-liste som ff/fn/ffcd.
function dcd --description 'Søk toppnivå-pakke i dotfiles og cd inn i selve config-mappen'
    set -l pkg (fd --max-depth 1 --type d --hidden (__fd_excludes) --search-path $dotfiles_dir | fzf)
    or return

    set -l name (path basename $pkg)
    for candidate in $pkg/.config/$name $pkg/etc/$name
        if test -d $candidate
            cd $candidate
            return
        end
    end
    cd $pkg
end
