{ ... }:
{
  programs.fish = {
    shellAbbrs = {
      ff = "fd --type f | fzf";
      fcd = "cd (fd --type d | fzf)";
      fnvim = "nvim (fd --type f --hidden --exclude .git | fzf)";
      gb = "git branch | fzf | xargs git checkout";
      fk = "ps aux | fzf | awk '{print $2}' | xargs kill -9";
    };
  };

}
