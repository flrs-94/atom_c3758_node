{ config, pkgs, lib, ... }:

{
  #
  # Cockpit Web-UI für VM/Container-Management
  # Nutzt offizielles NixOS Cockpit-Paket (v349)
  #

  # Cockpit: offizielles services.cockpit Modul
  services.cockpit = {
    enable = true;
    port = 9090;
    settings = {
      WebService = {
        AllowUnencrypted = true;  # --no-tls
        Origins = lib.mkForce "http://192.168.20.129:9090 http://localhost:9090 ws://192.168.20.129:9090 ws://localhost:9090";
      };
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

  # libvirtd dauerhaft aktiv halten für Cockpit
  systemd.services.libvirtd = {
    wantedBy = [ "multi-user.target" ];
  };

  # D-Bus Policy/Service für libvirt (für Cockpit-Integration via libvirt-dbus)
  services.dbus.packages = [ pkgs.libvirt-dbus ];

  # Installiere systemd-Unit für DBus-Aktivierung (org.libvirt)
  systemd.packages = [ pkgs.libvirt-dbus ];

  # libvirt-dbus stabilisieren (keine DynamicUser, als root starten, auf dbus+libvirtd warten)
  systemd.services.libvirt-dbus = {
    after = [ "dbus.service" "libvirtd.service" ];
    requires = [ "dbus.service" "libvirtd.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      DynamicUser = lib.mkForce false;
      User = "root";
      Group = "root";
      # Vorherige ExecStart-Einträge entfernen und neu setzen
      ExecStart = lib.mkForce [ "" "${pkgs.libvirt-dbus}/sbin/libvirt-dbus --system" ];
    };
  };

  # Stelle DBus-Policy/Service-Dateien unter /etc bereit (NixOS liest diese Pfade zuverlässig)
  environment.etc."dbus-1/system.d/org.libvirt.conf".source = "${pkgs.libvirt-dbus}/share/dbus-1/system.d/org.libvirt.conf";
  environment.etc."dbus-1/system-services/org.libvirt.service".source = "${pkgs.libvirt-dbus}/share/dbus-1/system-services/org.libvirt.service";

  # Dummy-Datei für cockpit-machines Condition
  systemd.tmpfiles.rules = [
    "f /usr/share/dbus-1/system.d/org.libvirt.conf 0644 root root - -"
  ];

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
    cockpit                    # Hauptpaket (v349 aus nixpkgs)
    cockpit-machines           # VM-Verwaltung aus custom overlay
    virt-viewer                # VNC/SPICE Konsole
    libvirt                    # libvirt CLI tools
    python3                    # Für Cockpit-Backend
    python3Packages.libvirt    # Python-libvirt-Bindings
  ];

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