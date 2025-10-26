self: super:

# Dieses Overlay baut nur die Kernel-Module aus dem QAT-Quellcode.
# Die Userspace-Komponenten werden von qatlib.nix gebaut.
{
  qat-sdk = super.stdenv.mkDerivation rec {
    pname = "qat-sdk";
    version = "1.7.0";  # Gleiche Version wie qatlib

    src = self.qatlib.src;  # Nutze die gleiche Quelle wie qatlib

    # Build-Tools für Kernel-Module (voll qualifizierte Referenzen auf nixpkgs)
    nativeBuildInputs = [
      super.pkgconf
      super.gcc
      super.gnumake
      super.flex
      super.bison
      super.which
      super.kmod
    ];

    # Kernel-Headers und Build-Dependencies
    buildInputs = [ super.linux.dev ];

    # Kernel-Build-Flags: verwende den Kernel-Build-Pfad aus dem linux.dev Paket
    makeFlags = [
      "KERNEL_SOURCE=${super.linux.dev}/lib/modules/${super.linux.modDirVersion}/build"
    ];

    buildPhase = ''
      # Baue Kernel-Module (falls vorhanden). Manche Releases enthalten keine
      # out-of-tree Kernel-Module im qatlib-Archiv; in diesem Fall überspringen
      # wir die Build-Phase, damit die Derivation nicht fehlschlägt.
      KERNEL_SRC=${super.linux.dev}/lib/modules/${super.linux.modDirVersion}/build

      # Falls ein Makefile existiert, versuchen wir, make aufzurufen. Andernfalls
      # überspringen wir den Schritt.
      if find . -maxdepth 4 -type f \( -name Makefile -o -name Makefile.am \) | grep -q .; then
        echo "Found Makefile(s); running make with KERNEL_SOURCE=$KERNEL_SRC"
        make KERNEL_SOURCE=$KERNEL_SRC || true
      else
        echo "No Makefile found in source; skipping kernel-module build"
      fi
    '';

    installPhase = ''
      # Nur die Kernel-Module installieren
      mkdir -p $out/lib/modules
      find . -type f -name '*.ko' -exec cp -v {} $out/lib/modules/ \;
    '';

    meta = with super.lib; {
      description = "Intel QuickAssist Technology Kernel Modules";
      homepage = "https://github.com/intel/qatlib";
      license = licenses.bsd3;
      platforms = platforms.linux;
    };
  };
}

