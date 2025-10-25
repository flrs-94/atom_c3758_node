{
  description = "GitOps-bootfähige NixOS-Konfiguration für atom_c3758_node";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        packages.default = pkgs.hello;

        nixosConfigurations.atom-c3758 = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./hosts/atom-c3758.nix
            ./modules/gitops.nix
          ];
        };
      });
}
