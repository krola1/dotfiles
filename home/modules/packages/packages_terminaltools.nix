{ pkgs, nixvim, ... }:
{
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

  ];
  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
  };
}
