{ pkgs, fixtures }:
pkgs.writeShellApplication {
  name = "test-portable-parity";
  runtimeInputs = [
    pkgs.bash
    pkgs.bzip2
    pkgs.coreutils
    pkgs.getopt
    pkgs.gnugrep
    pkgs.gnused
    pkgs.gnutar
    pkgs.jq
    pkgs.util-linux
  ];
  text = ''
    work_dir="$(mktemp -d)"
    trap 'rm -rf "$work_dir"' EXIT
    mkdir "$work_dir/work"
    printf '{"message":"portable parity"}\n' \
      > "$work_dir/work/input file.json"
    mkdir "$work_dir/host-bin"
    # shellcheck disable=SC2016
    printf '%s\n' \
      '#!${pkgs.runtimeShell}' \
      'printf "external=<%s>\n" "$1"' \
      > "$work_dir/host-bin/pog-external-helper"
    chmod +x "$work_dir/host-bin/pog-external-helper"

    assert_success() {
      local label=$1
      local description=$2
      local expected=$3
      shift 3
      local actual
      actual="$("$@")"
      if [[ $actual != "$expected" ]]; then
        printf '%s\nexpected: <%s>\nactual: <%s>\n' \
          "$label failed" \
          "$expected" \
          "$actual" >&2
        return 1
      fi
      printf '    PASS  %-28s %s\n' "$label" "$description"
    }

    assert_failure() {
      local label=$1
      local description=$2
      local expected_status=$3
      local expected_error=$4
      shift 4
      local status

      set +o errexit
      "$@" \
        > "$work_dir/$label.stdout" \
        2> "$work_dir/$label.stderr"
      status=$?
      set -o errexit

      if [[ $status -ne $expected_status ]]; then
        printf '%s\nexpected status: <%s>\nactual status: <%s>\n' \
          "$label failed" \
          "$expected_status" \
          "$status" >&2
        return 1
      fi
      if [[ -s $work_dir/$label.stdout ]]; then
        printf '%s\nunexpected stdout:\n' "$label failed" >&2
        cat "$work_dir/$label.stdout" >&2
        return 1
      fi
      if ! grep -qFx "$expected_error" "$work_dir/$label.stderr"; then
        printf '%s\nexpected stderr: <%s>\nactual stderr:\n' \
          "$label failed" \
          "$expected_error" >&2
        cat "$work_dir/$label.stderr" >&2
        return 1
      fi
      printf '    PASS  %-28s %s\n' "$label" "$description"
    }

    cd "$work_dir/work"

    printf '%s\n' 'Portable output parity:'
    printf '%s\n' '  Basic execution and relative runtime files:'
    assert_success \
      ordinary \
      'ordinary package reads JSON through its runtime dependency' \
      'portable parity' \
      ${fixtures.portable}/bin/pog-portable-fixture \
      'input file.json'
    assert_success \
      host \
      'host script matches ordinary output without Nix store paths' \
      'portable parity' \
      ${fixtures.portable.toHostScript} \
      'input file.json'
    assert_success \
      arx \
      'Arx executes the bundled Nix closure' \
      'portable parity' \
      ${fixtures.portable.toArx} \
      'input file.json'
    assert_success \
      appimage \
      'AppImage executes through its extraction fallback' \
      'portable parity' \
      env \
      APPIMAGE_EXTRACT_AND_RUN=1 \
      ${fixtures.portable.toAppImage} \
      'input file.json'

    printf '%s\n' '  Flag parsing and transformed output:'
    assert_success \
      ordinary-uppercase \
      'ordinary package handles --uppercase' \
      'PORTABLE PARITY' \
      ${fixtures.portable}/bin/pog-portable-fixture \
      --uppercase \
      'input file.json'
    assert_success \
      host-uppercase \
      'host script handles --uppercase' \
      'PORTABLE PARITY' \
      ${fixtures.portable.toHostScript} \
      --uppercase \
      'input file.json'
    assert_success \
      arx-uppercase \
      'Arx handles --uppercase' \
      'PORTABLE PARITY' \
      ${fixtures.portable.toArx} \
      --uppercase \
      'input file.json'
    assert_success \
      appimage-uppercase \
      'AppImage handles --uppercase' \
      'PORTABLE PARITY' \
      env \
      APPIMAGE_EXTRACT_AND_RUN=1 \
      ${fixtures.portable.toAppImage} \
      --uppercase \
      'input file.json'

    printf '%s\n' '  Exit status and error-output parity:'
    assert_failure \
      ordinary-failure \
      'ordinary package preserves the expected failure contract' \
      4 \
      'expected one JSON file' \
      ${fixtures.portable}/bin/pog-portable-fixture
    assert_failure \
      host-failure \
      'host script preserves the expected failure contract' \
      4 \
      'expected one JSON file' \
      ${fixtures.portable.toHostScript}
    assert_failure \
      arx-failure \
      'Arx preserves the expected failure contract' \
      4 \
      'expected one JSON file' \
      ${fixtures.portable.toArx}
    assert_failure \
      appimage-failure \
      'AppImage preserves the expected failure contract' \
      4 \
      'expected one JSON file' \
      env \
      APPIMAGE_EXTRACT_AND_RUN=1 \
      ${fixtures.portable.toAppImage}

    printf '%s\n' '  Generated help parity:'
    ordinary_help="$(${fixtures.portable}/bin/pog-portable-fixture --help)"
    assert_success \
      host-help \
      'host script help matches the ordinary package' \
      "$ordinary_help" \
      ${fixtures.portable.toHostScript} \
      --help
    assert_success \
      arx-help \
      'Arx help matches the ordinary package' \
      "$ordinary_help" \
      ${fixtures.portable.toArx} \
      --help
    assert_success \
      appimage-help \
      'AppImage help matches the ordinary package' \
      "$ordinary_help" \
      env \
      APPIMAGE_EXTRACT_AND_RUN=1 \
      ${fixtures.portable.toAppImage} \
      --help

    printf '%s\n' '  Host PATH dependencies:'
    assert_success \
      arx-host-command \
      'Arx preserves PATH for a declared external command' \
      'external=<from arx>' \
      env \
      PATH="$work_dir/host-bin:$PATH" \
      ${fixtures.portableHostDependency.toArx} \
      'from arx'
    assert_success \
      appimage-host-command \
      'AppImage preserves PATH for a declared external command' \
      'external=<from appimage>' \
      env \
      APPIMAGE_EXTRACT_AND_RUN=1 \
      PATH="$work_dir/host-bin:$PATH" \
      ${fixtures.portableHostDependency.toAppImage} \
      'from appimage'
    assert_success \
      arx-dynamic-host-command \
      'Arx exposes PATH to a configuration-selected command' \
      'external=<dynamic arx>' \
      env \
      PATH="$work_dir/host-bin:$PATH" \
      POG_PORTABLE_EXTERNAL_COMMAND=pog-external-helper \
      ${fixtures.portable.toArx} \
      'dynamic arx'
    assert_success \
      appimage-dynamic-host-command \
      'AppImage exposes PATH to a configuration-selected command' \
      'external=<dynamic appimage>' \
      env \
      APPIMAGE_EXTRACT_AND_RUN=1 \
      PATH="$work_dir/host-bin:$PATH" \
      POG_PORTABLE_EXTERNAL_COMMAND=pog-external-helper \
      ${fixtures.portable.toAppImage} \
      'dynamic appimage'
    assert_failure \
      arx-missing-host-command \
      'Arx reports a missing declared external command' \
      127 \
      'Missing required host commands: pog-external-helper' \
      ${fixtures.portableHostDependency.toArx}
    assert_failure \
      appimage-missing-host-command \
      'AppImage reports a missing declared external command' \
      127 \
      'Missing required host commands: pog-external-helper' \
      env \
      APPIMAGE_EXTRACT_AND_RUN=1 \
      ${fixtures.portableHostDependency.toAppImage}

    printf '%s\n' 'portable parity passed'
  '';
}
