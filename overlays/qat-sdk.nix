self: super:

let
  qatlibSrc = builtins.fetchGit {
    url = "https://github.com/intel/qatlib";
    rev = "main"; # oder ein stabiler Commit-Hash
  };
in {
  qat-sdk = super.stdenv.mkDerivation rec {
    pname = "qat-sdk";
    version = "unstable";

    src = qatlibSrc;

    nativeBuildInputs = with super; [ autoconf automake libtool pkg-config ];
    buildInputs = with super; [ openssl zlib libudev ];

    makeFlags = [ "KERNEL_SOURCE=${super.linux.dev}/lib/modules/${super.linux.modDirVersion}/build" ];

    installPhase = ''
      mkdir -p $out/bin
      cp -v build/*/adf_ctl $out/bin/
      cp -v build/*/qat_service $out/bin/ || true
      mkdir -p $out/lib/modules
      cp -v build/*/*.ko $out/lib/modules/
    '';

    meta = with super.lib; {
      description = "Intel QuickAssist Technology SDK with kernel modules and tools";
      homepage = "https://github.com/intel/qatlib";
      license = licenses.bsd3;
      platforms = platforms.linux;
    };
  };
}

/***
self: super:

let
  qatlibSrc = super.fetchFromGitHub {
    owner = "intel";
    repo = "qatlib";
    rev = "v24.02.0"; # oder HEAD für aktuellste Version
    sha256 = "sha256-PLACEHOLDER"; # mit nix-prefetch-git oder nix-prefetch-url ermitteln
  };
in {
  qat-sdk = super.stdenv.mkDerivation rec {
    pname = "qat-sdk";
    version = "24.02.0";

    src = qatlibSrc;

    nativeBuildInputs = with super; [ autoconf automake libtool pkg-config ];

    buildInputs = with super; [ openssl zlib libudev ];

    makeFlags = [ "KERNEL_SOURCE=${super.linux.dev}/lib/modules/${super.linux.modDirVersion}/build" ];

    installPhase = ''
      mkdir -p $out/bin
      cp -v build/*/adf_ctl $out/bin/
 #    cp -v build/*/qat_service $out/bin/ || true
  #   mkdir -p $out/lib/modules
   #  cp -v build/*/*.ko $out/lib/modules/
   # '';
/*
    meta = with super.lib; {
      description = "Intel QuickAssist Technology SDK with kernel modules and tools";
      homepage = "https://github.com/intel/qatlib";
      license = licenses.bsd3;
      platforms = platforms.linux;
    };
  };
}
***/
