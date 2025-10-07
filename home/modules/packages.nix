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
    #------------system-------------
    #------------ie the basics-----
    #kitty
    #fish
    nixvim.packages.${pkgs.system}.default # instead of neovim
    wl-clipboard
    killall
    htop
    tree
    git
    lm_sensors
    #-----ui--------
    #hyprland
    #waybar
    wireplumber
    blueman
    pavucontrol
    pasystray
    file
    wofi
    networkmanagerapplet
    ##------------programing, ie langueagepacks, compilers etc
    rustc
    cargo
    python314
    nodejs
    nodePackages.prettier
    nodePackages.typescript
    nodePackages.typescript-language-server
    nixd

    ##---------------other programs, music, etc
    vlc
    qbittorrent
    ffmpeg
    spotify
    discord
    obs-studio
    steam
    protonvpn-gui
  ];
}
