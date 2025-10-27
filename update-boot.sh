#!/usr/bin/env bash
set -e

# Automatisches Boot-Entry Management für NixOS
# Erstellt Boot-Eintrag für die neueste Generation und behält nur die letzten 3

BOOT_DIR="/boot/loader/entries"
LOADER_CONF="/boot/loader/loader.conf"

# Finde die neueste System-Generation
SYSTEM_LINK=$(readlink -f /run/current-system)
echo "[Boot-Update] Aktuelles System: $SYSTEM_LINK"

# Extrahiere Generation-Nummer aus dem Profile-Link (sortiere numerisch)
LATEST_GEN=$(ls /nix/var/nix/profiles/system-*-link 2>/dev/null | grep -oP '/system-\K[0-9]+(?=-link)' | sort -n | tail -n 1)
if [ -z "$LATEST_GEN" ]; then
    echo "[Boot-Update] FEHLER: Keine System-Generationen gefunden"
    exit 1
fi
echo "[Boot-Update] Neueste Generation: $LATEST_GEN"

# Extrahiere Kernel und Initrd Pfade aus der aktuellen Generation
INIT_PATH=$(readlink -f /nix/var/nix/profiles/system-${LATEST_GEN}-link/init)
SYSTEM_PATH=$(dirname "$INIT_PATH")

# Finde Kernel und Initrd (sie sind Symlinks direkt im Generation-Verzeichnis)
KERNEL_LINK="/nix/var/nix/profiles/system-${LATEST_GEN}-link/kernel"
INITRD_LINK="/nix/var/nix/profiles/system-${LATEST_GEN}-link/initrd"

if [ ! -L "$KERNEL_LINK" ] || [ ! -L "$INITRD_LINK" ]; then
    echo "[Boot-Update] FEHLER: Kernel oder Initrd Links nicht gefunden in Generation $LATEST_GEN"
    exit 1
fi

# Folge den Symlinks und extrahiere die tatsächlichen Dateipfade
KERNEL_PATH=$(readlink -f "$KERNEL_LINK")
INITRD_PATH=$(readlink -f "$INITRD_LINK")

# Extrahiere nur den Hash-basierten Dateinamen (mit Nix-Store-Hash für Eindeutigkeit)
KERNEL_HASH=$(basename $(dirname "$KERNEL_PATH"))
INITRD_HASH=$(basename $(dirname "$INITRD_PATH"))
KERNEL_FILE="/kernels/${KERNEL_HASH}-bzImage"
INITRD_FILE="/kernels/${INITRD_HASH}-initrd"

# Kopiere Kernel und Initrd nach /boot/kernels (falls noch nicht vorhanden)
mkdir -p /boot/kernels
if [ ! -f "/boot${KERNEL_FILE}" ]; then
    echo "[Boot-Update] Kopiere Kernel nach /boot${KERNEL_FILE}"
    cp "$KERNEL_PATH" "/boot${KERNEL_FILE}"
fi
if [ ! -f "/boot${INITRD_FILE}" ]; then
    echo "[Boot-Update] Kopiere Initrd nach /boot${INITRD_FILE}"
    cp "$INITRD_PATH" "/boot${INITRD_FILE}"
fi

# Kernel-Parameter aus der aktuellen Konfiguration
KERNEL_PARAMS="intel_iommu=on iommu=pt intel_idle.max_cstate=0 processor.max_cstate=1 pci=realloc vfio-pci.disable_denylist=1"

# Erstelle Boot-Eintrag für die neueste Generation
BOOT_ENTRY="${BOOT_DIR}/nixos-generation-${LATEST_GEN}.conf"
echo "[Boot-Update] Erstelle Boot-Eintrag: $BOOT_ENTRY"

cat > "$BOOT_ENTRY" << EOF
title NixOS Generation ${LATEST_GEN}
version Generation ${LATEST_GEN}
linux ${KERNEL_FILE}
initrd ${INITRD_FILE}
options init=${SYSTEM_PATH}/init ${KERNEL_PARAMS}
EOF

# Setze die neueste Generation als Default
echo "[Boot-Update] Setze Generation ${LATEST_GEN} als Default"
cat > "$LOADER_CONF" << EOF
timeout 5
default nixos-generation-${LATEST_GEN}.conf
EOF

# Behalte nur die letzten 3 Generationen
echo "[Boot-Update] Bereinige alte Boot-Einträge (behalte letzten 3)"
ls ${BOOT_DIR}/nixos-generation-*.conf 2>/dev/null | grep -oP 'generation-\K[0-9]+(?=\.conf)' | sort -n | head -n -3 | while read gen_num; do
    old_entry="${BOOT_DIR}/nixos-generation-${gen_num}.conf"
    if [ -f "$old_entry" ]; then
        echo "[Boot-Update]   Entferne: $(basename "$old_entry")"
        rm -f "$old_entry"
    fi
done

# Bereinige alte Kernel/Initrd-Dateien (optional, nur wenn nicht mehr referenziert)
echo "[Boot-Update] Bereinige ungenutzte Kernel/Initrd-Dateien"
USED_FILES=$(grep -h "^linux\|^initrd" ${BOOT_DIR}/nixos-generation-*.conf 2>/dev/null | awk '{print $2}' | sort -u)
for kernel_file in /boot/kernels/*; do
    kernel_basename="/kernels/$(basename "$kernel_file")"
    if ! echo "$USED_FILES" | grep -q "^${kernel_basename}$"; then
        echo "[Boot-Update]   Entferne ungenutztes File: $(basename "$kernel_file")"
        rm -f "$kernel_file"
    fi
done

echo "[Boot-Update] Fertig! Aktuelle Boot-Einträge:"
ls -1 ${BOOT_DIR}/nixos-generation-*.conf | while read entry; do
    gen_num=$(basename "$entry" | grep -oP 'generation-\K[0-9]+')
    is_default=""
    if [ "nixos-generation-${gen_num}.conf" = "$(grep '^default' $LOADER_CONF | awk '{print $2}')" ]; then
        is_default=" [DEFAULT]"
    fi
    echo "  Generation ${gen_num}${is_default}"
done
