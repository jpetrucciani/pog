{ pkgs, fixtures }:
pkgs.runCommand "pog-ordinary-completion-check" { } ''
    completion=${fixtures.completion}/share/bash-completion/completions/pog-completion-fixture

    ${pkgs.bash}/bin/bash -s "$completion" <<'BASH'
    set -o errexit -o nounset -o pipefail
    source "$1"

    assert_completion() {
      local expected=$1
      shift
      COMP_WORDS=("$@")
      COMP_CWORD=$(( ''${#COMP_WORDS[@]} - 1 ))
      COMPREPLY=()
      _pog-completion-fixture

      local actual
      actual="$(printf '%s\n' "''${COMPREPLY[@]}")"
      if [[ $actual != "$expected" ]]; then
        printf 'completion mismatch\nexpected:\n%s\nactual:\n%s\n' \
          "$expected" \
          "$actual" >&2
        return 1
      fi
    }

    assert_completion \
      $'project\nstatus' \
      pog-completion-fixture \
      ""

    assert_completion \
      $'open\nlist' \
      pog-completion-fixture \
      project \
      ""

    assert_completion \
      '--profile' \
      pog-completion-fixture \
      project \
      open \
      --pr

    assert_completion \
      '-p' \
      pog-completion-fixture \
      project \
      open \
      -p

    assert_completion \
      'dev' \
      pog-completion-fixture \
      project \
      open \
      --profile \
      d

    assert_completion \
      'alpha' \
      pog-completion-fixture \
      project \
      open \
      a
  BASH

    touch "$out"
''
