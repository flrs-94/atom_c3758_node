{
  description = "GitOps-ready NixOS config for atom-c3758";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }: {
    nixosConfigurations.atom-c3758 = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        system = "x86_64-linux";
        overlays = [
          (import ./overlays/qatlib.nix)
	  (import ./overlays/qat-sdk.nix)
        ];
      };
      modules = [
        ./hosts/atom-c3758.nix
        ./modules/gitops.nix
      ];
    };
  };
}


/*
{
  description = "GitOps-ready NixOS config for atom-c3758";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }: {
    nixosConfigurations.atom-c3758 = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      overlays = [
	(import ./overlay/qatlib.nix)
      ];
      modules = [
        ./hosts/atom-c3758.nix
        ./modules/gitops.nix
      ];
    };
  };
}
*/
