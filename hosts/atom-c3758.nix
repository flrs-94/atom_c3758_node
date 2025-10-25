{ config, pkgs, ... }:

{
  # Hostname & Zeitzone
  networking.hostName = "atom-c3758";
  time.timeZone = "Europe/Berlin";

  # Firewall: SSH + Cockpit

  networking.firewall.allowedTCPPorts = [ 22 9090 ];

  # Benutzer & Gruppen
  users.users.flores = {
    isNormalUser = true;
    extraGroups = [ "wheel" "libvirtd" ];
  };

  # Flake-Unterstützung
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Systempakete
  environment.systemPackages = with pkgs; [
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
	PasswordAuthentication = true;
      };
    };

  services.cockpit = {
  enable = true;
  settings = {
    WebService = {
      AllowUnencrypted = true;
     };
   };
 };


  # Cockpit-Erweiterung für VM-Verwaltung
 /* services.cockpit.packages = with pkgs; [ cockpit-machines ]; */

  # libvirt für Virtualisierung
  virtualisation.libvirtd = {
    enable = true;
    qemu.package = pkgs.qemu_kvm;
  };

  # Bootloader (UEFI)
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Root-Dateisystem
  fileSystems."/" = {
    device = "/dev/nvme1n1p2";
    fsType = "ext4";
  };

  # GitOps-Modul einbinden
  imports = [
    ./../modules/gitops.nix
  ];

  # system.stateVersion setzen
  system.stateVersion = "25.11";
}


/*{ config, pkgs, ... }:

{
  # Hostname und Zeitzone
  networking.hostName = "atom-c3758";
  time.timeZone = "Europe/Berlin";
  
  # Network & Firewall
  networking.firewall.allowedTCPPorts = [ 22, 9090 ];

  # User & Groups
  users.users.flores.extraGroups = [ "libvirtd" ];

  # Flake-Unterstützung
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Systempakete inkl. git + ssh
  environment.systemPackages = with pkgs; [
    git
    openssh
    cockpit
    cockpit-machines
    virt-manager
  ];

  # Services
  virtualisation.libvirtd.enable = true;
  services.openssh.enable = true;
  services.cockpit.enable = true;

  # Bootloader (UEFI)
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Root-Dateisystem
  fileSystems."/" = {
    device = "/dev/nvme1n1p2";
    fsType = "ext4";
  };

  # GitOps-Modul einbinden
  imports = [
    ./../modules/gitops.nix
  ];

  # system.stateVersion setzen
  system.stateVersion = "25.11";
}
*/
