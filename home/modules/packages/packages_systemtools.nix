{ pkgs, ... }:
{
  home.packages = with pkgs; [
    libnotify
    swaylock
    mako
    rclone
    wl-mirror
    glib
    cups
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
    xfce.thunar
    wine
    slurp
    grim
    swww
  ];
  services.blueman-applet.enable = true;

}
