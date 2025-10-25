{ config, pkgs, ... }:

{
  # Hostname & Zeitzone
  networking.hostName = "atom-c3758";
  time.timeZone = "Europe/Berlin";

  # Firewall: SSH + Cockpit

  networking.firewall.allowedTCPPorts = [ 22 9090 ];

  # Benutzer & Gruppen
  users.users.root.openssh.authorizedKeys.keys = [
  "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC6U/3CxfLatxlEro9deroGI9L23kkMBELlRFO9BdkyKVrKlj0rWKmmSvMAN92yRgaV5hjG3Y5wm9FxWloxhIfZNxs9ca3ez0aegEjbFD+t4qS1so9zfsTuXkT9jsaCngC5QExe/UWU9/AgLR5CGxhMv/67YR+mz7LKs4j3uVkgwHuZY8iVtVUUiJBxEmvyO8zzlO4H1ORzD2RB7LY3phApZc0uNO1FgAQvyYOQOVVTHPGO8y2ad7O3XA/LBe60HGE/LVTwDfBO7FM6gcKau5WnM+jDMCdRz7ESuldDxMz1G33Tl57T9w8aAYn53vQfQWgdsoIBgDl7HZ+KxYNAHubmIG0SA4lXKT497EabJbAbiAm/TzC1gvcQjSg0PRAdrrn93+8dcdNCbAkxB+x7D+NHEgWeUbOY8IJaibsmwc4x19GFloLGOo4yWRP34FsLYs6VFQR+2o9AdI0P1u+NOXEdMPn1z2aKS6Wcp2u+KXCknx7n6PoLIzmYGnzGe7+mJvc= marku@ThinkPad-L390"
  ];
  users.users.flores = {
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
    s-tui
    powertop
    htop
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
  port = 9090;
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
  security.pam.services.cockpit = {
     allowNullPassword = false;
     rootOK = true; # erlaubt Root-Login via Web-GUI
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
  systemd.sockets."cockpit-wsinstance-https-factory" = {
     enable = false;
  };
  systemd.services."cockpit" = {
    serviceConfig = {
       ExecStart = "${pkgs.cockpit}/libexec/cockpit-ws --no-tls";
    };
  };
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
