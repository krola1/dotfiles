{ pkgs, ... }:
{
  home.packages = with pkgs; [

    rustc
    cargo
    python314
    nodejs
    nodePackages.prettier
    nodePackages.typescript
    nodePackages.typescript-language-server
    nixd
    vscode
  ];
}
