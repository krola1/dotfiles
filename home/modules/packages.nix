#Min  første modul, inneholder pakker jeg ser som nødvendige for systemet.i
{
  config,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    file
    nodejs
    nodePackages.prettier
    nodePackages.typescript
    nodePackages.typescript-language-server
    nixd
    kitty
    git
    fish
    wofi
    killall
    htop
    pavucontrol
    lm_sensors
    tree
    blueman
    wireplumber
    wl-clipboard
  ];
}
