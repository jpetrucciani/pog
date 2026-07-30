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
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      perSystem = flake-utils.lib.eachSystem supportedSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          isLinux = pkgs.stdenv.hostPlatform.isLinux;
          pog = import ./. {
            inherit pkgs system;
          };
          params = {
            inherit pkgs;
            inherit (pog) _ pog;
          };
          builtin = import ./builtin params;
          portableTests = import ./tests {
            inherit pkgs;
            inherit (pog) pog;
          };
        in
        {
          inherit (portableTests) checks packages;
          legacyPackages = { inherit pog builtin; };
          apps = {
            test = {
              type = "app";
              program = pkgs.lib.getExe portableTests.allTests;
              meta.description = "Run every pog behavioral test available on this platform";
            };
            portable-fixture-host = portableTests.fixtures.portable.toHostScript.app;
          } // pkgs.lib.optionalAttrs isLinux {
            test-portable-parity = {
              type = "app";
              program = pkgs.lib.getExe portableTests.portableParity;
              meta.description = "Run the pog behavior contract against all portable output formats";
            };
            portable-fixture-arx = portableTests.fixtures.portable.toArx.app;
            portable-fixture-appimage = portableTests.fixtures.portable.toAppImage.app;
          };

          devShells = {
            default = pkgs.mkShell {
              nativeBuildInputs = with pkgs; [
                bun
                deadnix
                nixpkgs-fmt
                shellcheck
                shfmt
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
    in
    perSystem // {
      overlays.default = final: _prev: {
        pog = import ./. {
          pkgs = final;
          system = final.stdenv.hostPlatform.system;
        };
      };
    };
}
