
{ config, pkgs, ... }:
{
# Host-Konfiguration für atom-c3758
#
# ============================================================================
# WICHTIG: SSH-Key für Remote-Zugriff - NICHT LÖSCHEN!
# Dieser Key ermöglicht SSH-Zugriff als root von marku@ThinkPad-L390
# ============================================================================
users.users.root.openssh.authorizedKeys.keys = [
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC6U/3CxfLatxlEro9deroGI9L23kkMBELlRFO9BdkyKVrKlj0rWKmmSvMAN92yRgaV5hjG3Y5wm9FxWloxhIfZNxs9ca3ez0aegEjbFD+t4qS1so9zfsTuXkT9jsaCngC5QExe/UWU9/AgLR5CGxhMv/67YR+mz7LKs4j3uVkgwHuZY8iVtVUUiJBxEmvyO8zzlO4H1ORzD2RB7LY3phApZc0uNO1FgAQvyYOQOVVTHPGO8y2ad7O3XA/LBe60HGE/LVTwDfBO7FM6gcKau5WnM+jDMCdRz7ESuldDxMz1G33Tl57T9w8aAYn53vQfQWgdsoIBgDl7HZ+KxYNAHubmIG0SA4lXKT497EabJbAbiAm/TzC1gvcQjSg0PRAdrrn93+8dcdNCbAkxB+x7D+NHEgWeUbOY8IJaibsmwc4x19GFloLGOo4yWRP34FsLYs6VFQR+2o9AdI0P1u+NOXEdMPn1z2aKS6Wcp2u+KXCknx7n6PoLIzmYGnzGe7+mJvc= marku@ThinkPad-L390"
  ];
# ============================================================================
environment.systemPackages = with pkgs; [
    gcc
    nix-prefetch
    s-tui
    qatlib
    htop
    powertop
    pciutils
    ethtool
    hwinfo
    usbutils
    git
    openssh
    cockpit
    virt-manager
    gnutls
    curl
    bash
    gnugrep
    coreutils
    glibc
    openssl
  ];

services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "yes";
    };
  };


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
  # Intel QAT SR-IOV Konfiguration (über qat-sriov Overlay)
  #
  systemd.services.qat-setup = {
    description = "Setup Intel QAT with SR-IOV (4 VFs: 2 Host, 2 VM)";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-modules-load.service" ];
    path = [ pkgs.kmod pkgs.pciutils pkgs.coreutils ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.qat-sriov-setup}/bin/qat-sriov-setup";
    };
  };
}
