{ config, pkgs, lib, ... }:

{
  imports = [
    (fetchTarball {
	url = "https://github.com/nix-community/nixos-vscode-server/tarball/master";
	sha256 = "1rdn70jrg5mxmkkrpy2xk8lydmlc707sk0zb35426v1yxxka10by";
	})
  ];

  services.vscode-server.enable = true;

  services.openssh.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 ];

  environment.systemPackages = with pkgs; [
    git curl bash gnugrep coreutils gnutar gcc
  ];

  programs.nix-ld.enable = true;
}
