pkgs:
pkgs.stdenv.mkDerivation {
  pname = "bramble";
  version = "unstable-2026-02-04";

  src = pkgs.fetchFromGitHub {
    owner = "Night-Traders-Dev";
    repo = "Bramble";
    rev = "9eeea2470c1fa51319510e34d2206dee5a4d6725";
    sha256 = "sha256-GXSICtaEFfcoY9ssT4CScNLbgxWzsTq1NR8u4WtjQl8=";
  };
  nativeBuildInputs = [
    pkgs.gnumake
    pkgs.pkg-config
    pkgs.cmake

  ];
  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    cp bramble $out/bin/
    runHook postInstall
  '';

  meta = with pkgs.lib; {
    description = "A from-scratch ARM Cortex-M0+ emulator for the Raspberry Pi RP2040 microcontroller";
    homepage = "https://github.com/Night-Traders-Dev/Bramble";
    license = licenses.mit;
    platforms = platforms.all;
  };
}
