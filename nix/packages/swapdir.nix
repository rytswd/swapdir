{ pkgs, inputs, system, flake, ... }:
let
  zig = inputs.zig-overlay.packages.${system}.master;
in
pkgs.stdenv.mkDerivation {
  pname = "swapdir";
  version = "0.1.0";

  src = flake;

  nativeBuildInputs = [ zig ];

  XDG_CACHE_HOME = "$TMPDIR/.cache";
  ZIG_GLOBAL_CACHE_DIR = "$TMPDIR/.cache/zig";

  buildPhase = ''
    zig build -Doptimize=ReleaseSafe
  '';

  installPhase = ''
    mkdir -p $out/bin $out/share/swapdir
    cp zig-out/bin/swapdir $out/bin/
    cp shell/* $out/share/swapdir/
  '';

  checkPhase = ''
    zig build test
  '';

  doCheck = true;
}
