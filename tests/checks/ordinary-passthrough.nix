{ pkgs, pog, fixtures }:
let
  forceEvaluation = specification:
    let
      result = pog specification;
    in
    builtins.tryEval (builtins.seq result.drvPath true);

  passthroughParent = forceEvaluation {
    name = "pog-invalid-passthrough-parent";
    parsing = pog.parsing.passthrough;
    commands = [{ name = "child"; script = ":"; }];
  };

  invalidMode = forceEvaluation {
    name = "pog-invalid-parsing-mode";
    parsing = "permissive-ish";
    script = ":";
  };
in
assert !passthroughParent.success;
assert !invalidMode.success;
pkgs.runCommand "pog-ordinary-passthrough-check" { }
  ''
    command=${fixtures.passthrough}/bin/pog-passthrough-fixture
    grep -Fx 'export CARAPACE_LENIENT=1' ${fixtures.passthrough.pog.completionCommand}

    output="$($command \
      input \
      --profile dev \
      --foreign value \
      --label api \
      'two words' \
      --label=worker \
      --color=blue \
      -VV \
      --unknown=kept \
      output)"
    test "$output" = "$(printf '%s\n' \
      'profile=<dev>' \
      'labels=<api,worker>' \
      'color=<blue> verbose=<2> dry_run=<>' \
      'args=<input><--foreign><value><two words><--unknown=kept><output>')"

    output="$($command -pprod -lfirst -lsecond --color -n -xyz tail)"
    test "$output" = "$(printf '%s\n' \
      'profile=<prod>' \
      'labels=<first,second>' \
      'color=<> verbose=<0> dry_run=<1>' \
      'args=<-xyz><tail>')"

    output="$($command -Vnpprod -Vclue -xV tail)"
    test "$output" = "$(printf '%s\n' \
      'profile=<prod>' \
      'labels=<>' \
      'color=<lue> verbose=<2> dry_run=<1>' \
      'args=<-xV><tail>')"

    output="$($command --profile dev -- --profile downstream -VV --dry-run)"
    test "$output" = "$(printf '%s\n' \
      'profile=<dev>' \
      'labels=<>' \
      'color=<auto> verbose=<0> dry_run=<>' \
      'args=<--profile><downstream><-VV><--dry-run>')"

    output="$(POG_PROFILE=environment $command --foreign value)"
    test "$output" = "$(printf '%s\n' \
      'profile=<environment>' \
      'labels=<>' \
      'color=<auto> verbose=<0> dry_run=<>' \
      'args=<--foreign><value>')"

    set +e
    $command --profile > "$TMPDIR/missing.stdout" 2> "$TMPDIR/missing.stderr"
    status=$?
    set -e
    test "$status" -eq 2
    test ! -s "$TMPDIR/missing.stdout"
    grep -Fx "option --profile requires an argument" "$TMPDIR/missing.stderr"

    set +e
    $command --dry-run=yes > "$TMPDIR/bool.stdout" 2> "$TMPDIR/bool.stderr"
    status=$?
    set -e
    test "$status" -eq 2
    test ! -s "$TMPDIR/bool.stdout"
    grep -Fx "option --dry-run does not accept an argument" "$TMPDIR/bool.stderr"

    set +e
    ${fixtures.flags}/bin/pog-flags-fixture --foreign \
      > "$TMPDIR/strict.stdout" \
      2> "$TMPDIR/strict.stderr"
    status=$?
    set -e
    test "$status" -eq 2
    grep -F 'unrecognized option' "$TMPDIR/strict.stderr"

    touch "$out"
  ''
