{ pkgs, inputs, system, ... }:
let
  zig = inputs.zignix.packages.${system}.zig-master;
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
