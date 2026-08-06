{ pkgs, pog, fixtures }:
let
  hostScript =
    let
      hostPath = pkgs.lib.makeBinPath [
        pkgs.bash
        pkgs.coreutils
        pkgs.getopt
        pkgs.jq
      ];
      missingPath = pkgs.lib.makeBinPath [
        pkgs.bash
        pkgs.coreutils
        pkgs.getopt
      ];
    in
    pkgs.runCommand "pog-host-script-check"
      {
        nativeBuildInputs = [ pkgs.gnugrep ];
      }
      ''
        host_script=${fixtures.portable.toHostScript}
        minimal_host_script=${fixtures.minimal.toHostScript}
        command_host_script=${fixtures.commands.toHostScript}

        test -x "$host_script"
        grep -Fx '#!/usr/bin/env bash' "$host_script"
        grep -F '# Required commands:' "$host_script"
        grep -F '#   - bash' "$host_script"
        grep -F '#   - getopt' "$host_script"
        grep -F '#   - jq' "$host_script"
        grep -F '#   - tr' "$host_script"
        if grep -F '/nix/store/' "$host_script"; then
          echo "host script retained a Nix store reference" >&2
          exit 1
        fi

        mkdir work
        printf '{"message":"hello from a relative file"}\n' > work/input.json
        (
          cd work
          output="$(PATH=${hostPath} ${pkgs.bash}/bin/bash "$host_script" input.json)"
          test "$output" = 'hello from a relative file'

          output="$(PATH=${hostPath} ${pkgs.bash}/bin/bash "$host_script" --uppercase input.json)"
          test "$output" = 'HELLO FROM A RELATIVE FILE'
        )

        set +e
        PATH=${missingPath} ${pkgs.bash}/bin/bash "$host_script" work/input.json \
          > "$TMPDIR/missing.stdout" \
          2> "$TMPDIR/missing.stderr"
        status=$?
        set -e
        test "$status" -eq 127
        grep -F 'Missing required commands: jq' "$TMPDIR/missing.stderr"

        output="$(PATH=${hostPath} ${pkgs.bash}/bin/bash "$minimal_host_script")"
        test "$output" = 'literal $VALUE survives formatting'

        output="$(PATH=${hostPath} ${pkgs.bash}/bin/bash "$command_host_script" group show item)"
        test "$output" = "$(printf '%s\n' \
          'show=<item> scope=<local>' \
          'cleanup:show' \
          'cleanup:group' \
          'cleanup:root')"

        touch "$out"
      '';

  ordinary = pkgs.runCommand "pog-ordinary-script-check" { } ''
    output="$(${fixtures.minimal}/bin/pog-minimal-fixture)"
    test "$output" = 'literal $VALUE survives formatting'

    output="$(${fixtures.commands}/bin/pog-commands-fixture group show item)"
    test "$output" = "$(printf '%s\n' \
      'show=<item> scope=<local>' \
      'cleanup:show' \
      'cleanup:group' \
      'cleanup:root')"

    set +e
    ${fixtures.commands}/bin/pog-commands-fixture unknown \
      > "$TMPDIR/unknown.stdout" \
      2> "$TMPDIR/unknown.stderr"
    status=$?
    set -e
    test "$status" -eq 3

    completion=${fixtures.commands}/share/bash-completion/completions/pog-commands-fixture
    ${pkgs.bash}/bin/bash -c \
      'source "$1"; complete -p pog-commands-fixture' \
      bash \
      "$completion" \
      > "$TMPDIR/completion"
    grep -F 'complete -o noquote -F _pog-commands-fixture_completion pog-commands-fixture' \
      "$TMPDIR/completion"

    test -s ${fixtures.commands}/share/carapace/specs/pog-commands-fixture.yaml
    completion_command=${fixtures.commands}/bin/_pog-commands-fixture_complete
    test -x "$completion_command"
    test "$completion_command" = ${fixtures.commands.pog.completionCommand}
    "$completion_command" export pog-commands-fixture group s \
      > "$TMPDIR/completion-export.json"
    ${pkgs.jq}/bin/jq -e '.values | any(.value == "show")' \
      "$TMPDIR/completion-export.json" > /dev/null
    test -s ${fixtures.commands}/share/fish/vendor_completions.d/pog-commands-fixture.fish
    test -s ${fixtures.commands}/share/zsh/site-functions/_pog-commands-fixture
    test -s ${fixtures.commands}/share/nushell/vendor/autoload/pog-commands-fixture.nu
    for shell in \
      bash bash-ble cmd-clink elvish fish nushell oil powershell tcsh xonsh zsh; do
      for adapter in "${fixtures.commands}/share/pog/completions/$shell"/*; do
        test -s "$adapter"
        grep -F "$completion_command" "$adapter" > /dev/null
        if grep -F ${fixtures.commands.pog.completionSpec} "$adapter" > /dev/null; then
          echo "completion adapter bypasses installed completion command: $adapter" >&2
          exit 1
        fi
      done
    done

    touch "$out"
  '';

  passthru =
    assert fixtures.portable.toHostScript.outPath == (pog.toHostScript fixtures.portable).outPath;
    assert fixtures.portable.toArx.outPath == (pog.toArx fixtures.portable).outPath;
    assert fixtures.portable.toAppImage.outPath == (pog.toAppImage fixtures.portable).outPath;
    assert fixtures.portable.toHostScript.app.type == "app";
    assert fixtures.portable.toHostScript.app.program == fixtures.portable.toHostScript.outPath;
    assert fixtures.portable.toArx.app.type == "app";
    assert fixtures.portable.toArx.app.program == fixtures.portable.toArx.outPath;
    assert fixtures.portable.toAppImage.app.type == "app";
    assert fixtures.portable.toAppImage.app.program != fixtures.portable.toAppImage.outPath;
    assert pkgs.lib.isDerivation fixtures.portable.toAppImage.wrapped;
    assert fixtures.portable.toAppImage.app.program
      == pkgs.lib.getExe fixtures.portable.toAppImage.wrapped;
    pkgs.runCommand "pog-portable-passthru-check" { } ''
      touch "$out"
    '';
in
{
  portable-host-script = hostScript;
  portable-ordinary-script = ordinary;
  portable-passthru = passthru;
}
