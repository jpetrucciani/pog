{ _compat ? import ./flake-compat.nix
, pkgs ? import _compat.inputs.nixpkgs { }
, system ? pkgs.system
}:
let
  params = { inherit pkgs system; };
  pog = import ./pog params;
in
pog
