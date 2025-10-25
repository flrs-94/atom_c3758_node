{ config, pkgs, ... }:

{
  # Hostname und Zeitzone
  networking.hostName = "atom-c3758";
  time.timeZone = "Europe/Berlin";

  # Flake-Unterstützung
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Systempakete inkl. git + ssh
  environment.systemPackages = with pkgs; [
    git
    openssh
  ];

  # Bootloader (UEFI)
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Root-Dateisystem
  fileSystems."/" = {
    device = "/dev/nvme1n1p2";
    fsType = "ext4";
  };

  # GitOps-Modul einbinden
  imports = [
    ./../modules/gitops.nix
  ];

  # system.stateVersion setzen
  system.stateVersion = "25.11";
}
