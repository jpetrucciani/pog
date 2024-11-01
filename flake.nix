{
  description = "pog";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-compat = {
      flake = false;
      url = "github:edolstra/flake-compat";
    };
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
        overlays.default = final: prev: { inherit pog; };
        packages = { inherit pog builtin; };
        defaultPackage = packages.pog;

        devShells = {
          default = pkgs.mkShell {
            nativeBuildInputs = with pkgs; [
              bun
              deadnix
              nixpkgs-fmt
              statix
            ] ++ [
              (pog.pog {
                name = "docs";
                script = ''
                  ${pkgs.bun}/bin/bunx vitepress dev docs --host 0.0.0.0 "$@"
                '';
              })
              (pog.pog {
                name = "build_docs";
                script = ''
                  ${pkgs.bun}/bin/bunx vitepress build docs "$@"
                '';
              })
            ];
          };
        };
      });
}
