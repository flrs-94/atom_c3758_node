final: prev: {
  # Intel QAT SR-IOV VF Setup
  # Dieses Overlay stellt einen systemd-Service bereit, der beim Boot:
  # - qat_c3xxx Modul lädt (PF-Treiber)
  # - 4 VFs erstellt
  # - VF0+VF1 an c3xxxvf bindet (Host)
  # - VF2+VF3 an vfio-pci bindet (VM-Passthrough)

  qat-sriov-setup = prev.writeShellScriptBin "qat-sriov-setup" ''
    set -e
    PF="0000:01:00.0"
    
    echo "[QAT SR-IOV Setup] Starting..."
    
    # 1. Lade qat_c3xxx Modul (PF-Treiber)
    if ! lsmod | grep -q "^qat_c3xxx"; then
      echo "[QAT SR-IOV Setup] Loading qat_c3xxx module..."
      ${prev.kmod}/bin/modprobe qat_c3xxx
      sleep 2
    fi
    
    # 2. Prüfe ob PF existiert
    if [ ! -e "/sys/bus/pci/devices/$PF" ]; then
      echo "[QAT SR-IOV Setup] ERROR: PF device $PF not found"
      exit 1
    fi
    
    # 3. Binde PF an c3xxx (falls nicht schon gebunden)
    if [ ! -e "/sys/bus/pci/devices/$PF/driver" ]; then
      echo "[QAT SR-IOV Setup] Binding PF to c3xxx..."
      echo "$PF" > /sys/bus/pci/drivers/c3xxx/bind 2>/dev/null || true
      sleep 1
    fi
    
    # 4. Erstelle 4 VFs (Driver erstellt automatisch 16, wir akzeptieren das)
    echo "[QAT SR-IOV Setup] Creating 4 VFs..."
    echo 0 > /sys/bus/pci/devices/$PF/sriov_numvfs 2>/dev/null || true
    sleep 1
    echo 4 > /sys/bus/pci/devices/$PF/sriov_numvfs
    sleep 2
    
    VF_COUNT=$(cat /sys/bus/pci/devices/$PF/sriov_numvfs)
    echo "[QAT SR-IOV Setup] VFs created: $VF_COUNT"
    
    # 5. Binde VF0, VF1 an c3xxxvf (Host)
    for i in 0 1; do
      vf_path="/sys/bus/pci/devices/$PF/virtfn$i"
      if [ ! -e "$vf_path" ]; then
        echo "[QAT SR-IOV Setup] WARNING: VF$i not found, skipping"
        continue
      fi
      vf_addr=$(basename $(readlink -f $vf_path))
      echo "[QAT SR-IOV Setup] Binding VF$i ($vf_addr) to c3xxxvf (Host)..."
      echo "c3xxxvf" > $vf_path/driver_override
      echo "$vf_addr" > /sys/bus/pci/drivers/c3xxxvf/bind 2>/dev/null || echo "[QAT SR-IOV Setup]   -> already bound"
    done
    
    # 6. Binde VF2, VF3 an vfio-pci (VMs)
    for i in 2 3; do
      vf_path="/sys/bus/pci/devices/$PF/virtfn$i"
      if [ ! -e "$vf_path" ]; then
        echo "[QAT SR-IOV Setup] WARNING: VF$i not found, skipping"
        continue
      fi
      vf_addr=$(basename $(readlink -f $vf_path))
      echo "[QAT SR-IOV Setup] Binding VF$i ($vf_addr) to vfio-pci (VM)..."
      echo "vfio-pci" > $vf_path/driver_override
      echo "$vf_addr" > /sys/bus/pci/drivers/vfio-pci/bind 2>/dev/null || echo "[QAT SR-IOV Setup]   -> already bound"
    done
    
    # 7. Status ausgeben
    echo "[QAT SR-IOV Setup] Final status:"
    echo "  PF Driver: $(readlink /sys/bus/pci/devices/$PF/driver 2>/dev/null | xargs basename || echo none)"
    echo "  VF Count: $(cat /sys/bus/pci/devices/$PF/sriov_numvfs)"
    echo "  VF Bindings:"
    for i in 0 1 2 3; do
      vf_path="/sys/bus/pci/devices/$PF/virtfn$i"
      [ -e "$vf_path" ] || continue
      vf_addr=$(basename $(readlink -f $vf_path))
      vf_drv=$(readlink $vf_path/driver 2>/dev/null | xargs basename 2>/dev/null || echo "none")
      echo "    VF$i $vf_addr -> $vf_drv"
    done
    
    echo "[QAT SR-IOV Setup] Completed successfully"
  '';
}
