{pkgs, ...}: {
  home.packages = with pkgs; [
    git
    lm_sensors
    networkmanagerapplet
    blueman
    wireplumber
    pasystray
    pavucontrol
    hyprcursor
    bibata-cursors
    wofi
    wl-clipboard
  ];
}
