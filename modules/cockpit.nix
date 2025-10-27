{ config, pkgs, lib, ... }:

{
  #
  # Cockpit Web-UI für VM/Container-Management
  # Nutzt custom Cockpit-Pakete aus overlays/cockpit.nix
  #

  services.cockpit = {
    enable = true;
    port = 9090;
    settings = {
      WebService = {
        AllowUnencrypted = true;
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
    cockpit-machines           # libvirt/KVM UI
    cockpit-podman             # Podman/Container UI
    virt-viewer                # VNC/SPICE Konsole
  ];

  # PAM: Root-Login via Cockpit erlauben
  security.pam.services.cockpit = {
    unixAuth = true;
    rootOK = true;
  };

  # Admin-User für Cockpit Web-UI
  users.users.admin = {
    isNormalUser = true;
    description = "Cockpit Administrator";
    extraGroups = [ "wheel" "libvirtd" ];
    initialPassword = "changeme";  # Bitte nach erstem Login ändern!
  };
}
