{ config, pkgs, lib, ... }:

{
  imports = [
    (fetchTarball "https://github.com/nix-community/nixos-vscode-server/tarball/master")
  ];

  services.vscode-server.enable = true;

  services.openssh.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 ];

  environment.systemPackages = with pkgs; [
    git curl bash gnugrep coreutils tar gcc
  ];

  programs.nix-ld.enable = true;
}
