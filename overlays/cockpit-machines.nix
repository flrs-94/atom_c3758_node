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
      
      runHook postInstall
    '';

    meta = with super.lib; {
      description = "Cockpit UI for virtual machines";
      homepage = "https://github.com/cockpit-project/cockpit-machines";
      license = licenses.lgpl21Plus;
      platforms = platforms.linux;
    };
  };
}
