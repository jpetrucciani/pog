{ pkgs, fixture, structuredFixture }:
let
  command = "pog-completion-fixture";
  completion = "${fixture}/share/zsh/site-functions/_${command}";
  structuredCommand = "pog-structured-completion-fixture";
  structuredCompletion = "${structuredFixture}/share/zsh/site-functions/_${structuredCommand}";
in
pkgs.runCommand "pog-zsh-zle-completion"
{
  nativeBuildInputs = [ pkgs.expect ];
}
  ''
    work="$TMPDIR/zle-work"
    mkdir -p "$TMPDIR/home" "$work/directory"
    mkdir -p "$work/structured-dir"
    touch "$work/native-target" "$work/space target"
    touch "$work/structured.nix" "$work/structured.yaml" "$work/ignored.txt"

    export POG_EXPECT_ZSH=${pkgs.zsh}/bin/zsh
    export POG_EXPECT_COMPLETION=${completion}
    export POG_EXPECT_STRUCTURED_COMPLETION=${structuredCompletion}
    export POG_EXPECT_HOME="$TMPDIR/home"
    export POG_EXPECT_LOG="$TMPDIR/zle.log"
    export POG_EXPECT_WORK="$work"

    if ! expect ${./zsh-zle.exp}; then
      if [[ -f $POG_EXPECT_LOG ]]; then
        printf '%s\n' 'Zsh ZLE session log:' >&2
        cat "$POG_EXPECT_LOG" >&2
      fi
      exit 1
    fi

    touch "$out"
  ''
