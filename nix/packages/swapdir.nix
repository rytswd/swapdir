{ pkgs, inputs, system, flake, ... }:
let
  zig = inputs.zignix.packages.${system}.zig-master;
  # The build sandbox has no .git, so the commit baked into `--version`
  # comes from the flake revision (falls back to "dirty" for uncommitted
  # trees, e.g. `nix build` on a work-in-progress checkout).
  gitRev = flake.shortRev or flake.dirtyShortRev or "unknown";
in
pkgs.stdenv.mkDerivation {
  pname = "swapdir";
  version = "0.1.0";

  src = flake;

  nativeBuildInputs = [ zig ];

  XDG_CACHE_HOME = "$TMPDIR/.cache";
  ZIG_GLOBAL_CACHE_DIR = "$TMPDIR/.cache/zig";

  buildPhase = ''
    zig build -Doptimize=ReleaseSafe -Dgit_rev=${gitRev}
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
