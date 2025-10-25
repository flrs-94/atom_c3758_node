{
  description = "GitOps-ready NixOS config for atom-c3758";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }: {
    nixosConfigurations.atom-c3758 = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./hosts/atom-c3758.nix
        ./modules/gitops.nix
      ];
    };
  };
}
