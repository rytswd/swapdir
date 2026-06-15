{ pkgs, inputs, system, flake, ... }:
let
  zig = inputs.zignix.packages.${system}.zig-master;
in
pkgs.stdenv.mkDerivation {
  pname = "swapdir-tests";
  version = "0.1.0";

  src = flake;

  nativeBuildInputs = [ zig ];

  XDG_CACHE_HOME = "$TMPDIR/.cache";
  ZIG_GLOBAL_CACHE_DIR = "$TMPDIR/.cache/zig";

  buildPhase = ''
    zig build test
  '';

  installPhase = ''
    touch $out
  '';
}
