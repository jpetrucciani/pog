{ pkgs, fixtures }:
let
  fixture = fixtures.structuredCompletion;
  command = "pog-structured-completion-fixture";
  completionCommand = fixture.pog.completionCommand;
in
assert completionCommand == "${fixture}/bin/_${command}_complete";
pkgs.runCommand "pog-ordinary-structured-completion-check"
{
  nativeBuildInputs = [ pkgs.gnugrep pkgs.jq ];
}
  ''
    export HOME="$TMPDIR/home"
    export XDG_CACHE_HOME="$TMPDIR/cache"
    export CARAPACE_COLOR=1
    export POG_COMPLETION_CACHE_LOG="$TMPDIR/provider.log"
    mkdir -p "$HOME" "$XDG_CACHE_HOME"
    completion_command=${completionCommand}
    test -x "$completion_command"

    assert_equal() {
      local description=$1
      local expected=$2
      local actual=$3
      if [[ $actual != "$expected" ]]; then
        printf '%s: expected %q, got %q\n' "$description" "$expected" "$actual" >&2
        return 1
      fi
    }

    ${fixture}/bin/${command} --help > "$TMPDIR/help"
    grep -Fx '  Arguments:' "$TMPDIR/help"
    grep -F 'KIND' "$TMPDIR/help" | grep -F 'resource kind'
    grep -F 'LABELS...' "$TMPDIR/help" | grep -F 'comma-separated labels'

    "$completion_command" export ${command} --environment d \
      > "$TMPDIR/rich.json"
    jq -e '
      .values[]
      | select(
          .value == "dev"
          and .description == "local development"
          and .style == "green"
          and .tag == "local"
        )
    ' "$TMPDIR/rich.json" > /dev/null

    "$completion_command" export ${command} \
      --account team-a --region us- > "$TMPDIR/context.json"
    assert_equal "dynamic flag context" "us-east-1 us-west-2" \
      "$(jq -r '[.values[].value] | sort | join(" ")' "$TMPDIR/context.json")"

    "$completion_command" export ${command} \
      --usage a > "$TMPDIR/usage.json"
    assert_equal "completion usage" "a deployment target" \
      "$(jq -r '.usage' "$TMPDIR/usage.json")"

    "$completion_command" export ${command} \
      --no-space path > "$TMPDIR/no-space.json"
    assert_equal "no-space characters" "/=" \
      "$(jq -r '.nospace' "$TMPDIR/no-space.json")"

    "$completion_command" export ${command} \
      --message "" > "$TMPDIR/message.json"
    assert_equal "completion message" "no candidates available" \
      "$(jq -r '.messages | join(" ")' "$TMPDIR/message.json")"

    "$completion_command" export ${command} \
      --account team-a --cached "" > "$TMPDIR/cache-first.json"
    "$completion_command" export ${command} \
      --account team-a --cached "" > "$TMPDIR/cache-second.json"
    assert_equal "same-key provider invocations" 1 \
      "$(wc -l < "$POG_COMPLETION_CACHE_LOG")"
    assert_equal "same-key cached value" "cached-team-a" \
      "$(jq -r '.values[0].value' "$TMPDIR/cache-second.json")"

    "$completion_command" export ${command} \
      --account team-b --cached "" > "$TMPDIR/cache-other-key.json"
    assert_equal "distinct-key provider invocations" 2 \
      "$(wc -l < "$POG_COMPLETION_CACHE_LOG")"
    assert_equal "distinct-key cached value" "cached-team-b" \
      "$(jq -r '.values[0].value' "$TMPDIR/cache-other-key.json")"

    touch "$out"
  ''
