{ config, pkgs, ... }:

{
  imports = [];

  networking.hostName = "atom-c3758";
  time.timeZone = "Europe/Berlin";

  environment.systemPackages = with pkgs; [
    git
    nixos-rebuild
  ];

  services.openssh.enable = true;
}
