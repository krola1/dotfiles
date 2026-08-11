##### Miljø og oppstart (interactiveShellInit) #################################
set -gx EDITOR nvim
set -gx VISUAL nvim
set -gx MANPAGER "nvim +Man!"
# Skru av standard hilsen
set -g fish_greeting

##### Abbreviations (shellAbbrs) ###############################################
# Brukes når du skriver kommandoer — utvides før kjøring.
abbr -a gs 'git status'
abbr -a ga 'git add .'
abbr -a gc 'git commit -m'
abbr -a gp 'git push'
abbr -a sm 'cd ~/.dotfiles; and sudo nixos-rebuild switch --flake . --show-trace'
abbr -a hm 'cd ~/.dotfiles; and home-manager switch --flake . --show-trace'
abbr -a dot 'cd ~/.dotfiles'
abbr -a ls 'lsd -a'
abbr -a lt "lsd -X -r --tree --ignore-glob='.git|node_modules'"
abbr -a mkdir 'mkdir -p'
abbr -a grep 'grep -i'
abbr -a calendar 'gcalcli calw'
abbr -a ff 'fd --type f --hidden --exclude .git --exclude --exclude .cache --exclude .mozilla --exclude .local --exclude .npm --exclude .ssh --exclude .var --exclude .pki --exclude .gitconfig --exclude gtkrc-2.0 --exclude .bash --exclude node_modules | fzf'
abbr -a fcd 'cd (fd -H --type d | fzf)'
abbr -a fc 'code (fd --type d --exclude .git --exclude node_modules | fzf)'
abbr -a fn 'nvim (fd --type f --hidden --exclude .wine --exclude .vscode --exclude .git --exclude .cache --exclude .mozilla --exclude .local --exclude .npm --exclude .ssh --exclude .var --exclude .pki --exclude .gitconfig --exclude gtkrc-2.0 --exclude .bash --exclude node_modules | fzf)'
abbr -a gb 'git branch | fzf | xargs git checkout'
abbr -a fk "ps aux | fzf | awk '{print \$2}' | xargs kill -9"
abbr -a steam "steam -system-composer"
abbr -a npm pnpm

##### Aliases (shellAliases) ###################################################
# Merk: alias cd='z' forutsetter at du bruker zoxide (kommando: `z`)
alias cd='z'
alias cls='clear'
alias cat='bat'

##### Funksjoner (functions) ###################################################

function mkcd --description 'Opprett en mappe og gå inn i den'
    mkdir -p $argv
    and cd $argv
end

function rmcd
    set current $PWD
    cd ..
    and rm -rf $current
end

# cdl: cd inn i mappe og list innhold

function cdl
    cd $argv[1]; and ls -la
end
function sc --description 'ripgrep + fzf søk med forhåndsvisning'
    fzf --ansi --disabled \
        --prompt='rg> ' \
        --bind "change:reload:rg --hidden --smart-case --line-number --no-heading --color=always \
            --glob !.git --glob !node_modules --glob !.config --glob !.cache --glob !.mozilla \
            --glob !.local --glob !.npm --glob !.ssh --glob !.var --glob !.pki \
            --glob !.gitconfig --glob !gtkrc-2.0 --glob !.bash {q} || true" \
        --delimiter ':' \
        --preview "bat --style=numbers --color=always --line-range {2}:{2} {1}" \
        --preview-window=up,60% \
        --bind "enter:execute(nvim +{2} {1})+abort"
end
function reload
    echo "Reloading Fish"
    source ~/.config/fish/config.fish

    echo "Reloading Kitty"
    kitty @ set-colors --all ~/.config/kitty/kitty.conf

    echo "All configs reloaded"
end

# rgf: ripgrep med nyttige defaults (inkl. skjulte filer, uten .git)
function rgf
    rg -n --hidden --glob "!.git" $argv
end

zoxide init fish | source

################################################################################
# SSH-AGENT (robust, fish-kompatibel)
################################################################################

# Start ssh-agent hvis ikke allerede startet
if not set -q SSH_AUTH_SOCK
    eval (ssh-agent -c) >/dev/null
    ssh-add ~/.ssh/id_ed25519 >/dev/null
end

################################################################################
# GIT – IDENTER FOR JOBB OG PRIVAT
################################################################################

# Bytt repo til JOBB-identitet
abbr -a git-jobb 'git config user.name "krola1"; git config user.email "REDACTED"'

# Bytt repo til PRIVAT-identitet
abbr -a git-priv 'git config user.name "kwlbandit"; git config user.email "REDACTED"'
