# home/modules/waybar.nix
{ pkgs, ... }:
{
  programs.waybar = {
    enable = true;
    # sizer and position
    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 28;
        margin-top = 6;
        margin-left = 6;
        margin-right = 6;

        # Sections
        modules-left = [ "hyprland/workspaces" ];
        modules-center = [ "clock" ];
        modules-right = [
          "tray"
        ];

        tray = {
          icon-size = 20;
          spacing = 8;
        };

        # workspace viewer
        "hyprland/workspaces" = {
          all-outputs = true;
          format = "{icon}";
          format-icons = {
            default = "";
            active = "";
            urgent = "";
          };

          on-click = "hyprctl dispatch workspace {id}";
          on-scroll-up = "hyprctl dispatch workspace e+1";
          on-scroll-down = "hyprctl dispatch workspace e-1";
        };

        #clock
        clock = {
          interval = 60;
          format = "{:%H:%M}";
          format-alt = "{:%H:%M:%S}";
          tooltip-format = "{:%A %d %B %Y}";
        };

      };
    };

    #styling
    style = ''
      * { font-family: "JetBrainsMono Nerd Font", monospace; font-size: 13px; }
      window#waybar { background: rgba(24, 24, 28, 0.6); }

      #workspaces { background: rgba(0,0,0,0.4); border-radius: 10px; padding: 2px 6px; }
      #workspaces button { color: #cdd6f4; padding: 2px 6px; }
      #workspaces button.active  { color: #89b4fa; }
      #workspaces button.urgent  { color: #f38ba8; }

      #clock { padding: 0 10px; color: #cdd6f4; }

    '';
  };
}
