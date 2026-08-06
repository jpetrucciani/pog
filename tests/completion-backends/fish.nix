{ pkgs, fixtures, contract }:
let
  inherit (pkgs.lib) concatMapStringsSep concatStringsSep escapeShellArg;

  renderCase = suite: case:
    let
      label = "${suite.name}: ${case.name}";
      line = concatStringsSep " " ([ suite.command ] ++ case.words);
      expected = concatStringsSep "\n" case.expected;
    in
    ''
      assert_completion \
        ${escapeShellArg label} \
        ${escapeShellArg line} \
        ${escapeShellArg expected}
    '';

  renderSuite = suite:
    let
      package = fixtures.${suite.fixture};
      completion = "${package}/share/fish/vendor_completions.d/${suite.command}.fish";
    in
    ''
      assert_adapter ${escapeShellArg suite.name} ${escapeShellArg completion}
      POG_FISH_COMPLETION=${escapeShellArg completion}
      export POG_FISH_COMPLETION
      ${concatMapStringsSep "\n" (renderCase suite) suite.cases}
    '';

  caseCount = builtins.foldl'
    (count: suite: count + builtins.length suite.cases)
    0
    contract;
in
pkgs.runCommand "pog-fish-completion-contract"
{
  nativeBuildInputs = [ pkgs.fish ];
}
  ''
    set -o errexit -o nounset -o pipefail

    pass_count=0
    failure_count=0
    mkdir -p "$TMPDIR/completion-work/structured-dir"
    touch "$TMPDIR/completion-work/structured.nix"
    touch "$TMPDIR/completion-work/structured.yaml"
    touch "$TMPDIR/completion-work/ignored.txt"
    cd "$TMPDIR/completion-work"

    assert_adapter() {
      local suite_name=$1
      local completion=$2

      if [[ ! -s $completion ]]; then
        printf 'missing %s Fish completion: %s\n' \
          "$suite_name" \
          "$completion" >&2
        return 1
      fi
    }

    assert_completion() {
      local case_name=$1
      local line=$2
      local expected=$3
      local actual normalized_expected status

      export POG_FISH_LINE=$line
      : > "$TMPDIR/completion.stderr"
      set +o errexit
      actual="$(${pkgs.fish}/bin/fish --no-config --command '
        source "$POG_FISH_COMPLETION"
        complete -C "$POG_FISH_LINE"
      ' 2> "$TMPDIR/completion.stderr" | ${pkgs.coreutils}/bin/cut -f1 | LC_ALL=C ${pkgs.coreutils}/bin/sort -u)"
      status=$?
      set -o errexit

      normalized_expected="$(
        if [[ -n $expected ]]; then
          printf '%s\n' "$expected"
        fi | LC_ALL=C ${pkgs.coreutils}/bin/sort -u
      )"

      if [[ $status -ne 0 ]] || [[ -s $TMPDIR/completion.stderr ]]; then
        printf 'Fish completion failed for %s with status %d:\n' \
          "$case_name" \
          "$status" >&2
        cat "$TMPDIR/completion.stderr" >&2
        ((failure_count += 1))
      elif [[ $actual != "$normalized_expected" ]]; then
        printf 'Fish completion mismatch for %s\nexpected:\n%s\nactual:\n%s\n' \
          "$case_name" \
          "$normalized_expected" \
          "$actual" >&2
        ((failure_count += 1))
      else
        ((pass_count += 1))
      fi
    }

    ${concatMapStringsSep "\n" renderSuite contract}

    if [[ $pass_count -ne ${toString caseCount} ]]; then
      printf 'expected ${toString caseCount} Fish completion cases, passed %d and failed %d\n' \
        "$pass_count" \
        "$failure_count" >&2
      exit 1
    fi
    printf 'PASS: %d Fish completion cases across ${toString (builtins.length contract)} Pog outputs\n' \
      "$pass_count"

    touch "$out"
  ''
