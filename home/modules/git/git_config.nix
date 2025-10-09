# home/modules/git.nix
{...}: {
  programs.git = {
    enable = true;

    # ✍️ Dine globale Git-innstillinger
    userName = "krola1";
    userEmail = "kwl082024@gmail.com";

    # 💡 Vanlige preferanser
    extraConfig = {
      core.editor = "nvim";
      pull.rebase = false;
      push.autoSetupRemote = true;
      color.ui = true;
    };
  };
}
