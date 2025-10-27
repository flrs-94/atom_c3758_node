
{ config, pkgs, ... }:
{

# Host-Konfiguration für atom-c3758
#
  #
  # System Version und Basis-Konfiguration
  #
  system.stateVersion = "25.11";

  #
  # Boot und UEFI Konfiguration
  #
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  #
  # Intel QAT und IOMMU Konfiguration
  # - Aktiviert IOMMU für SR-IOV
  # - Setzt CPU C-States für bessere Latenz
  # - Konfiguriert VFIO für QAT VFs
  #
  boot.kernelParams = [
    "intel_iommu=on"         # Aktiviert IOMMU für Intel-Plattformen
    "iommu=pt"               # Passthrough-Modus für nicht-VFIO-Geräte
    "intel_idle.max_cstate=0" # Optional: verhindert tiefe C-States
    "processor.max_cstate=1"  # Optional: reduziert CPU-Schlafzustände
  # VFIO auto-binding disabled here; wir binden gezielt via sysfs in `qat-setup`
  # (früher: "vfio-pci.ids=8086:19e3")
    "pci=realloc"            # Erlaubt PCI Resource Reallocation
    "vfio-pci.disable_denylist=1" # Erlaubt vfio-pci-Bindings für Geräte auf der Kernel-Denylist (u.a. QAT VFs)
  ];

  #
  # Kernel Module Konfiguration
  # - VFIO Module für PCI Passthrough
  # - Intel QAT Treiber (PF und VF)
  #
  boot.initrd.kernelModules = [
    "vfio"
    "vfio_pci"
    "vfio_iommu_type1"
    "intel_qat"
    "qat_c3xxx"
    "qat_c3xxxvf"
  ];

  boot.kernelModules = [
    # VFIO Module
    "vfio"
    "vfio_pci"
    "vfio_iommu_type1"
    
    # QAT Module
    "intel_qat"
    "qat_c3xxx"
    "qat_c3xxxvf"
    
    # Userspace I/O
    "uio"
    "uio_pci_generic"
  ];

  boot.blacklistedKernelModules = [ ];

  # QAT Firmware: minimal, aus dem Repo vendored (kleiner als linux-firmware)
  hardware.firmware = [ pkgs.qat-firmware ];

  #
  # Netzwerk und Systemeinstellungen
  #
  networking.hostName = "atom-c3758";
  time.timeZone = "Europe/Berlin";
  
  # Firewall: SSH, Cockpit und VNC
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 9090 ] ++ (pkgs.lib.range 5900 5910);
  };

  # Journald klein halten, damit / nicht vollläuft
  services.journald.extraConfig = ''
    SystemMaxUse=64M
    RuntimeMaxUse=64M
    MaxFileSec=1day
  '';

  #
  # Dateisystem und Storage
  #
  fileSystems."/" = {
    device = "/dev/nvme1n1p2";
    fsType = "ext4";
  };

  #
  # GitOps Integration und Management
  #
  imports = [
    ./../modules/gitops.nix
    ./../modules/vscode-server.nix
    ./../modules/cockpit.nix
  ];

  #
  # Intel QAT SR-IOV Konfiguration (systemd qat-setup Unit, garantiert im config-Set)
  #
  systemd.services.qat-setup = {
    description = "Setup Intel QAT with SR-IOV";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-modules-load.service" ];
    path = [ pkgs.kmod pkgs.pciutils ];
    script = ''
      sleep 2
      
      # Bind PF to c3xxx driver first
      if [ ! -e /sys/bus/pci/devices/0000:01:00.0/driver ]; then
        echo "Binding PF to c3xxx driver..."
        echo 0000:01:00.0 > /sys/bus/pci/drivers/c3xxx/bind || true
        sleep 2
      fi
      
      # Enable PCI bus mastering
      setpci -s 01:00.0 COMMAND=0x06
      
      # Create VFs and bind them using virtfn symlinks (die VF-BDFs sind nicht 01:00.x)
      for i in $(seq 1 15); do
        PF=/sys/bus/pci/devices/0000:01:00.0
        if [ -e "$PF/sriov_numvfs" ]; then
          # Deaktivieren, dann Wunschzahl setzen (Kernel kann auf max. VFs runden)
          echo 0 > "$PF/sriov_numvfs" || true
          sleep 1
          echo 4 > "$PF/sriov_numvfs" || true
          sleep 2

          # Autoprobe aus, wir binden gezielt
          if [ -w "$PF/sriov_drivers_autoprobe" ]; then
            echo 0 > "$PF/sriov_drivers_autoprobe" || true
          fi

          # Sammle die ersten 4 VF-Pfade aus virtfn{0..3}
          VF0=$(readlink -f "$PF/virtfn0") || true
          VF1=$(readlink -f "$PF/virtfn1") || true
          VF2=$(readlink -f "$PF/virtfn2") || true
          VF3=$(readlink -f "$PF/virtfn3") || true

          for vf in "$VF0" "$VF1" "$VF2" "$VF3"; do
            [ -n "$vf" ] || continue
            # Setze gezielt die gewünschte Treiberbindung
            case "$vf" in
              "$VF0"|"$VF1") echo c3xxxvf > "$vf/driver_override" ;;   # Host
              "$VF2"|"$VF3") echo vfio-pci > "$vf/driver_override" ;; # VM Passthrough
            esac
            # ggf. bestehenden Treiber lösen
            if [ -e "$vf/driver" ]; then
              echo "$(basename "$vf")" > "$vf/driver/unbind" || true
            fi
          done

          # Treiber binden: Host-VFs an c3xxxvf, VM-VFs an vfio-pci
          for bdf in $(basename "$VF0") $(basename "$VF1"); do
            [ -n "$bdf" ] || continue
            echo "$bdf" > /sys/bus/pci/drivers/c3xxxvf/bind || true
          done
          for bdf in $(basename "$VF2") $(basename "$VF3"); do
            [ -n "$bdf" ] || continue
            echo "$bdf" > /sys/bus/pci/drivers/vfio-pci/bind || true
          done

          # Debug-Ausgabe
          for vf in "$VF0" "$VF1" "$VF2" "$VF3"; do
            [ -n "$vf" ] || continue
            drv="-"; [ -e "$vf/driver" ] && drv=$(basename "$(readlink "$vf/driver")")
            echo "$(basename "$vf") -> driver=$drv override=$(cat "$vf/driver_override")"
          done

          exit 0
        fi
        sleep 1
      done
      echo "QAT device not ready" >&2
      exit 1
    '';
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      CapabilityBoundingSet = "CAP_SYS_ADMIN";
      AmbientCapabilities = "CAP_SYS_ADMIN";
    };
  };
}
