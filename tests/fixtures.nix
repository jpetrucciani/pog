{ pkgs, pog }:
rec {
  minimal = pog {
    name = "pog-minimal-fixture";
    description = "exercise minimal pog rendering";
    script = ''
      cat <<'EOF'
      literal $VALUE survives formatting
      EOF
    '';
  };

  flags = pog {
    name = "pog-flags-fixture";
    description = "exercise the pog flag contract";
    showDefaultFlags = true;
    flags = [
      {
        name = "output-format";
        short = "f";
        description = "select an output format";
        default = "text";
      }
      {
        name = "dry-run";
        short = "n";
        description = "avoid changing anything";
        bool = true;
      }
      {
        name = "required-value";
        short = "r";
        description = "a required value";
        required = true;
      }
      {
        name = "label";
        short = "l";
        description = "attach a label";
        default = "default label";
      }
      {
        name = "long-only";
        short = "";
        description = "exercise a long-only flag";
        default = "long default";
      }
    ];
    arguments = [ "value" ];
    script = helpers: ''
      if ${helpers.flag "dry_run"}; then
        dry_run_state=enabled
      else
        dry_run_state=disabled
      fi

      printf 'format=<%s>\n' "$output_format"
      printf 'dry_run=<%s>\n' "$dry_run_state"
      printf 'required=<%s>\n' "$required_value"
      printf 'label=<%s>\n' "$label"
      printf 'long_only=<%s>\n' "$long_only"
      printf 'argc=<%s>\n' "$#"
      for fixture_argument in "$@"; do
        printf 'arg=<%s>\n' "$fixture_argument"
      done
    '';
  };

  commands = pog {
    name = "pog-commands-fixture";
    description = "exercise recursive command behavior";
    beforeExit = ''printf '%s\n' 'cleanup:root' '';
    commands = [
      {
        name = "group";
        description = "a parent command";
        beforeExit = ''printf '%s\n' 'cleanup:group' '';
        flags = [
          {
            name = "scope";
            short = "s";
            description = "select a scope";
            default = "local";
          }
        ];
        commands = [
          {
            name = "show";
            description = "show a value";
            default = true;
            beforeExit = ''printf '%s\n' 'cleanup:show' '';
            arguments = [ "value" ];
            script = ''printf 'show=<%s> scope=<%s>\n' "''${1:-default}" "$scope"'';
          }
          {
            name = "fail";
            description = "fail with a known status";
            beforeExit = ''printf '%s\n' 'cleanup:fail' '';
            script = ''die "command failed" 7'';
          }
          {
            name = "terminate";
            description = "terminate itself";
            beforeExit = ''printf '%s\n' 'cleanup:terminate' '';
            script = ''
              kill -TERM "$$"
              printf '%s\n' 'continued after SIGTERM'
            '';
          }
          {
            name = "nested";
            description = "a second command level";
            beforeExit = ''printf '%s\n' 'cleanup:nested' '';
            commands = [
              {
                name = "leaf";
                description = "a deeply nested leaf";
                beforeExit = ''printf '%s\n' 'cleanup:leaf' '';
                arguments = [ "value" ];
                script = ''printf 'leaf=<%s>\n' "''${1:-missing}"'';
              }
            ];
          }
        ];
      }
      {
        name = "status";
        description = "show fixture status";
        script = ''printf '%s\n' 'status:ok' '';
      }
    ];
  };

  completion = pog {
    name = "pog-completion-fixture";
    description = "exercise generated Bash completion";
    commands = [
      {
        name = "project";
        description = "manage projects";
        commands = [
          {
            name = "open";
            description = "open a project";
            argumentCompletion = ''${pkgs.bash}/bin/bash -c 'printf "%s\n" alpha beta' --'';
            flags = [
              {
                name = "profile";
                short = "p";
                description = "select a profile";
                completion = ''printf '%s\n' dev prod'';
              }
            ];
            script = ''printf '%s\n' "$profile" > /dev/null'';
          }
          {
            name = "list";
            description = "list projects";
            script = ":";
          }
        ];
      }
      {
        name = "status";
        description = "show status";
        script = ":";
      }
    ];
  };

  bashBible = pog {
    name = "pog-bash-bible-fixture";
    description = "exercise Bash Bible rendering";
    bashBible = true;
    script = ''
      printf 'reverse=<%s>\n' "$(reverse_case 'aBc Z-123')"
      printf 'trim=<%s>\n' "$(trim_string '  spaced value  ')"
    '';
  };

  portable = pog {
    name = "pog-portable-fixture";
    description = "exercise pog portable output formats";
    runtimeInputs = [ pkgs.jq ];
    flags = [
      {
        name = "uppercase";
        short = "u";
        description = "uppercase the selected value";
        bool = true;
      }
    ];
    arguments = [ "json_file" ];
    script = helpers: ''
      if [[ $# -ne 1 ]]; then
        die "expected one JSON file" 4
      fi

      value="$(${pkgs.jq}/bin/jq -r '.message' "$1")"
      if ${helpers.flag "uppercase"}; then
        printf '%s\n' "$value" | ${pkgs.coreutils}/bin/tr '[:lower:]' '[:upper:]'
      else
        printf '%s\n' "$value"
      fi
    '';
  };

  hostDependencies = pog {
    name = "pog-host-dependencies-fixture";
    description = "exercise declared host dependencies";
    runtimeInputs = [ pkgs.jq ];
    hostCommands = [
      "curl"
      "git"
    ];
    script = ''printf '%s\n' 'host dependencies available' '';
  };

  invalidHostStoreReference = pog {
    name = "pog-invalid-host-store-reference";
    description = "exercise rejection of non-executable store references";
    script = ''
      printf '%s\n' ${pkgs.iana-etc}/share/iana-etc/protocols
    '';
  };
}
