{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.qat-sriov;
in
{
  options.services.qat-sriov = {
    enable = mkEnableOption "Intel QAT SR-IOV VF setup";

    pciAddress = mkOption {
      type = types.str;
      default = "0000:01:00.0";
      description = "PCI address of the QAT Physical Function (PF)";
      example = "0000:01:00.0";
    };

    numVFs = mkOption {
      type = types.int;
      default = 4;
      description = "Number of Virtual Functions (VFs) to create";
    };

    hostVFs = mkOption {
      type = types.listOf types.int;
      default = [ 0 1 ];
      description = "VF indices to bind to c3xxxvf driver (for host usage)";
      example = [ 0 1 ];
    };

    vmVFs = mkOption {
      type = types.listOf types.int;
      default = [ 2 3 ];
      description = "VF indices to bind to vfio-pci driver (for VM passthrough)";
      example = [ 2 3 ];
    };
  };

  config = mkIf cfg.enable {
    # Stelle sicher dass benötigte Kernel-Module geladen werden
    boot.kernelModules = [ "qat_c3xxx" "qat_c3xxxvf" "vfio-pci" ];

    # Systemd-Service für VF-Setup
    systemd.services.qat-sriov-setup = {
      description = "Intel QAT SR-IOV VF Setup (${toString cfg.numVFs} VFs: ${toString (length cfg.hostVFs)} Host, ${toString (length cfg.vmVFs)} VM)";
      wantedBy = [ "multi-user.target" ];
      after = [ "systemd-modules-load.service" ];
      
      path = with pkgs; [ kmod pciutils coreutils ];
      
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

      script = ''
        set -e
        PF="${cfg.pciAddress}"
        
        echo "[QAT SR-IOV] Starting setup for PF $PF..."
        
        # 1. Prüfe ob PF existiert
        if [ ! -e "/sys/bus/pci/devices/$PF" ]; then
          echo "[QAT SR-IOV] ERROR: PF device $PF not found"
          exit 1
        fi
        
        # 2. Warte auf qat_c3xxx Modul
        for i in {1..10}; do
          if lsmod | grep -q "^qat_c3xxx"; then
            echo "[QAT SR-IOV] qat_c3xxx module loaded"
            break
          fi
          echo "[QAT SR-IOV] Waiting for qat_c3xxx module... ($i/10)"
          sleep 1
        done
        
        if ! lsmod | grep -q "^qat_c3xxx"; then
          echo "[QAT SR-IOV] ERROR: qat_c3xxx module not loaded"
          exit 1
        fi
        
        # 3. Binde PF an c3xxx (falls nicht schon gebunden)
        if [ ! -e "/sys/bus/pci/devices/$PF/driver" ]; then
          echo "[QAT SR-IOV] Binding PF to c3xxx..."
          echo "$PF" > /sys/bus/pci/drivers/c3xxx/bind 2>/dev/null || true
          sleep 1
        fi
        
        PF_DRV=$(readlink /sys/bus/pci/devices/$PF/driver 2>/dev/null | xargs basename 2>/dev/null || echo "none")
        echo "[QAT SR-IOV] PF driver: $PF_DRV"
        
        # 4. Erstelle VFs
        echo "[QAT SR-IOV] Creating ${toString cfg.numVFs} VFs..."
        echo 0 > /sys/bus/pci/devices/$PF/sriov_numvfs 2>/dev/null || true
        sleep 1
        echo ${toString cfg.numVFs} > /sys/bus/pci/devices/$PF/sriov_numvfs
        sleep 2
        
        VF_COUNT=$(cat /sys/bus/pci/devices/$PF/sriov_numvfs)
        echo "[QAT SR-IOV] VFs created: $VF_COUNT"
        
        ${optionalString (cfg.hostVFs != []) ''
        # 5. Binde Host-VFs an c3xxxvf
        for i in ${concatStringsSep " " (map toString cfg.hostVFs)}; do
          vf_path="/sys/bus/pci/devices/$PF/virtfn$i"
          if [ ! -e "$vf_path" ]; then
            echo "[QAT SR-IOV] WARNING: VF$i not found, skipping"
            continue
          fi
          vf_addr=$(basename $(readlink -f $vf_path))
          echo "[QAT SR-IOV] Binding VF$i ($vf_addr) to c3xxxvf (Host)..."
          echo "c3xxxvf" > $vf_path/driver_override
          echo "$vf_addr" > /sys/bus/pci/drivers/c3xxxvf/bind 2>/dev/null || echo "[QAT SR-IOV]   -> already bound"
        done
        ''}
        
        ${optionalString (cfg.vmVFs != []) ''
        # 6. Binde VM-VFs an vfio-pci
        for i in ${concatStringsSep " " (map toString cfg.vmVFs)}; do
          vf_path="/sys/bus/pci/devices/$PF/virtfn$i"
          if [ ! -e "$vf_path" ]; then
            echo "[QAT SR-IOV] WARNING: VF$i not found, skipping"
            continue
          fi
          vf_addr=$(basename $(readlink -f $vf_path))
          echo "[QAT SR-IOV] Binding VF$i ($vf_addr) to vfio-pci (VM)..."
          echo "vfio-pci" > $vf_path/driver_override
          echo "$vf_addr" > /sys/bus/pci/drivers/vfio-pci/bind 2>/dev/null || echo "[QAT SR-IOV]   -> already bound"
        done
        ''}
        
        # 7. Status ausgeben
        echo "[QAT SR-IOV] Final status:"
        echo "  PF Driver: $(readlink /sys/bus/pci/devices/$PF/driver 2>/dev/null | xargs basename || echo none)"
        echo "  VF Count: $(cat /sys/bus/pci/devices/$PF/sriov_numvfs)"
        echo "  VF Bindings:"
        for i in $(seq 0 $((VF_COUNT - 1))); do
          vf_path="/sys/bus/pci/devices/$PF/virtfn$i"
          [ -e "$vf_path" ] || continue
          vf_addr=$(basename $(readlink -f $vf_path))
          vf_drv=$(readlink $vf_path/driver 2>/dev/null | xargs basename 2>/dev/null || echo "none")
          echo "    VF$i $vf_addr -> $vf_drv"
        done
        
        echo "[QAT SR-IOV] Setup completed successfully"
      '';
    };
  };
}
