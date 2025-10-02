# This is my attempt for å combinations system, .nix loops through repeatable binds, config file for the remainder
{lib, ...}: {
  # Bruk din eksisterende conf-fil
  wayland.windowManager.hyprland.extraConfig = lib.mkAfter ''
    source = ~/.config/hypr/keybinds.conf
  '';

  #

  wayland.windowManager.hyprland.settings.bind =
    ["SUPER, RETURN, exec, kitty"]
    #one map creates moves to workspace another displays it. pas through keys 1-10
    ++ map (n: "SUPER, ${toString n}, workspace, ${toString n}") (lib.range 1 9)
    ++ map (m: "SUPER SHIFT, ${toString m}, movetoworkspace, ${toString m}") (lib.range 1 9);
  # Slink til .config
  home.file.".config/hypr/keybinds.conf".source = ./keybinds.conf;
}

