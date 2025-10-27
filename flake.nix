{
  description = "GitOps-ready NixOS config for atom-c3758";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }: 
    let
      # Firmware-Dateien aus dem Repo verfügbar machen
      firmwareBins = {
        qat_c3xxx_mmp = builtins.path {
          path = ./firmware/intel/qat/qat_c3xxx_mmp.bin;
          name = "qat_c3xxx_mmp.bin";
        };
        qat_c3xxx = builtins.path {
          path = ./firmware/intel/qat/qat_c3xxx.bin;
          name = "qat_c3xxx.bin";
        };
      };
    in {
      nixosConfigurations.atom-c3758 = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit firmwareBins; };
        pkgs = import nixpkgs {
          system = "x86_64-linux";
          config.allowUnfree = true;
          overlays = [
            (final: prev: { inherit firmwareBins; })
            (import ./overlays/qatlib.nix)
            (import ./overlays/qat-sdk.nix)
            (import ./overlays/qat-firmware.nix)
            (import ./overlays/cockpit.nix)
          ];
        };
        modules = [
          ./hosts/atom-c3758.nix
        ];
      };
    };
}
