{ pkgs, fixtures }:
import ../completion-backends/zsh-zle.nix {
  fixture = fixtures.completion;
  structuredFixture = fixtures.structuredCompletion;
  inherit pkgs;
}
