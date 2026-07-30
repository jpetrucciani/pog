{ pkgs, fixtures }:
pkgs.runCommand "pog-ordinary-flags-check"
{
  nativeBuildInputs = [ pkgs.gnugrep ];
}
  ''
    flags=${fixtures.flags}/bin/pog-flags-fixture

    output="$("$flags" \
      --output-format 'json lines' \
      --dry-run \
      --required-value 'required value' \
      -- \
      'positional value' \
      '-literal')"
    test "$output" = "$(printf '%s\n' \
      'format=<json lines>' \
      'dry_run=<enabled>' \
      'required=<required value>' \
      'label=<default label>' \
      'long_only=<long default>' \
      'argc=<2>' \
      'arg=<positional value>' \
      'arg=<-literal>')"

    output="$(
      POG_OUTPUT_FORMAT='environment format' \
      POG_DRY_RUN=1 \
      POG_REQUIRED_VALUE='environment required' \
      POG_LABEL='environment label' \
      POG_LONG_ONLY='environment long' \
      "$flags" 'environment positional'
    )"
    test "$output" = "$(printf '%s\n' \
      'format=<environment format>' \
      'dry_run=<enabled>' \
      'required=<environment required>' \
      'label=<environment label>' \
      'long_only=<environment long>' \
      'argc=<1>' \
      'arg=<environment positional>')"

    output="$(
      POG_OUTPUT_FORMAT='ignored environment' \
      "$flags" \
        -f yaml \
        -n \
        -r short \
        -l 'short label' \
        --long-only 'long option' \
        argument
    )"
    test "$output" = "$(printf '%s\n' \
      'format=<yaml>' \
      'dry_run=<enabled>' \
      'required=<short>' \
      'label=<short label>' \
      'long_only=<long option>' \
      'argc=<1>' \
      'arg=<argument>')"

    set +e
    "$flags" > "$TMPDIR/required.stdout" 2> "$TMPDIR/required.stderr"
    status=$?
    set -e
    test "$status" -eq 3
    test ! -s "$TMPDIR/required.stdout"
    grep -Fx "you must specify a value for '--required-value'!" \
      "$TMPDIR/required.stderr"

    "$flags" --help > "$TMPDIR/help"
    grep -F -- '--output-format' "$TMPDIR/help"
    grep -F -- "[default: 'text']" "$TMPDIR/help"
    grep -F -- '--long-only' "$TMPDIR/help"
    if grep -F -- '--output_format' "$TMPDIR/help"; then
      echo "hyphenated flag leaked its Bash variable name into help" >&2
      exit 1
    fi

    touch "$out"
  ''
