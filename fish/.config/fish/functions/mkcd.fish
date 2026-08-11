function mkcd --description 'Opprett en mappe og gå inn i den'
    mkdir -p $argv
    and cd $argv
end
