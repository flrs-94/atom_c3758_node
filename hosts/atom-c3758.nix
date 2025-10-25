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
# modprobe Optionen
  environment.etc."modprobe.d/99-qat.conf".text = ''
  options qat_c3xxx max_vfs=4
  '';
# Hostname & Zeitzone
  networking.hostName = "atom-c3758";
  time.timeZone = "Europe/Berlin";

# Firewall: SSH + Cockpit
  networking.firewall.allowedTCPPorts = [ 22 9090 ];

# Benutzer & Gruppen
  users.users.root.openssh.authorizedKeys.keys = [
  "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC6U/3CxfLatxlEro9deroGI9L23kkMBELlRFO9BdkyKVrKlj0rWKmmSvMAN92yRgaV5hjG3Y5wm>
  ];
  users.users.flrs = {
    isNormalUser = true;
    extraGroups = [ "wheel" "libvirtd" ];
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC6U/3CxfLatxlEro9deroGI9L23kkMBELlRFO9BdkyKVrKlj0rWKmmSvMAN92yRgaV5hjG3>
    ];
  };

# Flake-Unterstützung
>>>>>>> refs/remotes/origin/main
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

# Systempakete
  environment.systemPackages = with pkgs; [

	s-tui
	qatlib
	adf-tools
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

