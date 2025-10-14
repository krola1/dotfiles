{
  config,
  pkgs,
  lib,
  ...
}:

let
  sep = "\n\n// ----\n\n";
  kdlParts = [
    (builtins.readFile ./kdl/input.kdl)
    (builtins.readFile ./kdl/monitors.kdl)
    (builtins.readFile ./kdl/layout.kdl)
    (builtins.readFile ./kdl/ui.kdl)
    (builtins.readFile ./kdl/animations.kdl)
    (builtins.readFile ./kdl/window-rules.kdl)
    (builtins.readFile ./kdl/hotkey-overlay.kdl)
    (builtins.readFile ./kdl/startup.kdl)
    (builtins.readFile ./kdl/binds.kdl)
  ];
  combined = builtins.concatStringsSep sep kdlParts;
in
{
  # Velg én av disse to (begge virker):

  # 1) XDG-vennlig (anbefalt):
  xdg.configFile."niri/config.kdl".text = combined;

  # 2) Eller hardkodet sti med home.file:
  # home.file.".config/niri/config.kdl".text = combined;
}
