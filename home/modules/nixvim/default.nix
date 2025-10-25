# home/modules/nixvim/default.nix
{
  pkgs,
  lib,
  nixvim,
  ...
}:

let
  # 1) Ta ut den utvidbare konfig-objektet fra elythh/nixvim
  baseCfg = nixvim.nixvimConfigurations.${pkgs.system}.nixvim;

  # 2) Lag en liten modul som overstyrer tema
  setCustomTheme = {
    theme = lib.mkForce "edge-dark";
  };

  # 3) Utvid upstream med vår modul og hent ferdig pakke
  extended = baseCfg.extendModules { modules = [ setCustomTheme ]; };
  myNvim = extended.config.build.package;
in
{
  # 4) Installer vår “bakte” nvim
  home.packages = [ myNvim ];
}

#       "aquarium"
#      "decay"
#       "edge-dark"
#       "everblush"
#       "everforest"
#       "far"
#       "gruvbox"
#       "houseki"
#       "jellybeans"
#       "material"
#       "material-darker"
#       "mountain"
#       "ocean"
#       "oxocarbon"
#       "paradise"
#       "radium"
#       "test"
#       "tokyonight"
#       "yoru"
