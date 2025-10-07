## no need to create seperate .conf file for this at this point.
{ ... }:
{
  wayland.windowManager.hyprland.settings."exec-once" = [
    "waybar"
    "pasystray"
    "blueman-applet"
    "protonvpn-app"
    "nm-applet"
  ];
}
