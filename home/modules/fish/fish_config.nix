{pkgs, ...}: {
  imports = [
    ./fish_abbrv_fzf.nix
  ];
  programs.fish = {
    enable = true;
    shellAbbrs = {
      gs = "git status";
      ga = "git add .";
      gc = "git commit -m";
      gp = "git push";
      sm = "cd ~/.dotfiles; and sudo nixos-rebuild switch --flake . --show-trace";
      hm = "cd ~/.dotfiles; and home-manager switch --flake . --show-trace";
      dot = "cd /home/bandit/.dotfiles";
      ls = "lsd -a";
      lt = "lsd -X -r --tree --ignore-glob='.git|node_modules'";
      mkdir = "mkdir -p";
    };
    shellAliases = {
      cd = "z";
      cls = "clear";
      cat = "bat";
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
