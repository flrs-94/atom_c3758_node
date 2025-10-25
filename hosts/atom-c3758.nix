{ config, pkgs, ... }:

{
# Boot und Kernel Parameter
   system.stateVersion = "25.11";
   boot.loader.systemd-boot.enable = true;
   boot.loader.efi.canTouchEfiVariables = true;
   boot.kernelParams = [
 	"intel_iommu=on"
	"iommu=pt"
	"intel_idle.max_cstate=0"
        "processor.max_cstate=1"
  # optional direktes VFIO-Binding (Vendor:Device IDs)
	"vfio-pci.ids=8086:19e2"
   ];
   boot.initrd.kernelModules = [ 
	"vfio" 
	"vfio_pci" 
	"vfio_iommu_type1"
   ];
   boot.kernelModules = [
	"vfio"
	"vfio_pci"
	"vfio_iommu_type1"
   ];
   boot.blacklistedKernelModules = [ 
	"intel_qat" 
	"qat_c3xxx" 
   ];
   systemd.tmpfiles.rules = [
    "w /sys/bus/pci/devices/0000\:01\:00.0/sriov_numvfs - - - - 4"
   ];

# Hostname & Zeitzone
  networking.hostName = "atom-c3758";
  time.timeZone = "Europe/Berlin";

# Firewall: SSH + Cockpit
  networking.firewall.allowedTCPPorts = [ 22 9090 ];

# Benutzer & Gruppen
  users.users.root.openssh.authorizedKeys.keys = [
  "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC6U/3CxfLatxlEro9deroGI9L23kkMBELlRFO9BdkyKVrKlj0rWKmmSvMAN92yRgaV5hjG3Y5wm9FxWloxhIfZNxs9ca3ez0aegEjbFD+t4qS1so9zfsTuXkT9jsaCngC5QExe/UWU9/AgLR5CGxhMv/67YR+mz7LKs4j3uVkgwHuZY8iVtVUUiJBxEmvyO8zzlO4H1ORzD2RB7LY3phApZc0uNO1FgAQvyYOQOVVTHPGO8y2ad7O3XA/LBe60HGE/LVTwDfBO7FM6gcKau5WnM+jDMCdRz7ESuldDxMz1G33Tl57T9w8aAYn53vQfQWgdsoIBgDl7HZ+KxYNAHubmIG0SA4lXKT497EabJbAbiAm/TzC1gvcQjSg0PRAdrrn93+8dcdNCbAkxB+x7D+NHEgWeUbOY8IJaibsmwc4x19GFloLGOo4yWRP34FsLYs6VFQR+2o9AdI0P1u+NOXEdMPn1z2aKS6Wcp2u+KXCknx7n6PoLIzmYGnzGe7+mJvc= marku@ThinkPad-L390"
  ];
  users.users.flrs = {
    isNormalUser = true;
    extraGroups = [ "wheel" "libvirtd" ];
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC6U/3CxfLatxlEro9deroGI9L23kkMBELlRFO9BdkyKVrKlj0rWKmmSvMAN92yRgaV5hjG3Y5wm9FxWloxhIfZNxs9ca3ez0aegEjbFD+t4qS1so9zfsTuXkT9jsaCngC5QExe/UWU9/AgLR5CGxhMv/67YR+mz7LKs4j3uVkgwHuZY8iVtVUUiJBxEmvyO8zzlO4H1ORzD2RB7LY3phApZc0uNO1FgAQvyYOQOVVTHPGO8y2ad7O3XA/LBe60HGE/LVTwDfBO7FM6gcKau5WnM+jDMCdRz7ESuldDxMz1G33Tl57T9w8aAYn53vQfQWgdsoIBgDl7HZ+KxYNAHubmIG0SA4lXKT497EabJbAbiAm/TzC1gvcQjSg0PRAdrrn93+8dcdNCbAkxB+x7D+NHEgWeUbOY8IJaibsmwc4x19GFloLGOo4yWRP34FsLYs6VFQR+2o9AdI0P1u+NOXEdMPn1z2aKS6Wcp2u+KXCknx7n6PoLIzmYGnzGe7+mJvc= marku@ThinkPad-L390"
    ];
  };

# Flake-Unterstützung
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

# Systempakete
  environment.systemPackages = with pkgs; [
#	driverctl
	nix-prefetch
	s-tui
	qatlib
#	adf-tools
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
        openssl
  ];

