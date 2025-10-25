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
    buildInputs = [
      super.openssl
      super.udev
      super.libtirpc
      super.pciutils
      super.numactl.dev
      super.zlib.dev
    ];


    makeFlags = [ "KERNEL_SOURCE=${super.linux.dev}/lib/modules/${super.linux.modDirVersion}/build" ];

  installPhase = ''
    mkdir -p $/out/bin
    find . -type f -name adf_ctl -exec cp -v {} $/out/bin/ \;
    find . -type f -name qat_service -exec cp -v {} $/out/bin/ \; || true
    mkdir -p $/out/lib/modules
    find . -type f -name '*.ko' -exec cp -v {} $/out/lib/modules/ \;
  '';


  
    meta = with super.lib; {
      description = "Intel QuickAssist Technology SDK with kernel modules and tools";
      homepage = "https://github.com/intel/qatlib";
      license = licenses.bsd3;
      platforms = platforms.linux;
    };
  };
}

