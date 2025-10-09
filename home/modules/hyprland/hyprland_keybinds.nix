# This is my attempt for å combinations system, .nix loops through repeatable binds, config file for the remainder
{lib, ...}: {
  #sources file,
  wayland.windowManager.hyprland.extraConfig = lib.mkAfter ''
    source = ~/.config/hypr/keybinds.conf
  '';

  #____ insert nix code here if neede___
  #sets binds as nix code
  wayland.windowManager.hyprland.settings.bind =
    # commands can be passed as array if "strightforward"
    ["SUPER, RETURN, exec, kitty"]
    # map creates moves to workspace another displays it. pas through keys 1-10
    ++ map (n: "SUPER, ${toString n}, workspace, ${toString n}") (lib.range 1 9)
    ++ map (m: "SUPER SHIFT, ${toString m}, movetoworkspace, ${toString m}") (lib.range 1 9);
  # Symlinks .keybinds.conf to .conf/hypr/keybinds.conf
  home.file.".config/hypr/keybinds.conf".source = ./conf/keybinds.conf;
}
