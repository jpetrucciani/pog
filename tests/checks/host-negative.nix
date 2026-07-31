{ pkgs, pog, fixtures }:
let
  rejectedStoreReference =
    pkgs.testers.testBuildFailure fixtures.invalidHostStoreReference.toHostScript;

  invalidCommandName =
    let
      result = pog {
        name = "pog-invalid-host-command";
        hostCommands = [ "not a command" ];
        script = ":";
      };
    in
    builtins.tryEval (builtins.seq result.toHostScript.drvPath true);

  invalidArxCommandName =
    let
      result = pog {
        name = "pog-invalid-arx-host-command";
        hostCommands = [ "not a command" ];
        script = ":";
      };
    in
    builtins.tryEval (builtins.seq result.toArx.drvPath true);

  invalidAppImageCommandName =
    let
      result = pog {
        name = "pog-invalid-appimage-host-command";
        hostCommands = [ "not a command" ];
        script = ":";
      };
    in
    builtins.tryEval (builtins.seq result.toAppImage.drvPath true);

  availablePath = pkgs.lib.makeBinPath [
    pkgs.bash
    pkgs.coreutils
    pkgs.curl
    pkgs.getopt
    pkgs.git
    pkgs.jq
  ];
  missingPath = pkgs.lib.makeBinPath [
    pkgs.bash
    pkgs.coreutils
    pkgs.getopt
  ];
in
assert !invalidCommandName.success;
assert !invalidArxCommandName.success;
assert !invalidAppImageCommandName.success;
pkgs.runCommand "pog-host-negative-check"
{
  nativeBuildInputs = [ pkgs.gnugrep ];
}
  ''
    host_script=${fixtures.hostDependencies.toHostScript}

    grep -F '#   - curl' "$host_script"
    grep -F '#   - git' "$host_script"
    grep -F '#   - jq' "$host_script"

    output="$(PATH=${availablePath} ${pkgs.bash}/bin/bash "$host_script")"
    test "$output" = 'host dependencies available'

    set +e
    PATH=${missingPath} ${pkgs.bash}/bin/bash "$host_script" \
      > "$TMPDIR/missing.stdout" \
      2> "$TMPDIR/missing.stderr"
    status=$?
    set -e
    test "$status" -eq 127
    test ! -s "$TMPDIR/missing.stdout"
    grep -Fx 'Missing required commands: curl git jq' \
      "$TMPDIR/missing.stderr"

    test "$(cat ${rejectedStoreReference}/testBuildFailure.exit)" -eq 1
    grep -F 'pog.toHostScript: unresolved Nix store references remain' \
      ${rejectedStoreReference}/testBuildFailure.log
    grep -F "Use an executable under a dependency's bin directory" \
      ${rejectedStoreReference}/testBuildFailure.log

    touch "$out"
  ''
