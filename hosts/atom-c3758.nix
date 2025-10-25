{ config, pkgs, ... }:

{
# Boot und Kernel Parameter
  system.stateVersion = "25.11";
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelParams = [
 	"intel_iommu=on"
	"iommu=pt"
  # optional direktes VFIO-Binding (Vendor:Device IDs)
  # "vfio-pci.ids=8086:10fb,8086:10ed"
  ];
  boot.initrd.kernelModules = [ 
	"vfio"
	"vfio_pci"
	"vfio_iommu_type1"
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
  serviceConfig = {
    Type = "oneshot";
    ExecStart = "/bin/sh -c 'echo 4 > /sys/bus/pci/devices/0000\:01\:00.0/sriov_totalvfs'";
    RemainAfterExit = "yes";
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

