## no need to create seperate .conf file for this at this point.
{ ... }:
{
  wayland.windowManager.hyprland.settings."exec-once" = [
    "waybar"
    "nm-applet"
    "blueman-applet"
    "protonvpn-app"
    "pasystray"
  ];
}
