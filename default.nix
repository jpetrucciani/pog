{ pkgs ? import <nixpkgs> { }, system ? pkgs.system }:
let
  params = { inherit pkgs system; };
  pog = import ./pog params;
in
pog
