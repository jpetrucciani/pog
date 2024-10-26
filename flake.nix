{
  description = "pog";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { nixpkgs, flake-utils, ... }:
    let
      setup = system: rec {
        pkgs = nixpkgs.legacyPackages.${system};
        pog = import ./. {
          inherit pkgs system;
        };
        params = {
          inherit pkgs;
          inherit (pog) _ pog;
        };
        builtin = import ./builtin params;
      };
    in
    (flake-utils.lib.eachDefaultSystem
      (system:
        let
          inherit (setup system) pkgs pog builtin;
        in
        rec {
          packages = { inherit pog builtin; };
          defaultPackage = packages.pog;

          devShells = {
            default = pkgs.mkShell {
              nativeBuildInputs = with pkgs; [
                bun
                deadnix
                nixpkgs-fmt
                statix
              ];
            };
          };
        }))
    // (flake-utils.lib.eachDefaultSystemPassThrough (system:
      let
        inherit (setup system) pog;
      in
      {
        overlays.default = final: prev: { inherit pog; };
      }));
}
