{...}: {
  programs.fish = {
    shellAbbrs = {
      ff = "fd --type f --hidden --exclude .git --exclude .config --exclude .cache --exclude .mozilla --exclude .local --exclude .npm --exclude .ssh --exclude .var --exclude .pki --exclude .gitconfig --exclude gtkrc-2.0 --exclude .bash --exclude node_modules | fzf";
      fcd = "cd (fd -H --type d | fzf)";
      fc = "code (fd --type d --exclude .git --exclude node_modules | fzf)";
      fn = "nvim (fd --type f --hidden --exclude .wine --exclude .vscode --exclude .git --exclude .config --exclude .cache --exclude .mozilla --exclude .local --exclude .npm --exclude .ssh --exclude .var --exclude .pki --exclude .gitconfig --exclude gtkrc-2.0 --exclude .bash --exclude node_modules | fzf)";
      gb = "git branch | fzf | xargs git checkout";
      fk = "ps aux | fzf | awk '{print $2}' | xargs kill -9";
      sc = "fzf --ansi --disabled \
      --prompt='rg> ' \
      --bind 'change:reload:rg --hidden --smart-case --line-number --no-heading --color=always \
        --glob !.git --glob !node_modules --glob !.config --glob !.cache --glob !.mozilla \
        --glob !.local --glob !.npm --glob !.ssh --glob !.var --glob !.pki \
        --glob !.gitconfig --glob !gtkrc-2.0 --glob !.bash {q} || true' \
      --delimiter ':' \
      --preview 'bat --style=numbers --color=always --line-range {2}:{2} {1}' \
      --preview-window=up,60% \
      --bind 'enter:execute(nvim +{2} {1})+abort'";
    };
  };
}
