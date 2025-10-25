self: super:

let
  qatlibSrc = super.fetchFromGitHub {
    owner = "intel";
    repo = "qatlib";
    rev = "8575c0e2b8439d50f343476aed1e1f7bac60bf1d";
    sha256 = "sha256-xAUS1ZEpFVSWg9/jp+oZMxzuEpCcKyBwjwHGGD/ETkg=";
  };
in {
  qatlib = super.stdenv.mkDerivation {
    pname = "qatlib";
    version = "1.7.0";

    src = qatlibSrc;

    nativeBuildInputs = [
      super.autoconf
      super.automake
      super.libtool
      super.pkg-config
      super.autoconf-archive
      super.nasm
    ];

    buildInputs = [
      super.openssl
      super.udev
      super.libtirpc
      super.pciutils
      super.numactl.dev
      super.zlib.dev
    ];

    preConfigure = "./autogen.sh";
    configureFlags = [ "--without-systemd" ];


    buildPhase = "make";

   installPhase = ''
     substituteInPlace quickassist/utilities/service/Makefile --replace 'install-systemdsystemunitDATA' ""
     make install
   '';
    
     meta = with super.lib; {
      description = "Intel QuickAssist userspace library (qatlib)";
      homepage = "https://github.com/intel/qatlib";
      license = licenses.bsd3;
      maintainers = [ maintainers.flores ];
    };
  };
}
