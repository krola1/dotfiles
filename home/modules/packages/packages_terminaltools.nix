{
  pkgs,
  ...
}:
{
  nixpkgs.overlays = [
    (final: prev: {
      taskwarrior = prev.taskwarrior.overrideAttrs (old: {
        cmakeFlags = (old.cmakeFlags or [ ]) ++ [ "-DCMAKE_POLICY_VERSION_MINIMUM=3.5" ];
      });
    })
  ];
  home.packages = with pkgs; [
    python3Packages.argcomplete
    libinput
    gcalcli
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
    unzip
    unrar
    fswatch
    taskwarrior
    yazi
  ];
  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
  };
}
