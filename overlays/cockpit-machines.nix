self: super: {
  cockpit-machines = super.stdenv.mkDerivation rec {
    pname = "cockpit-machines";
  version = "327";

    # Nutze pre-built dist tarball statt source
    src = super.fetchurl {
      url = "https://github.com/cockpit-project/cockpit-machines/releases/download/${version}/cockpit-machines-${version}.tar.xz";
      hash = "sha256-bGHskly2Hmmzk8pJ27y6YChxI8dG/zu5F4MALnkUpkM=";
    };

    dontBuild = true;  # Pre-built, kein Build nötig

    installPhase = ''
      runHook preInstall

      mkdir -p $out/share/cockpit
      cp -r dist $out/share/cockpit/machines

      # Manifest-Condition an NixOS anpassen: prüfe libvirt Socket statt DBus-Policy
      if [ -f "$out/share/cockpit/machines/manifest.json" ]; then
        sed -i 's#/usr/share/dbus-1/system.d/org.libvirt.conf#/var/run/libvirt/libvirt-sock#g' \
          "$out/share/cockpit/machines/manifest.json"
      fi

      runHook postInstall
    '';

    meta = with super.lib; {
      description = "Cockpit UI for virtual machines";
      homepage = "https://github.com/cockpit-project/cockpit-machines";
      license = licenses.lgpl21Plus;
      platforms = platforms.linux;
    };
  };

  # Kombiniertes Paket: Cockpit + Machines in einem Verzeichnis
  cockpit-with-machines = super.stdenv.mkDerivation {
    name = "cockpit-with-machines";
    
    buildInputs = [ self.cockpit self.cockpit-machines super.makeWrapper ];
    nativeBuildInputs = [ super.makeWrapper ];
    
    buildCommand = ''
      mkdir -p $out/share/cockpit
      
      # Kopiere alle Cockpit-Module
      cp -r ${self.cockpit}/share/cockpit/* $out/share/cockpit/
      
      # Füge cockpit-machines hinzu
      cp -r ${self.cockpit-machines}/share/cockpit/machines $out/share/cockpit/
      
      # Kopiere libexec für cockpit-ws und andere Tools
      mkdir -p $out/libexec
      cp -r ${self.cockpit}/libexec/* $out/libexec/
      
      # Kopiere bin für cockpit-bridge mit PATH-Wrapper
      mkdir -p $out/bin
      
      # Erstelle Wrapper für cockpit-bridge mit korrektem PATH
      makeWrapper ${self.cockpit}/bin/cockpit-bridge $out/bin/cockpit-bridge \
        --prefix PATH : ${super.lib.makeBinPath [ super.bash super.coreutils super.util-linux ]}
    '';
  };
}
