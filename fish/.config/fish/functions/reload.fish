# Restarter selve fish-shellet (exec) i stedet for å bare kilde config.fish,
# slik at ALLE conf.d/*.fish og functions/*.fish også lastes på nytt - ikke
# bare config.fish. Reloader også kitty-fargene før shellet restartes.
function reload --description 'Reload fish- og kitty-config'
    echo "Reloading Kitty"
    kitty @ set-colors --all ~/.config/kitty/kitty.conf

    echo "Reloading Fish (restarter shell)"
    exec fish
end
