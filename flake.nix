# flake.nix
{
  description = "Bandit-Flake";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-25.05";
    home-manager.url = "github:nix-community/home-manager/release-25.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # + treefmt-nix for `nix fmt` med alejandra
    treefmt-nix.url = "github:numtide/treefmt-nix";
  };

  outputs = {
    self,
    nixpkgs,
    home-manager,
    treefmt-nix,
    ...
  }: let
    lib = nixpkgs.lib;
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};

    # + tree-wrapper som kjører alejandra
    tree = treefmt-nix.lib.mkWrapper pkgs {
      projectRootFile = "flake.nix";
      programs.alejandra.enable = true;
      programs.prettier.enable = true;
      programs.shfmt.enable = true;
      programs.black.enable = true;
    };
  in {
    nixosConfigurations = {
      nixos = lib.nixosSystem {
        inherit system;
        modules = [./configuration.nix];
      };
    };
    homeConfigurations = {
      bandit = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [./home];
      };
    };

    # + gjør at `nix fmt` kjører treefmt (alejandra)
    formatter.${system} = tree;
  };
}
