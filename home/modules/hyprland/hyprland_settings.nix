## fine for now, might have to split and source when i get to the design config
{ pkgs, ... }:
{
  wayland.windowManager.hyprland = {
    enable = true;

    settings = {
      "$terminal" = "kitty";
      "$fileManager" = "dolphin";
      "$menu" = "wofi --show drun";
      "$browser" = "firefox";

      env = [
        "HYPRCURSOR_SIZE,24"
        "HYPRCURSOR_THEME, Bibata-Modern-Ice"
        "XCURSOR_SIZE,24"
        "XCURSOR_THEME, Bibata-Modern-Ice"
        "GTK_CSD,0"
        "MOZ_ENABLE_WAYLAND,1"
        "MOZ_DISABLE_CSD,1"
      ];

      ##  ----------General---------
      general = {
        gaps_in = 5;
        gaps_out = 7;
        border_size = 1;
        "col.active_border" = "rgba(33ccffee) rgba(00ff99ee) 45deg";
        "col.inactive_border" = "rgba(595959aa)";

        resize_on_border = false;
        allow_tearing = false;
        layout = "dwindle";
      };

      ## ------------- Dekorasjon
      decoration = {
        rounding = 10;
        rounding_power = 2;
        active_opacity = 1.0;
        inactive_opacity = 1.0;

        shadow = {
          enabled = true;
          range = 4;
          render_power = 3;
          color = "rgba(1a1a1aee)";
        };

        blur = {
          enabled = true;
          size = 3;
          passes = 4;
          vibrancy = 0.17;
        };
      };

      ## -----Layouts
      dwindle = {
        pseudotile = true;
        preserve_split = true;
      };
      master.new_status = "master";

      ## ---- Misc
      misc = {
        force_default_wallpaper = -1; # ingen default wallpaper
        disable_hyprland_logo = false;
      };

      ## -----Input
      input = {
        kb_layout = "no";
        follow_mouse = 1;
        sensitivity = 0;
        touchpad.natural_scroll = false;
      };

      device = {
        name = "epic-mouse-v1";
        sensitivity = -0.5;
      };

      ## ----Window-rules
      windowrule = [
        "suppressevent maximize, class:.*"
        "nofocus,class:^$,title:^$,xwayland:1,floating:1,fullscreen:0,pinned:0"
      ];
    };
  };
}
