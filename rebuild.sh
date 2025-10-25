#!/bin/sh
cd /root/nixos-config
git pull
nixos-rebuild switch --flake /root/nixos-config#atom-c3758
