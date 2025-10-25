{...}: {
  programs.fish.functions = {
    reload = ''
      echo "Reloading Fish"
      source ~/.config/fish/config.fish

      echo "Reloading Kitty"
      kitty @ set-colors --all ~/.config/kitty/kitty.conf

      echo "All configs reloaded"
    '';
  };
}
