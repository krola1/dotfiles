{ pkgs, ... }:
{
  programs.fish = {
    enable = true;
    shellAbbrs = {
      gs = "git status";
      ga = "git add .";
      gc = "git commit -m";
      gp = "git push";
      sm = "sudo nixos-rebuild switch --flake . --show-trace";
      hm = "home-manager switch --flake . --show-trace";
      dot = "cd /home/bandit/.dotfiles";
      ls = "lsd -a";

    };
    shellAliases = {
      cd = "z";
    };
    interactiveShellInit = ''
      set -gx EDITOR nvim
      set -gx VISUAL nvim
      set -gx MANPAGER "nvim +Man!"
      set -g fish_greeting ""
    '';
    functions = {
      cdl = ''
        function cdl
          cd $argv[1]; and ls -la
        end
      '';
      rgf = ''
        function rgf
          rg -n --hidden --glob "!.git" $argv
        end
      '';
    };
  };
}
