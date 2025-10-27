#!/bin/sh
set -e  # Exit on error

cd /root/nixos-config
git pull

# Build system to a known path
echo "[rebuild.sh] Building NixOS configuration..."
nix --extra-experimental-features 'nix-command flakes' build .#nixosConfigurations.atom-c3758.config.system.build.toplevel --out-link /root/nixos-config/result-system

# Activate directly, bypassing nixos-rebuild and systemd-run
echo "[rebuild.sh] Activating new configuration..."
/root/nixos-config/result-system/bin/switch-to-configuration switch

# Update boot entries automatically (neueste Generation als Default, letzte 3 behalten)
echo "[rebuild.sh] Updating boot entries..."
/root/nixos-config/update-boot.sh

# Push changes to remote if rebuild was successful
echo "[rebuild.sh] Pushing changes to remote repository..."
if git push origin main; then
  echo "[rebuild.sh] ✓ Changes pushed successfully"
else
  echo "[rebuild.sh] ✗ Warning: Failed to push changes to remote (continuing anyway)"
fi

echo "[rebuild.sh] ✓ Rebuild completed successfully"
