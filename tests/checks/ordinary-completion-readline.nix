{ pkgs, fixtures }:
import ../completion-backends/bash-readline.nix {
  fixture = fixtures.completion;
  structuredFixture = fixtures.structuredCompletion;
  inherit pkgs;
}
