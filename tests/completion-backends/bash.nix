{ pkgs, fixtures, contract }:
let
  inherit (pkgs.lib) concatMapStringsSep escapeShellArg escapeShellArgs;

  renderCase = suite: case:
    let
      label = "${suite.name}: ${case.name}";
      expected = builtins.concatStringsSep "\n" (case.bashExpected or case.expected);
    in
    ''
      assert_completion \
        ${escapeShellArg label} \
        ${escapeShellArg suite.command} \
        ${escapeShellArg "_${suite.command}_completion"} \
        ${escapeShellArg expected} \
        ${escapeShellArgs case.words}
    '';

  renderSuite = suite:
    let
      package = fixtures.${suite.fixture};
      completion = "${package}/share/bash-completion/completions/${suite.command}";
    in
    ''
      source_completion \
        ${escapeShellArg suite.name} \
        ${escapeShellArg suite.command} \
        ${escapeShellArg completion}
      ${concatMapStringsSep "\n" (renderCase suite) suite.cases}
    '';

  caseCount = builtins.foldl'
    (count: suite: count + builtins.length suite.cases)
    0
    contract;
in
pkgs.runCommand "pog-bash-completion-contract"
{
  nativeBuildInputs = [ pkgs.bashInteractive ];
}
  ''
    ${pkgs.bashInteractive}/bin/bash --noprofile --norc <<'BASH'
    set -o errexit -o nounset -o pipefail

    pass_count=0
    failure_count=0
    mkdir -p "$TMPDIR/completion-work/structured-dir"
    touch "$TMPDIR/completion-work/structured.nix"
    touch "$TMPDIR/completion-work/structured.yaml"
    touch "$TMPDIR/completion-work/ignored.txt"
    cd "$TMPDIR/completion-work"

    source_completion() {
      local suite_name=$1
      local command=$2
      local completion=$3

      if [[ ! -f $completion ]]; then
        printf 'missing %s Bash completion: %s\n' \
          "$suite_name" \
          "$completion" >&2
        return 1
      fi

      source "$completion"
      if ! complete -p "$command" > /dev/null; then
        printf '%s did not register completion for %s\n' \
          "$completion" \
          "$command" >&2
        return 1
      fi
    }

    assert_completion() {
      local case_name=$1
      local command=$2
      local function_name=$3
      local expected=$4
      shift 4

      COMP_WORDS=("$command" "$@")
      COMP_CWORD=$(( ''${#COMP_WORDS[@]} - 1 ))
      COMP_LINE=$command
      for word in "$@"; do
        COMP_LINE+=" $word"
      done
      COMP_POINT=''${#COMP_LINE}
      COMP_TYPE=9
      COMPREPLY=()
      : > "$TMPDIR/completion.stderr"

      set +o errexit
      "$function_name" 2> "$TMPDIR/completion.stderr"
      local status=$?
      set -o errexit

      if [[ $status -gt 1 ]]; then
        printf 'completion failed for %s with status %d\n' \
          "$case_name" \
          "$status" >&2
        cat "$TMPDIR/completion.stderr" >&2
        ((failure_count += 1))
        return 0
      fi
      if [[ -s $TMPDIR/completion.stderr ]] && \
        ${pkgs.gnugrep}/bin/grep -Fv \
          'compopt: not currently executing completion function' \
          "$TMPDIR/completion.stderr" > /dev/null; then
        printf 'completion wrote to stderr for %s:\n' "$case_name" >&2
        cat "$TMPDIR/completion.stderr" >&2
        ((failure_count += 1))
        return 0
      fi

      local actual normalized_expected
      actual="$(
        if [[ ''${#COMPREPLY[@]} -gt 0 ]]; then
          printf '%s\n' "''${COMPREPLY[@]}"
        fi | LC_ALL=C ${pkgs.coreutils}/bin/sort -u
      )"
      normalized_expected="$(
        if [[ -n $expected ]]; then
          printf '%s\n' "$expected"
        fi | LC_ALL=C ${pkgs.coreutils}/bin/sort -u
      )"

      if [[ $actual != "$normalized_expected" ]]; then
        printf 'completion mismatch for %s\nexpected:\n%s\nactual:\n%s\n' \
          "$case_name" \
          "$normalized_expected" \
          "$actual" >&2
        ((failure_count += 1))
        return 0
      fi

      ((pass_count += 1))
    }

    ${concatMapStringsSep "\n" renderSuite contract}

    if [[ $pass_count -ne ${toString caseCount} ]]; then
      printf 'expected ${toString caseCount} completion cases, passed %d and failed %d\n' \
        "$pass_count" \
        "$failure_count" >&2
      exit 1
    fi
    printf 'PASS: %d Bash completion cases across ${toString (builtins.length contract)} Pog outputs\n' \
      "$pass_count"
    BASH

    touch "$out"
  ''
