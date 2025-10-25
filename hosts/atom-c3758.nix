{ config, pkgs, ... }:

{
  networking.hostName = "atom-c3758";
  time.timeZone = "Europe/Berlin";

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  environment.systemPackages = with pkgs; [
    git
    nixos-rebuild
  ];

  services.openssh.enable = true;
}
