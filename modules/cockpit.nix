{ config, pkgs, lib, ... }:

{
  #
  # Cockpit Web-UI für VM/Container-Management
  # Nutzt custom Cockpit-Pakete aus overlays/cockpit.nix
  #

  # Cockpit systemd services (manuell definiert, da kein offizielles NixOS-Modul)
  systemd.services.cockpit = {
    description = "Cockpit Web Service";
    wants = [ "cockpit.socket" ];
    after = [ "cockpit.socket" ];
    serviceConfig = {
      ExecStart = "${pkgs.cockpit}/libexec/cockpit-ws --no-tls";
      User = "root";
      Group = "root";
    };
  };

  systemd.sockets.cockpit = {
    description = "Cockpit Web Service Socket";
    wantedBy = [ "sockets.target" ];
    listenStreams = [ "9090" ];
    socketConfig = {
      Accept = false;
    };
  };

  # Virtualisierung: libvirtd für VMs
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      swtpm.enable = true;     # TPM-Emulation
      runAsRoot = false;
    };
    onBoot = "ignore";         # VMs nicht automatisch starten
    onShutdown = "shutdown";   # VMs sauber herunterfahren
  };

  # Container: Podman mit Docker-Kompatibilität
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;       # docker-Befehl → podman
    defaultNetwork.settings.dns_enabled = true;
    autoPrune = {
      enable = true;
      dates = "weekly";        # Wöchentlich aufräumen
    };
  };

  # Cockpit-Pakete und Tools
  environment.systemPackages = with pkgs; [
    cockpit                    # Hauptpaket aus Overlay
    # cockpit-machines         # TODO: Fix git-dependency in Makefile
    # cockpit-podman           # TODO: Fix git-dependency in Makefile
    virt-viewer                # VNC/SPICE Konsole
    libvirt                    # libvirt CLI tools
  ];

  # PAM: Root-Login via Cockpit erlauben
  security.pam.services.cockpit = {
    unixAuth = true;
    rootOK = true;
  };

  # Firewall: Cockpit Port + VNC Range
  networking.firewall.allowedTCPPorts = [ 9090 ] ++ (lib.range 5900 5910);

  # Admin-User für Cockpit Web-UI
  users.users.admin = {
    isNormalUser = true;
    description = "Cockpit Administrator";
    extraGroups = [ "wheel" "libvirtd" ];
    initialPassword = "changeme";  # Bitte nach erstem Login ändern!
  };
}
