#!/bin/sh
cd /root/nixos-config
git pull

# Build system to a known path
nix --extra-experimental-features 'nix-command flakes' build .#nixosConfigurations.atom-c3758.config.system.build.toplevel --out-link /root/nixos-config/result-system

# Activate directly, bypassing nixos-rebuild and systemd-run
/root/nixos-config/result-system/bin/switch-to-configuration switch
