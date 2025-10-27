self: super: {
  cockpit = super.stdenv.mkDerivation rec {
    pname = "cockpit";
    version = "321";

    # Nutze den offiziellen Release-Tarball, nicht GitHub-Repo
    src = super.fetchurl {
      url = "https://github.com/cockpit-project/cockpit/releases/download/${version}/cockpit-${version}.tar.xz";
      sha256 = "sha256-kTXnVKQqWud2rLYupRz1iL8Cepsm1So07D2fE7mI6KQ=";
    };

    nativeBuildInputs = with super; [
      pkg-config
      gettext
      python3
      python3.pkgs.pip
      python3.pkgs.build
      libxslt
      xmlto
      docbook_xsl
      autoreconfHook
    ];

    buildInputs = with super; [
      glib
      json-glib
      polkit
      libssh
      systemd
      pam
      gnutls
      krb5
      libpwquality
      libxcrypt
    ];

    configureFlags = [
      "--disable-doc"
      "--disable-selinux"
      "--enable-polkit"
      "--enable-pam"
      "--disable-pcp"
      "--with-admin-group=wheel"
      "--with-systemdunitdir=${placeholder "out"}/lib/systemd/system"
    ];

    # Cockpit braucht node_modules aus dist/ (pre-built)
    preConfigure = ''
      # dist/ ist bereits im Tarball vorhanden
      export NODE_ENV=production
      
      # Patch hardcoded Python paths in build scripts
      patchShebangs tools/
    '';

    postInstall = ''
      # Stelle sicher, dass systemd units korrekt installiert sind
      mkdir -p $out/lib/systemd/system
    '';

    meta = with super.lib; {
      description = "Web-based server manager";
      homepage = "https://cockpit-project.org/";
      license = licenses.lgpl21Plus;
      platforms = platforms.linux;
    };
  };

  cockpit-machines = super.stdenv.mkDerivation rec {
    pname = "cockpit-machines";
    version = "316";

    src = super.fetchFromGitHub {
      owner = "cockpit-project";
      repo = "cockpit-machines";
      rev = version;
      sha256 = "sha256-Zh8m5Gpl8dMSXkUUT8mhmW9HDmS/XxxpykHLXbXzG+M=";
    };

    nativeBuildInputs = with super; [
      gettext
      nodejs
      python3
      git
    ];

    buildInputs = [ self.cockpit ];

    makeFlags = [
      "DESTDIR=$(out)"
      "PREFIX="
    ];

    meta = with super.lib; {
      description = "Cockpit UI for virtual machines";
      homepage = "https://cockpit-project.org/";
      license = licenses.lgpl21Plus;
    };
  };

  cockpit-podman = super.stdenv.mkDerivation rec {
    pname = "cockpit-podman";
    version = "92";

    src = super.fetchFromGitHub {
      owner = "cockpit-project";
      repo = "cockpit-podman";
      rev = version;
      sha256 = "sha256-fGvVEwpXF8igoHM/KEmeIHcUBemMeeR/B0IxWzkwbK4=";
    };

    nativeBuildInputs = with super; [
      gettext
      nodejs
      python3
      git
    ];

    buildInputs = [ self.cockpit ];

    makeFlags = [
      "DESTDIR=$(out)"
      "PREFIX="
    ];

    meta = with super.lib; {
      description = "Cockpit UI for podman containers";
      homepage = "https://cockpit-project.org/";
      license = licenses.lgpl21Plus;
    };
  };
}
