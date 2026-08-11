function sc --description 'ripgrep + fzf søk med forhåndsvisning, enter åpner treff i nvim'
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
