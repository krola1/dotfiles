function rgf --description 'ripgrep med nyttige defaults (inkl. skjulte filer, uten .git)'
    rg -n --hidden --glob "!.git" $argv
end
