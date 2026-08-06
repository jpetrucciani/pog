{ pkgs, fixture, structuredFixture }:
let
  command = "pog-completion-fixture";
  completion = "${fixture}/share/bash-completion/completions/${command}";
  structuredCommand = "pog-structured-completion-fixture";
  structuredCompletion = "${structuredFixture}/share/bash-completion/completions/${structuredCommand}";
in
pkgs.runCommand "pog-bash-readline-completion"
{
  nativeBuildInputs = [ pkgs.expect ];
}
  ''
    work="$TMPDIR/readline-work"
    mkdir -p "$TMPDIR/home" "$work/directory"
    touch "$work/native-target" "$work/space target"

    export POG_EXPECT_BASH=${pkgs.bashInteractive}/bin/bash
    export POG_EXPECT_COMPLETION=${completion}
    export POG_EXPECT_STRUCTURED_COMPLETION=${structuredCompletion}
    export POG_EXPECT_HOME="$TMPDIR/home"
    export POG_EXPECT_LOG="$TMPDIR/readline.log"
    export POG_EXPECT_WORK="$work"

    if ! expect ${./bash-readline.exp}; then
      if [[ -f $POG_EXPECT_LOG ]]; then
        printf '%s\n' 'Bash Readline session log:' >&2
        cat "$POG_EXPECT_LOG" >&2
      fi
      exit 1
    fi

    touch "$out"
  ''
