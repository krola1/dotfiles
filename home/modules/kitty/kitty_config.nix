{
  pkgs,
  lib,
  ...
}:
let
  fishPath = "${pkgs.fish}/bin/fish";
  kittyKeymaps = [
    "ctrl+shift+enter new_window"
    "ctrl+shift+w close_window"
    "ctrl+shift+h previous_tab"
    "ctrl+shift+l next_tab"
  ];
in
{
  programs.kitty = {
    enable = true;
    settings = {
      shell = fishPath;
      login_shell = "yes";
      font_family = "JetBrainsMono Nerd Font";
      font_size = 12;
      background = "#1E1E2E";
      foreground = "#CDD6F4";
      selection_background = "#575268";
      selection_foreground = "#1E1E2E";
      cursor = "#F5E0DC";
      enable_audio_bell = "no";
      confirm_os_window_close = 0;
      background_opacity = "0.95";
      window_padding_width = 8;
      scrollback_lines = 5000;
    };
    extraConfig = lib.concatStringsSep "\n" (map (m: "map ${m}") kittyKeymaps);
  };
}
