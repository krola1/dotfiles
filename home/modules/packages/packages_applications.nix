{ pkgs, ... }:
{
  home.packages = with pkgs; [
    vlc
    qbittorrent
    steam
    ffmpeg
    spotify
    discord
    obs-studio
    brave
    protonvpn-gui
    firefox
  ];

}
