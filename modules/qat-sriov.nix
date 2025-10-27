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
      description = ''
        Number of Virtual Functions (VFs) to create.
        
        Note: Intel QAT C3xxx hardware creates 16 VFs when SR-IOV is enabled,
        regardless of the numVFs setting. This option controls how many VFs
        are configured for use (hostVFs + vmVFs should not exceed this number).
        The remaining VFs will be created but left unbound.
      '';
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
        
        # 4. Erstelle VFs deterministisch (erst deaktivieren, dann aktivieren)
        echo "[QAT SR-IOV] Resetting VFs to 0..."
        echo 0 > /sys/bus/pci/devices/$PF/sriov_numvfs 2>/dev/null || true
        sleep 2
        
        echo "[QAT SR-IOV] Creating ${toString cfg.numVFs} VFs..."
        echo ${toString cfg.numVFs} > /sys/bus/pci/devices/$PF/sriov_numvfs
        sleep 3
        
        VF_COUNT=$(cat /sys/bus/pci/devices/$PF/sriov_numvfs)
        echo "[QAT SR-IOV] VFs created: $VF_COUNT"
        
        # Note: Intel QAT C3xxx creates 16 VFs in hardware regardless of numVFs setting
        # We configure only the specified number (hostVFs + vmVFs)
        if [ "$VF_COUNT" != "${toString cfg.numVFs}" ]; then
          echo "[QAT SR-IOV] Note: Hardware created $VF_COUNT VFs (expected ${toString cfg.numVFs})"
          echo "[QAT SR-IOV]       This is normal for QAT C3xxx - only configured VFs will be bound to drivers"
        fi
        
        ${optionalString (cfg.hostVFs != []) ''
        # 5. Binde Host-VFs an c3xxxvf
        for i in ${concatStringsSep " " (map toString cfg.hostVFs)}; do
          vf_path="/sys/bus/pci/devices/$PF/virtfn$i"
          if [ ! -e "$vf_path" ]; then
            echo "[QAT SR-IOV] WARNING: VF$i not found, skipping"
            continue
          fi
          vf_addr=$(basename $(readlink -f $vf_path))
          
          # Unbind von vorherigem Treiber falls vorhanden
          if [ -e "/sys/bus/pci/devices/$vf_addr/driver" ]; then
            old_drv=$(readlink /sys/bus/pci/devices/$vf_addr/driver | xargs basename)
            if [ "$old_drv" != "c3xxxvf" ]; then
              echo "[QAT SR-IOV] VF$i ($vf_addr): Unbinding from $old_drv..."
              echo "$vf_addr" > /sys/bus/pci/devices/$vf_addr/driver/unbind 2>/dev/null || true
              sleep 0.5
            fi
          fi
          
          echo "[QAT SR-IOV] Binding VF$i ($vf_addr) to c3xxxvf (Host)..."
          echo "c3xxxvf" > /sys/bus/pci/devices/$vf_addr/driver_override
          echo "$vf_addr" > /sys/bus/pci/drivers/c3xxxvf/bind 2>/dev/null || echo "[QAT SR-IOV]   -> already bound"
        done
        ''}
        
        ${optionalString (cfg.vmVFs != []) ''
        # 6. Binde VM-VFs an vfio-pci (mit force unbind)
        for i in ${concatStringsSep " " (map toString cfg.vmVFs)}; do
          vf_path="/sys/bus/pci/devices/$PF/virtfn$i"
          if [ ! -e "$vf_path" ]; then
            echo "[QAT SR-IOV] WARNING: VF$i not found, skipping"
            continue
          fi
          vf_addr=$(basename $(readlink -f $vf_path))
          
          # Force unbind von vorherigem Treiber falls vorhanden
          if [ -e "/sys/bus/pci/devices/$vf_addr/driver" ]; then
            old_drv=$(readlink /sys/bus/pci/devices/$vf_addr/driver | xargs basename)
            echo "[QAT SR-IOV] VF$i ($vf_addr): Unbinding from $old_drv..."
            echo "$vf_addr" > /sys/bus/pci/devices/$vf_addr/driver/unbind 2>/dev/null || true
            sleep 0.5
          fi
          
          echo "[QAT SR-IOV] Binding VF$i ($vf_addr) to vfio-pci (VM)..."
          echo "vfio-pci" > /sys/bus/pci/devices/$vf_addr/driver_override
          
          # Retry-Logik für vfio-pci bind (manchmal braucht es mehrere Versuche)
          for attempt in {1..3}; do
            if echo "$vf_addr" > /sys/bus/pci/drivers/vfio-pci/bind 2>/dev/null; then
              echo "[QAT SR-IOV]   -> bound successfully"
              break
            else
              if [ $attempt -lt 3 ]; then
                echo "[QAT SR-IOV]   -> bind attempt $attempt failed, retrying..."
                sleep 1
              else
                echo "[QAT SR-IOV]   -> ERROR: bind failed after 3 attempts"
              fi
            fi
          done
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
