#!/bin/sh
cd /root/nixos-config
git pull
nix build --no-lock-file .#nixosConfigurations.atom-c3758.config.system.build.toplevel
./result/bin/switch-to-configuration switch
