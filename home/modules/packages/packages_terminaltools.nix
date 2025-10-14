{
  pkgs,
  nixvim,
  ...
}:
{
  nixpkgs.overlays = [
    (final: prev: {
      taskwarrior = prev.taskwarrior.overrideAttrs (old: {
        cmakeFlags = (old.cmakeFlags or [ ]) ++ [ "-DCMAKE_POLICY_VERSION_MINIMUM=3.5" ];
      });
    })
  ];
  home.packages = with pkgs; [
    nixvim.packages.${pkgs.system}.default # instead of neovim
    eza
    lsd
    fzf
    fd
    ripgrep
    bat
    killall
    htop
    tree
    file
    unzip
    unrar
    fswatch
    taskwarrior
  ];
  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
  };
}
