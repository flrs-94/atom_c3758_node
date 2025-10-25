{ config, pkgs, ... }:

{
  systemd.services.nixos-pull-on-boot = {
    description = "Pull latest NixOS config and rebuild on boot";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      WorkingDirectory = "/root/nixos-config";
      ExecStart = "${pkgs.git}/bin/git pull";
      ExecStartPost = "${pkgs.nixos-rebuild}/bin/nixos-rebuild switch --flake /root/nixos-config#atom-c3758";
      Environment = "PATH=/run/current-system/sw/bin";
    };
  };
}

