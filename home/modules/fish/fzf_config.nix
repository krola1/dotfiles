{ ... }:
{
  programs.fish = {
    shellAbbrs = {
      ff = "fd --type f --hidden --exclude .git --exclude .config --exclude .cache --exclude .mozilla --exclude .local --exclude .npm --exclude .ssh --exclude .var --exclude .pki --exclude .gitconfig --exclude gtkrc-2.0 --exclude .bash --exclude node_modules | fzf";
      fcd = "cd (fd -H --type d | fzf)";
      fc = "code (fd --type d | fzf)";
      fn = "nvim (fd --type f --hidden --exclude .git --exclude .config --exclude .cache --exclude .mozilla --exclude .local --exclude .npm --exclude .ssh --exclude .var --exclude .pki --exclude .gitconfig --exclude gtkrc-2.0 --exclude .bash --exclude node_modules | fzf)";
      gb = "git branch | fzf | xargs git checkout";
      fk = "ps aux | fzf | awk '{print $2}' | xargs kill -9";
    };
  };

}
