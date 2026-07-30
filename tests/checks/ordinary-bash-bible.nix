{ pkgs, fixtures }:
pkgs.runCommand "pog-ordinary-bash-bible-check" { } ''
  output="$(${fixtures.bashBible}/bin/pog-bash-bible-fixture)"
  test "$output" = "$(printf '%s\n' \
    'reverse=<AbC z-123>' \
    'trim=<spaced value>')"

  touch "$out"
''
