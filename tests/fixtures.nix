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
    description = "exercise recursive completion rendering";
    flags = [
      {
        name = "config";
        short = "c";
        description = "select a configuration";
        completion = ''
          if [[ ''${current+x} == x && ''${previous+x} == x ]]; then
            printf '%s\n' dev prod
          fi
        '';
      }
      {
        name = "dry-run";
        short = "n";
        description = "avoid changing anything";
        bool = true;
      }
      {
        name = "long-only";
        short = "";
        description = "exercise a root long-only flag";
        bool = true;
      }
    ];
    script = ''printf '%s%s%s\n' "$config" "$dry_run" "$long_only" > /dev/null'';
    commands = [
      {
        name = "project";
        description = "manage projects";
        flags = [
          {
            name = "scope";
            short = "s";
            description = "select a project scope";
            completion = ''printf '%s\n' private public'';
          }
        ];
        script = ''printf '%s\n' "$scope" > /dev/null'';
        commands = [
          {
            name = "open";
            description = "open a project";
            argumentCompletion = ''
              if [[ $1 == "$current" ]]; then
                printf '%s\n' alpha beta
              fi
            '';
            flags = [
              {
                name = "profile";
                short = "p";
                description = "select a profile";
                completion = ''printf '%s\n' dev prod'';
              }
              {
                name = "force";
                short = "f";
                description = "force the operation";
                bool = true;
              }
              {
                name = "output-format";
                short = "";
                description = "select an output format";
                completion = ''printf '%s\n' json yaml'';
              }
            ];
            script = ''printf '%s%s%s\n' "$profile" "$force" "$output_format" > /dev/null'';
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
      {
        name = "admin";
        description = "administrative commands";
        commands = [
          {
            name = "cache";
            description = "manage caches";
            commands = [
              {
                name = "clear";
                description = "clear caches";
                script = ":";
              }
            ];
          }
        ];
      }
    ];
  };

  flatCompletion = pog {
    name = "pog-flat-completion-fixture";
    description = "exercise flat completion rendering";
    argumentCompletion = ''
      if [[ $1 == "$current" ]]; then
        printf '%s\n' alpha beta
      fi
    '';
    flags = [
      {
        name = "format";
        short = "f";
        description = "select a format";
        completion = ''printf '%s\n' json yaml'';
      }
      {
        name = "quiet";
        short = "q";
        description = "suppress output";
        bool = true;
      }
      {
        name = "long-only";
        short = "";
        description = "exercise a long-only flag";
        bool = true;
      }
    ];
    arguments = [ "value" ];
    script = ''printf '%s%s%s\n' "$format" "$quiet" "$long_only" > /dev/null'';
  };

  noShortDefaultCompletion = pog {
    name = "pog-no-short-default-completion-fixture";
    description = "exercise completion without short default flags";
    shortDefaultFlags = false;
    flags = [
      {
        name = "feature";
        short = "f";
        description = "enable a feature";
        bool = true;
      }
    ];
    script = ''printf '%s\n' "$feature" > /dev/null'';
  };

  structuredCompletion =
    let
      completion = pog.completions;
      relativeCompletionRoot = pkgs.runCommand "pog-structured-relative-completion" { } ''
        mkdir -p "$out/nested"
        touch "$out/relative.txt" "$out/ignored.json"
      '';
      completionExecutable = pkgs.writeShellApplication {
        name = "pog-structured-helper";
        text = ''true'';
      };
      delegatedSpec = pkgs.writeText "pog-delegated-completion.yaml" ''
        name: pog-delegated-completion
        completion:
          positional:
            - [delegated-one, delegated-two]
      '';
    in
    pog {
      name = "pog-structured-completion-fixture";
      description = "exercise structured completion inputs";
      flags = [
        {
          name = "environment";
          short = "e";
          description = "select an environment";
          completion = [
            {
              value = "dev";
              description = "local development";
              style = "green";
              tag = "local";
            }
            {
              value = "prod";
              description = "production environment";
              style = "red";
              tag = "remote";
            }
          ];
        }
        {
          name = "account";
          short = "a";
          description = "select an account";
          completion = [ "team-a" "team-b" ];
        }
        {
          name = "region";
          short = "r";
          description = "select a region for the current account";
          completion = completion.dynamic {
            script = ''
              case "''${POG_COMPLETION_FLAG_ACCOUNT-}" in
                team-a) printf '%s\n' us-east-1 us-west-2 ;;
                team-b) printf '%s\n' eu-west-1 ;;
              esac
            '';
          };
        }
        {
          name = "config";
          short = "c";
          description = "select a Nix or YAML configuration";
          completion = completion.files {
            extensions = [ ".nix" ".yaml" ];
          };
        }
        {
          name = "directory";
          short = "d";
          description = "select a directory";
          completion = completion.directories { };
        }
        {
          name = "cached";
          short = "C";
          description = "exercise cached dynamic completion";
          completion = completion.dynamic {
            script = ''
              printf '%s\n' "cached-''${POG_COMPLETION_FLAG_ACCOUNT-unknown}"
              if [[ -n ''${POG_COMPLETION_CACHE_LOG-} ]]; then
                printf '%s\n' invoked >> "$POG_COMPLETION_CACHE_LOG"
              fi
            '';
            cache = {
              ttlSeconds = 60;
              by = [{ flag = "account"; }];
            };
          };
        }
        {
          name = "merged";
          short = "";
          description = "merge multiple completion sources";
          completion = completion.merge [
            [ "alpha" ]
            [ "beta" ]
          ];
        }
        {
          name = "list";
          short = "";
          description = "complete a list";
          completion = completion.list {
            separator = ",";
            completion = [ "blue" "green" "red" ];
          };
        }
        {
          name = "multipart";
          short = "";
          description = "complete multipart values";
          completion = completion.multipart {
            separators = [ "=" ];
            completion = [ "key=alpha" "key=beta" "other=value" ];
          };
        }
        {
          name = "prefixed";
          short = "";
          description = "prefix completion values";
          completion = completion.prefix {
            prefix = "feature/";
            completion = [ "alpha" "beta" ];
          };
        }
        {
          name = "suffixed";
          short = "";
          description = "suffix completion values";
          completion = completion.suffix {
            suffix = ".json";
            completion = [ "alpha" "beta" ];
          };
        }
        {
          name = "executable";
          short = "";
          description = "complete executables from explicit directories";
          completion = completion.executables {
            directories = [ "${completionExecutable}/bin" ];
          };
        }
        {
          name = "relative";
          short = "";
          description = "complete files relative to another directory";
          completion = completion.files {
            extensions = [ ".txt" ];
            relativeTo = { path = "${relativeCompletionRoot}"; };
          };
        }
        {
          name = "delegated";
          short = "";
          description = "delegate to another Carapace spec";
          completion = completion.delegate delegatedSpec;
        }
        {
          name = "raw-directory";
          short = "";
          description = "accept an explicit Carapace action";
          completion = completion.rawCarapace [ "$directories" ];
        }
        {
          name = "no-space";
          short = "";
          description = "control completion spacing";
          completion = completion.noSpace {
            characters = [ "/" "=" ];
            completion = [ "path/" "key=" ];
          };
        }
        {
          name = "used";
          short = "";
          description = "filter already-used positional values";
          completion = completion.filterUsed [ "job" "service" ];
        }
        {
          name = "usage";
          short = "";
          description = "attach completion usage";
          completion = completion.withUsage {
            usage = "a deployment target";
            completion = [ "api" "web" ];
          };
        }
        {
          name = "message";
          short = "";
          description = "return a completion message";
          completion = completion.message "no candidates available";
        }
      ];
      arguments = [
        {
          name = "KIND";
          description = "resource kind";
          completion = [ "job" "service" ];
        }
        {
          name = "NAME";
          description = "resource name";
          completion = completion.dynamic {
            script = ''
              if [[ ''${POG_COMPLETION_ARG_0-} == service ]] \
                && [[ $POG_COMPLETION_INDEX == 1 ]]; then
                printf '%s\n' api web
              elif [[ ''${POG_COMPLETION_ARG_0-} == job ]]; then
                printf '%s\n' cleanup migrate
              fi
            '';
          };
        }
        {
          name = "LABELS";
          description = "comma-separated labels";
          variadic = true;
          completion = completion.uniqueList {
            separator = ",";
            completion = [ "blue" "green" "red" ];
          };
        }
      ];
      script = ''
        : "$environment" "$account" "$region" "$config" "$directory" "$cached"
        : "$merged" "$list" "$multipart" "$prefixed" "$suffixed" "$executable"
        : "$relative" "$delegated" "$raw_directory" "$no_space" "$used" "$usage" "$message"
      '';
    };

  passthrough = pog {
    name = "pog-passthrough-fixture";
    description = "exercise recognized-only flag parsing";
    parsing = pog.parsing.passthrough;
    flags = [
      {
        name = "profile";
        short = "p";
        description = "select a profile";
        default = "default";
        completion = [ "dev" "prod" ];
      }
      {
        name = "label";
        short = "l";
        description = "attach a label";
        repeatable = true;
      }
      {
        name = "color";
        short = "c";
        description = "set an optional color";
        optionalValue = true;
        default = "auto";
      }
      {
        name = "verbose-count";
        short = "V";
        description = "increase verbosity";
        bool = true;
        repeatable = true;
      }
      {
        name = "dry-run";
        short = "n";
        description = "avoid changes";
        bool = true;
      }
    ];
    arguments = [{ name = "ARG"; variadic = true; }];
    script = ''
      printf 'profile=<%s>\n' "$profile"
      printf 'labels=<%s>\n' "$(IFS=,; printf '%s' "''${label[*]}")"
      printf 'color=<%s> verbose=<%s> dry_run=<%s>\n' "$color" "$verbose_count" "$dry_run"
      printf 'args='
      if [[ $# -gt 0 ]]; then
        printf '<%s>' "$@"
      fi
      printf '\n'
    '';
  };

  advancedCommands = pog {
    name = "pog-advanced-commands-fixture";
    description = "exercise advanced command and flag behavior";
    persistentFlags = [
      {
        name = "profile";
        short = "p";
        description = "select a profile";
        default = "default";
        completion = [ "dev" "prod" ];
      }
    ];
    commands = [
      {
        name = "deploy";
        aliases = [ "ship" ];
        group = "operations";
        description = "deploy a target";
        exclusiveFlags = [ [ "json" "yaml" ] ];
        flags = [
          {
            name = "json";
            short = "j";
            description = "use JSON output";
            bool = true;
          }
          {
            name = "yaml";
            short = "y";
            description = "use YAML output";
            bool = true;
          }
          {
            name = "tag";
            short = "t";
            description = "attach a tag";
            repeatable = true;
            completion = [ "api" "worker" "web" ];
          }
          {
            name = "color";
            short = "c";
            description = "set an optional color";
            optionalValue = true;
            default = "auto";
            completion = [ "blue" "green" ];
          }
          {
            name = "secret";
            short = "s";
            description = "hidden diagnostic switch";
            bool = true;
            hidden = true;
          }
          {
            name = "verbose-count";
            short = "V";
            description = "increase verbosity";
            bool = true;
            repeatable = true;
          }
        ];
        arguments = [ "TARGET" ];
        script = ''
          printf 'profile=<%s>\n' "$profile"
          printf 'json=<%s> yaml=<%s>\n' "$json" "$yaml"
          printf 'tags=<%s>\n' "$(IFS=,; printf '%s' "''${tag[*]}")"
          printf 'color=<%s> secret=<%s> verbose=<%s>\n' "$color" "$secret" "$verbose_count"
          printf 'args=<%s>\n' "$*"
        '';
      }
      {
        name = "literal";
        group = "diagnostics";
        description = "stop parsing flags after the first argument";
        parsing = "non-interspersed";
        flags = [
          {
            name = "parsed";
            short = "P";
            bool = true;
          }
        ];
        arguments = [{ name = "ARG"; variadic = true; }];
        script = ''printf 'parsed=<%s> args=<%s>\n' "$parsed" "$*"'';
      }
      {
        name = "raw";
        group = "diagnostics";
        description = "disable flag parsing";
        parsing = "disabled";
        arguments = [{ name = "ARG"; variadic = true; }];
        script = ''printf 'args=<%s>\n' "$*"'';
      }
      {
        name = "internal";
        description = "hidden internal command";
        hidden = true;
        script = ''printf '%s\n' internal'';
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
      if [[ -n ''${POG_PORTABLE_EXTERNAL_COMMAND-} ]]; then
        "$POG_PORTABLE_EXTERNAL_COMMAND" "$1"
        exit
      fi

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

  portableHostDependency = pog {
    name = "pog-portable-host-dependency-fixture";
    description = "exercise host PATH access from closure bundles";
    hostCommands = [ "pog-external-helper" ];
    arguments = [ "value" ];
    script = ''pog-external-helper "$1" '';
  };

  invalidHostStoreReference = pog {
    name = "pog-invalid-host-store-reference";
    description = "exercise rejection of non-executable store references";
    script = ''
      printf '%s\n' ${pkgs.iana-etc}/share/iana-etc/protocols
    '';
  };
}
