{ config, pkgs, ... }:

{
  systemd.services.nixos-pull = {
    description = "Pull latest NixOS config";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      WorkingDirectory = "/root/nixos-config";
      ExecStart = "${pkgs.git}/bin/git pull";
      ExecStartPost = "${pkgs.systemd}/bin/systemctl start nixos-rebuild";
      Environment = "PATH=/run/current-system/sw/bin";
    };
  };

/*  systemd.services.nixos-rebuild = {
    description = "Rebuild and activate NixOS system";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.writeShellScript "rebuild" ''
        set -e
        cd /root/nixos-config
        nix build .#nixosConfigurations.atom-c3758.config.system.build.toplevel --out-link /root/nixos-config/result-system
        /root/nixos-config/result-system/bin/switch-to-configuration switch
      ''}";
      Environment = "PATH=/run/current-system/sw/bin";  
    };
*/
  };
}
