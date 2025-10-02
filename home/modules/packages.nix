#Min  første modul, inneholder pakker jeg ser som nødvendige for systemet.i
{
  config,
  pkgs,
  nixvim,
  ...
}:
{
  ###comented out packages are enabled in their own files
  home.packages = with pkgs; [
    file
    nodejs
    nodePackages.prettier
    nodePackages.typescript
    nodePackages.typescript-language-server
    nixd
    #kitty
    git
    #fish
    #waybar
    #hyprland
    #nvim
    wofi
    killall
    htop
    pavucontrol
    lm_sensors
    tree
    blueman
    wireplumber
    wl-clipboard
    nixvim.packages.${pkgs.system}.default
  ];
}
