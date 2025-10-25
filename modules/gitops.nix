{ config, pkgs, ... }:

{
  systemd.services.nixos-pull-on-boot = {
    description = "Pull latest NixOS config and rebuild on boot";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "/root/nixos-config/rebuild.sh";
      Environment = "PATH=/run/current-system/sw/bin";
    };
  };
}
