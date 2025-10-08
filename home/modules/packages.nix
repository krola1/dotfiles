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
    eza
    lsd
    fzf
    fd
    ripgrep
    bat
    wl-clipboard
    killall
    htop
    tree
    git
    lm_sensors
    #upower
    #-----ui--------
    #hyprland
    #waybar
    nwg-look
    hyprcursor
    bibata-cursors
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
    vscode
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

  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;

  };
}
