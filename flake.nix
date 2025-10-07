# flake.nix
{
  description = "Bandit-Flake";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager/";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nixvim.url = "github:elythh/nixvim";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = {
    self,
    nixpkgs,
    home-manager,
    treefmt-nix,
    nixvim,
    ...
  }: let
    lib = nixpkgs.lib;
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};

    # tree-wrapper som kjører alejandra
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
        modules = [
          ./configuration.nix
        ];
      };
    };
    homeConfigurations = {
      bandit = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [./home];
        extraSpecialArgs = {inherit nixvim;};
      };
    };

    # + gjør at `nix fmt` kjører treefmt (alejandra)
    formatter.${system} = tree;
  };
}