# Dienste
  services.openssh = {
      enable = true;
      settings = {
	PermitRootLogin = "yes";
      };
    };
  services.cockpit = {
  enable = true;
  port = 9090;
  settings = {
    WebService = {
      AllowUnencrypted = true;
     };
   };
 };
   systemd.services.qat-sriov-vfs = {
  description = "Create 4 SR-IOV VFs for Intel QAT";
  wantedBy = [ "multi-user.target" ];
  after = [ "systemd-udevd.service" ];
  serviceConfig = {
    Type = "oneshot";
    ExecStart = ''
      /bin/sh -c '
        for i in {1..10}; do
          if [ -e /sys/bus/pci/devices/0000:01:00.0/sriov_totalvfs ]; then
            echo 4 > /sys/bus/pci/devices/0000:01:00.0/sriov_numvfs && exit 0
          fi
          sleep 1
        done
        echo "QAT device not ready for SR-IOV" >&2
        exit 1
      '
    '';
    RemainAfterExit = true;
    CapabilityBoundingSet = [ "CAP_SYS_ADMIN" ];
    AmbientCapabilities = [ "CAP_SYS_ADMIN" ];
    PrivateDevices = false;
    ProtectKernelModules = false;
    ProtectControlGroups = false;
    ProtectKernelTunables = false;
    SystemCallFilter = [ "~write" ];
  };
};
   systemd.services.qat-bind-vfs = {
  description = "Bind QAT VFs to vfio-pci";
  wantedBy = [ "multi-user.target" ];
  after = [ "qat-sriov-vfs.service" ];
  serviceConfig = {
    Type = "oneshot";
    ExecStart = ''
      /bin/sh -c '
        echo vfio-pci > /sys/bus/pci/devices/0000:01:00.1/driver_override
        echo vfio-pci > /sys/bus/pci/devices/0000:01:00.2/driver_override
        echo vfio-pci > /sys/bus/pci/devices/0000:01:00.3/driver_override
        echo vfio-pci > /sys/bus/pci/devices/0000:01:00.4/driver_override
      '
    '';
    RemainAfterExit = true;
    CapabilityBoundingSet = [ "CAP_SYS_ADMIN" ];
    AmbientCapabilities = [ "CAP_SYS_ADMIN" ];
  };
};


/*   systemd.services.qat-sriov-vfs = {
     description = "Create 4 SR-IOV VFs for Intel QAT";
     wantedBy = [ "sysinit.target" ];
     before = [ "sysinit.target" ];
     after = [ "local-fs.target" ];
  serviceConfig = {
    Type = "oneshot";
    ExecStart = ''/bin/sh -c 'echo 4 > /sys/bus/pci/devices/0000\:01\:00.0/sriov_numvfs' '';
    RemainAfterExit = true;
    CapabilityBoundingSet = [ "CAP_SYS_ADMIN" ];
    AmbientCapabilities = [ "CAP_SYS_ADMIN" ];
    PrivateDevices = false;
    ProtectKernelModules = false;
    ProtectControlGroups = false;
    ProtectKernelTunables = false;
    SystemCallFilter = [ "~write" ];
  };
};
   systemd.services.qat-sriov-vfs = {
     description = "Create 4 SR-IOV VFs for Intel QAT";
     wantedBy = [ "multi-user.target" ];
     serviceConfig = {
       Type = "oneshot";
       ExecStart = "/bin/sh -c 'echo 4 > /sys/bus/pci/devices/0000\:01\:00.0/sriov_totalvfs'";
       RemainAfterExit = "yes";
     };
   };
*/
   services.tlp = {
     enable = true;
     settings = {
       CPU_SCALING_GOVERNOR_ON_AC = "performance";
       CPU_SCALING_GOVERNOR_ON_BAT = "performance"; # falls relevant
     };
   };


# libvirt für Virtualisierung
  virtualisation.libvirtd = {
    enable = true;
    qemu.package = pkgs.qemu_kvm;
  };
  security.pam.services.cockpit = {
     allowNullPassword = false;
     rootOK = true; # erlaubt Root-Login via Web-GUI
  };

# Root-Dateisystem
  fileSystems."/" = {
    device = "/dev/nvme1n1p2";
    fsType = "ext4";
  };

# GitOps-Modul einbinden
  imports = [
    ./../modules/gitops.nix
  ];

}

