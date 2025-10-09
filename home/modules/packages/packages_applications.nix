{pkgs, ...}: {
  home.packages = with pkgs; [
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
