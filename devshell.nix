{ pkgs, inputs, system, ... }:
let
  zig = inputs.zig-overlay.packages.${system}.master;
in
pkgs.mkShell {
  packages = [
    zig
  ];

  env = { };

  shellHook = ''
    echo "swapdir dev environment"
    echo "Zig: $(zig version)"
  '';
}
