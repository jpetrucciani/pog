{ pkgs, pog, fixtures }:
let
  forceEvaluation = specification:
    let
      result = pog specification;
    in
    builtins.tryEval (builtins.seq result.drvPath true);

  duplicateAlias = forceEvaluation {
    name = "pog-invalid-duplicate-alias";
    commands = [
      {
        name = "one";
        aliases = [ "shared" ];
        script = ":";
      }
      {
        name = "two";
        aliases = [ "shared" ];
        script = ":";
      }
    ];
  };

  unknownExclusiveFlag = forceEvaluation {
    name = "pog-invalid-exclusive-flag";
    flags = [{ name = "known"; bool = true; }];
    exclusiveFlags = [ [ "known" "missing" ] ];
    script = ":";
  };

  misplacedVariadicArgument = forceEvaluation {
    name = "pog-invalid-variadic-argument";
    arguments = [
      { name = "many"; variadic = true; }
      "last"
    ];
    script = ":";
  };

  interspersedParent = forceEvaluation {
    name = "pog-invalid-interspersed-parent";
    parsing = "interspersed";
    commands = [{ name = "child"; script = ":"; }];
  };

  ambiguousBooleanFlag = forceEvaluation {
    name = "pog-invalid-ambiguous-bool";
    flags = [
      {
        name = "ambiguous";
        bool = true;
        optionalValue = true;
      }
    ];
    script = ":";
  };
in
assert !duplicateAlias.success;
assert !unknownExclusiveFlag.success;
assert !misplacedVariadicArgument.success;
assert !interspersedParent.success;
assert !ambiguousBooleanFlag.success;
pkgs.runCommand "pog-ordinary-advanced-commands-check"
{
  nativeBuildInputs = [ pkgs.gnugrep ];
}
  ''
    command=${fixtures.advancedCommands}/bin/pog-advanced-commands-fixture

    output="$($command \
      --profile dev \
      ship \
      --tag api \
      --tag worker \
      --color=blue \
      -VV \
      --secret \
      target)"
    test "$output" = "$(printf '%s\n' \
      'profile=<dev>' \
      'json=<> yaml=<>' \
      'tags=<api,worker>' \
      'color=<blue> secret=<1> verbose=<2>' \
      'args=<target>')"

    output="$($command deploy --profile prod --color target)"
    test "$output" = "$(printf '%s\n' \
      'profile=<prod>' \
      'json=<> yaml=<>' \
      'tags=<>' \
      'color=<> secret=<> verbose=<0>' \
      'args=<target>')"

    set +e
    $command deploy --json --yaml target \
      > "$TMPDIR/exclusive.stdout" \
      2> "$TMPDIR/exclusive.stderr"
    status=$?
    set -e
    test "$status" -eq 2
    test ! -s "$TMPDIR/exclusive.stdout"
    grep -Fx 'flags --json, --yaml are mutually exclusive' \
      "$TMPDIR/exclusive.stderr"

    $command --help > "$TMPDIR/root-help"
    grep -Fx '  operations:' "$TMPDIR/root-help"
    grep -F 'deploy' "$TMPDIR/root-help"
    grep -F '[aliases: ship]' "$TMPDIR/root-help"
    if grep -F 'internal' "$TMPDIR/root-help"; then
      echo "hidden command appeared in help" >&2
      exit 1
    fi

    $command deploy --help > "$TMPDIR/deploy-help"
    grep -F -- '--profile' "$TMPDIR/deploy-help"
    grep -F '[persistent]' "$TMPDIR/deploy-help"
    if grep -F -- '--secret' "$TMPDIR/deploy-help"; then
      echo "hidden flag appeared in help" >&2
      exit 1
    fi

    test "$($command internal)" = internal
    test "$($command literal value --parsed)" = \
      'parsed=<> args=<value --parsed>'
    test "$($command raw --profile ignored --literal)" = \
      'args=<--profile ignored --literal>'

    touch "$out"
  ''
