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
      Environment = "PATH=/run/current-system/sw/bin";
    };
  };
}
