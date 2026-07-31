{ pkgs
, nixBundleSrc ? builtins.fetchTarball {
    name = "nix-bundle-eff01593f627";
    url = "https://github.com/nix-community/nix-bundle/archive/eff01593f62794d458ec714090091419194ab64d.tar.gz";
    sha256 = "sha256-8YFhvulVX3iS4TYnKisA9zSImJeFN21G75HOUUFjzuE=";
  }
, nixAppImageSrc ? builtins.fetchTarball {
    name = "nix-appimage-7946addbc0d9";
    url = "https://github.com/ralismark/nix-appimage/archive/7946addbc0d97e358a6d7aefe5e82310f0fe6b18.tar.gz";
    sha256 = "sha256-jd0QwCVz4O1sHHkeaZILD/7D6oyalceEJ4EFnWCgm0k=";
  }
}:
let
  inherit (pkgs) lib;
  inherit (lib.strings) concatMapStringsSep escapeShellArg;

  requireLinux = outputName: value:
    if pkgs.stdenv.hostPlatform.isLinux
    then value
    else throw "pog.${outputName}: only Linux outputs are supported";

  programName = drv:
    drv.meta.mainProgram or (lib.getName drv);

  runtimeInputsFor = drv:
    drv.passthru.pog.runtimeInputs or [ ];

  hostCommandsFor = drv:
    drv.passthru.pog.hostCommands or [ ];

  validHostCommandsFor = outputName: drv:
    let
      commands = hostCommandsFor drv;
    in
    assert lib.assertMsg
      (lib.all (command: builtins.match "[A-Za-z0-9._+-]+" command != null) commands)
      "pog.${outputName}: host command names may only contain letters, numbers, '.', '_', '+', and '-'";
    commands;

  runtimeCommandFor = input:
    input.meta.mainProgram or (lib.getName input);

  runtimeProviderFor = input:
    lib.getName input;

  appendLine = path: value:
    "printf '%s\\n' ${escapeShellArg value} >> ${path}";

  withSingleFileApp =
    { drv
    , appProgram ? null
    , wrapped ? null
    }:
    let
      wrappedPassthru = lib.optionalAttrs (wrapped != null) {
        inherit wrapped;
      };
    in
    drv.overrideAttrs (finalAttrs: previousAttrs: {
      passthru = (previousAttrs.passthru or { }) // wrappedPassthru // {
        app = {
          type = "app";
          program =
            if appProgram == null
            then "${finalAttrs.finalPackage}"
            else appProgram;
          meta.description = "Run the ${drv.name} single-file artifact";
        };
      };
    });

  nixBundle = import "${nixBundleSrc}/default.nix" {
    nixpkgs = pkgs;
  };
  nixUserChroot = nixBundle.nix-user-chroot.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./nix-user-chroot.patch ];
  });

  appImagePkgs = pkgs.pkgsStatic;
  appImageRuntime = appImagePkgs.callPackage "${nixAppImageSrc}/runtimes/appimage-type2-runtime" { };
  appImageAppRun = appImagePkgs.callPackage "${nixAppImageSrc}/appruns/userns-chroot" { };
  mkAppImage = appImagePkgs.callPackage "${nixAppImageSrc}/mkAppImage.nix" {
    mkappimage-runtime = appImageRuntime;
    mkappimage-apprun = appImageAppRun;
  };

  portableProgramFor = outputName: drv:
    let
      name = programName drv;
      hostCommands = validHostCommandsFor outputName drv;
    in
    if hostCommands == [ ]
    then drv
    else
      pkgs.writeShellApplication {
        name = "${name}-portable-entrypoint";
        runtimeInputs = runtimeInputsFor drv;
        text = ''
          _pog_required_host_commands=(
            ${concatMapStringsSep "\n" (command: "  ${escapeShellArg command}") hostCommands}
          )
          _pog_missing_host_commands=()
          for _pog_command in "''${_pog_required_host_commands[@]}"; do
            command -v "$_pog_command" >/dev/null 2>&1 ||
              _pog_missing_host_commands+=("$_pog_command")
          done

          if (( ''${#_pog_missing_host_commands[@]} > 0 )); then
            printf 'Missing required host commands:' >&2
            printf ' %s' "''${_pog_missing_host_commands[@]}" >&2
            printf '\n' >&2
            printf '%s\n' \
              'Install them on the host PATH outside /nix/store,' \
              'or add their Nix packages to runtimeInputs.' >&2
            exit 127
          fi

          unset _pog_command _pog_missing_host_commands _pog_required_host_commands
          exec ${lib.getExe drv} "$@"
        '';
      };
in
{
  toArx = drv:
    requireLinux "toArx"
      (
        let
          program = lib.getExe (portableProgramFor "toArx" drv);
          startup = pkgs.writeScript "${lib.getName drv}-arx-startup" ''
            #!/bin/sh
            .${nixUserChroot}/bin/nix-user-chroot -n ./nix -p PATH -- ${program} "$@"
          '';
          bundle = nixBundle.makebootstrap {
            drvToBundle = {
              pname = drv.pname or (lib.getName drv);
            };
            targets = [ startup ];
            startup = ".${builtins.unsafeDiscardStringContext startup} '\"$@\"'";
          };
        in
        withSingleFileApp {
          drv = bundle.overrideAttrs (old: {
            buildCommand = old.buildCommand + ''
              rewritten="$TMPDIR/arx-with-original-cwd"
              {
                IFS= read -r first_line
                printf '%s\n' "$first_line"
                printf '%s\n' \
                  'POG_ORIGINAL_CWD=$PWD' \
                  'export POG_ORIGINAL_CWD'
                cat
              } < "$out" > "$rewritten"
              mv "$rewritten" "$out"
              chmod +x "$out"
            '';
          });
        }
      );

  toAppImage = drv:
    requireLinux "toAppImage"
      (
        let
          program = lib.getExe (portableProgramFor "toAppImage" drv);
          appImage = mkAppImage {
            inherit program;
            pname = drv.pname or (lib.getName drv);
          };
          appImageRunner = pkgs.writeShellApplication {
            name = "${lib.getName drv}-appimage-run";
            runtimeInputs = [ pkgs.appimage-run ];
            text = ''
              exec appimage-run ${appImage} "$@"
            '';
          };
        in
        withSingleFileApp {
          drv = appImage;
          appProgram = lib.getExe appImageRunner;
          wrapped = appImageRunner;
        }
      );

  toHostScript = drv:
    let
      name = programName drv;
      runtimeInputs = runtimeInputsFor drv;
      declaredHostCommands = validHostCommandsFor "toHostScript" drv;
      runtimeCommands = map runtimeCommandFor runtimeInputs;
      runtimeProviders = map runtimeProviderFor runtimeInputs;
      nixRuntimePathLine = ''export PATH="${lib.makeBinPath runtimeInputs}:$PATH"'';
      initialCommands = [
        "bash"
        "getopt"
      ] ++ runtimeCommands ++ declaredHostCommands;
      hostScript =
        pkgs.runCommand "${name}-host-script"
          {
            nativeBuildInputs = [
              pkgs.bash
              pkgs.coreutils
              pkgs.gnugrep
              pkgs.gnused
              pkgs.shellcheck
              pkgs.shfmt
            ];
            meta = {
              description = "Nix-store-free host script for ${name}";
            };
          }
          ''
            source_script=${escapeShellArg (lib.getExe drv)}
            work_script="$TMPDIR/${name}"
            required_commands="$TMPDIR/required-commands"
            runtime_providers="$TMPDIR/runtime-providers"
            executable_references="$TMPDIR/executable-references"

            cp "$source_script" "$work_script"
            sed -i '1c #!/usr/bin/env bash' "$work_script"
            substituteInPlace "$work_script" \
              --replace-fail ${escapeShellArg nixRuntimePathLine} ""

            : > "$required_commands"
            : > "$runtime_providers"
            ${concatMapStringsSep "\n" (appendLine ''"$required_commands"'') initialCommands}
            ${concatMapStringsSep "\n" (appendLine ''"$runtime_providers"'') runtimeProviders}

            grep -Eo \
              '/nix/store/[a-z0-9]{32}-[^/[:space:]"'"'"']+/bin/[A-Za-z0-9._+-]+' \
              "$work_script" |
              sort -u > "$executable_references" || true

            while IFS= read -r reference; do
              command_name="$(basename "$reference")"
              provider_path="''${reference%/bin/*}"
              provider_name="''${provider_path#/nix/store/}"
              provider_name="''${provider_name#*-}"

              substituteInPlace "$work_script" --replace-fail "$reference" "$command_name"
              printf '%s\n' "$command_name" >> "$required_commands"
              printf '%s\n' "$provider_name" >> "$runtime_providers"
            done < "$executable_references"

            sort -u -o "$required_commands" "$required_commands"
            sort -u -o "$runtime_providers" "$runtime_providers"

            if grep -nF '/nix/store/' "$work_script" > "$TMPDIR/store-references"; then
              echo "pog.toHostScript: unresolved Nix store references remain in ${name}:" >&2
              cat "$TMPDIR/store-references" >&2
              echo "Use an executable under a dependency's bin directory or keep this tool as a Nix-backed output." >&2
              exit 1
            fi

            {
              echo '#!/usr/bin/env bash'
              echo '# Generated by pog. This variant uses programs installed on the host.'
              echo '# Required commands:'
              while IFS= read -r command_name; do
                printf '#   - %s\n' "$command_name"
              done < "$required_commands"
              if [[ -s "$runtime_providers" ]]; then
                echo '# Nix providers used when this script was generated:'
                while IFS= read -r provider_name; do
                  printf '#   - %s\n' "$provider_name"
                done < "$runtime_providers"
              fi
              echo
              echo 'if (( BASH_VERSINFO[0] < 4 )); then'
              echo '  printf "%s\n" "This script requires Bash 4 or newer." >&2'
              echo '  exit 127'
              echo 'fi'
              echo
              printf '_pog_required_commands=('
              while IFS= read -r command_name; do
                printf ' %q' "$command_name"
              done < "$required_commands"
              echo ' )'
              echo '_pog_missing_commands=()'
              echo 'for _pog_command in "''${_pog_required_commands[@]}"; do'
              echo '  command -v "$_pog_command" >/dev/null 2>&1 || _pog_missing_commands+=("$_pog_command")'
              echo 'done'
              echo 'if (( ''${#_pog_missing_commands[@]} > 0 )); then'
              echo '  printf "Missing required commands:" >&2'
              echo '  printf " %s" "''${_pog_missing_commands[@]}" >&2'
              echo '  printf "\n" >&2'
              echo '  exit 127'
              echo 'fi'
              echo 'getopt --test >/dev/null'
              echo '_pog_getopt_status=$?'
              echo 'if (( _pog_getopt_status != 4 )); then'
              echo '  printf "%s\n" "This script requires GNU-compatible getopt." >&2'
              echo '  exit 127'
              echo 'fi'
              echo 'unset _pog_getopt_status'
              echo 'unset _pog_command _pog_missing_commands _pog_required_commands'
              echo
              tail -n +2 "$work_script"
            } > "$out"

            chmod 755 "$out"
            shfmt -w -ln bash -i 2 -ci -sr "$out"
            bash -n "$out"
            shfmt -d -ln bash -i 2 -ci -sr "$out"
            shellcheck "$out"
          '';
    in
    assert lib.assertMsg
      (lib.all (command: builtins.match "[A-Za-z0-9._+-]+" command != null) initialCommands)
      "pog.toHostScript: generated command names may only contain letters, numbers, '.', '_', '+', and '-'";
    withSingleFileApp { drv = hostScript; };
}
