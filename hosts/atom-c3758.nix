{ config, pkgs, ... }:

{
  networking.hostName = "atom-c3758";
  time.timeZone = "Europe/Berlin";

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  environment.systemPackages = with pkgs; [
    openssh
    git
    nixos-rebuild
  ];

  services.openssh.enable = true;

  # ✅ Pflicht: Root-Dateisystem
  fileSystems."/" = {
    device = "/dev/nvme1n1p2";
    fsType = "ext4"; # oder "btrfs", je nach Setup
  };

  # ✅ Pflicht: GRUB-Ziel
  boot.loader.grub.enable = false;
 # boot.loader.grub.devices = [ "/dev/nvme1n1" ];
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Optional: stateVersion setzen
#  system.stateVersion = "25.05";
}
