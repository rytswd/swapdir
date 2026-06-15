{
  description = "swapdir - cross-shell directory path swapping utility";

  nixConfig = {
    extra-substituters = [ "https://swapdir.cachix.org" ];
    extra-trusted-public-keys = [
      "swapdir.cachix.org-1:AxK+CyOlKSBbZ/O2HhFz4V++zaIP1UqPaRenIbbFpUo="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs?ref=nixos-unstable";
    blueprint.url = "github:numtide/blueprint";
    blueprint.inputs.nixpkgs.follows = "nixpkgs";
    zignix.url = "github:withre/zignix";
    zignix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs: inputs.blueprint { inherit inputs; prefix = "nix"; };
}
