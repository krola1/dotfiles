{pkgs, ...}: {
  home.packages = with pkgs; [
    pnpm
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
