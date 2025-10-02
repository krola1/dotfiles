{lib, ...}: {
  #sources the file
  wayland.windowManager.hyprland.extraConfig = lib.mkAfter "
		source = ~/.config/hypr/animations.conf
		";

  ##----- insert nix code here if needed
  ## sets  .config/hypr/animations.conf too be equal to .dotfiles/home/module/hyperland/animations.conf
  home.file.".config/hypr/animations.conf".source = ./animations.conf;
}
