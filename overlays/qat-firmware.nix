self: super: {
  qat-firmware = super.runCommand "qat-firmware" {
    preferLocalBuild = true;
    allowSubstitutes = false;
    passthru.compressFirmware = false;
    meta = with super.lib; {
      description = "Intel QAT C3xxx firmware vendored into repo";
      license = licenses.unfreeRedistributableFirmware;
      platforms = platforms.linux;
    };
  } ''
    mkdir -p "$out/lib/firmware/intel/qat"
    install -Dm444 ${super.firmwareBins.qat_c3xxx_mmp} "$out/lib/firmware/intel/qat/qat_c3xxx_mmp.bin"
    install -Dm444 ${super.firmwareBins.qat_c3xxx} "$out/lib/firmware/intel/qat/qat_c3xxx.bin"
  '';
}
