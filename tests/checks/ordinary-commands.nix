{ pkgs, pog, fixtures }:
let
  forceEvaluation = specification:
    let
      result = pog specification;
    in
    builtins.tryEval (builtins.seq result.drvPath true);

  multipleDefaults = forceEvaluation {
    name = "pog-invalid-multiple-defaults";
    commands = [
      {
        name = "first";
        default = true;
        script = ":";
      }
      {
        name = "second";
        default = true;
        script = ":";
      }
    ];
  };

  scriptAndDefault = forceEvaluation {
    name = "pog-invalid-script-and-default";
    script = ":";
    commands = [
      {
        name = "child";
        default = true;
        script = ":";
      }
    ];
  };
in
assert !multipleDefaults.success;
assert !scriptAndDefault.success;
pkgs.runCommand "pog-ordinary-commands-check"
{
  nativeBuildInputs = [ pkgs.gnugrep ];
}
  ''
    commands=${fixtures.commands}/bin/pog-commands-fixture

    output="$("$commands" group)"
    test "$output" = "$(printf '%s\n' \
      'show=<default> scope=<local>' \
      'cleanup:show' \
      'cleanup:group' \
      'cleanup:root')"

    output="$("$commands" group --scope global show item)"
    test "$output" = "$(printf '%s\n' \
      'show=<item> scope=<global>' \
      'cleanup:show' \
      'cleanup:group' \
      'cleanup:root')"

    output="$("$commands" group nested leaf 'deep value')"
    test "$output" = "$(printf '%s\n' \
      'leaf=<deep value>' \
      'cleanup:leaf' \
      'cleanup:nested' \
      'cleanup:group' \
      'cleanup:root')"

    set +e
    "$commands" group fail \
      > "$TMPDIR/fail.stdout" \
      2> "$TMPDIR/fail.stderr"
    status=$?
    set -e
    test "$status" -eq 7
    test "$(cat "$TMPDIR/fail.stdout")" = "$(printf '%s\n' \
      'cleanup:fail' \
      'cleanup:group' \
      'cleanup:root')"
    grep -Fx 'command failed' "$TMPDIR/fail.stderr"

    set +e
    "$commands" group terminate \
      > "$TMPDIR/signal.stdout" \
      2> "$TMPDIR/signal.stderr"
    status=$?
    set -e
    test "$status" -eq 143
    test "$(cat "$TMPDIR/signal.stdout")" = "$(printf '%s\n' \
      'cleanup:terminate' \
      'cleanup:group' \
      'cleanup:root')"
    test ! -s "$TMPDIR/signal.stderr"

    set +e
    "$commands" group missing \
      > "$TMPDIR/unknown.stdout" \
      2> "$TMPDIR/unknown.stderr"
    status=$?
    set -e
    test "$status" -eq 3
    test "$(cat "$TMPDIR/unknown.stdout")" = "$(printf '%s\n' \
      'cleanup:group' \
      'cleanup:root')"
    grep -Fx "unknown command: 'missing'" "$TMPDIR/unknown.stderr"

    "$commands" --help > "$TMPDIR/root-help"
    grep -F 'Usage: pog-commands-fixture' "$TMPDIR/root-help"
    grep -F 'group' "$TMPDIR/root-help"
    if grep -F 'cleanup:' "$TMPDIR/root-help"; then
      echo "root help unexpectedly ran cleanup hooks" >&2
      exit 1
    fi

    "$commands" group --help > "$TMPDIR/group-help"
    grep -F 'Usage: pog-commands-fixture group' "$TMPDIR/group-help"
    grep -F 'show' "$TMPDIR/group-help"
    grep -F '(default)' "$TMPDIR/group-help"
    if grep -F 'cleanup:' "$TMPDIR/group-help"; then
      echo "command help unexpectedly ran cleanup hooks" >&2
      exit 1
    fi

    touch "$out"
  ''
