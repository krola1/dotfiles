{pkgs, ...}: {
  home.packages = with pkgs; [
    vlc
    qbittorrent
    ffmpeg
    spotify
    discord
    obs-studio
    steam
    brave
    protonvpn-gui
  ];
}
