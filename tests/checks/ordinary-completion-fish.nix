{ pkgs, fixtures }:
import ../completion-backends/fish.nix {
  inherit fixtures pkgs;
  contract = import ../completion-contract.nix;
}
