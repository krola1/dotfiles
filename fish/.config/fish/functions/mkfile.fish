function mkfile --description 'Opprett en fil (med nødvendige mapper) og gå inn i mappen den ligger i'
    if test (count $argv) -eq 0
        echo "bruk: mkfile sti/til/fil.ext" >&2
        return 1
    end

    for file in $argv
        set -l dir (dirname $file)
        if test $dir != "."
            mkdir -p $dir
        end
        touch $file
    end

    cd (dirname $argv[-1])
end
