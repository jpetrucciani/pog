{
  description = "pog";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        pog = import ./. {
          inherit pkgs system;
        };
        params = {
          inherit pkgs;
          inherit (pog) _ pog;
        };
        builtin = import ./builtin params;
      in
      rec {
        inherit (pog) overlay;
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
      });
}
