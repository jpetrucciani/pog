{ pkgs, pog }:
let
  inherit (pkgs.lib) optionalAttrs optionals;
  isLinux = pkgs.stdenv.hostPlatform.isLinux;

  fixtures = import ./fixtures.nix {
    inherit pkgs pog;
  };

  smokeChecks = import ./checks/smoke.nix {
    inherit fixtures pkgs pog;
  };

  focusedChecks = {
    argument-compatibility = import ./checks/argument-compatibility.nix {
      inherit pkgs pog;
    };
    ordinary-flags = import ./checks/ordinary-flags.nix {
      inherit fixtures pkgs;
    };
    ordinary-commands = import ./checks/ordinary-commands.nix {
      inherit fixtures pkgs pog;
    };
    ordinary-completion = import ./checks/ordinary-completion.nix {
      inherit fixtures pkgs;
    };
    ordinary-bash-bible = import ./checks/ordinary-bash-bible.nix {
      inherit fixtures pkgs;
    };
    host-negative = import ./checks/host-negative.nix {
      inherit fixtures pkgs pog;
    };
  };

  crossPlatformSmokeChecks = builtins.removeAttrs smokeChecks [ "portable-passthru" ];
  linuxSmokeChecks = optionalAttrs isLinux {
    inherit (smokeChecks) portable-passthru;
  };
  individualChecks = crossPlatformSmokeChecks // focusedChecks // linuxSmokeChecks;
  testSuite = pkgs.linkFarm "pog-test-suite"
    (pkgs.lib.mapAttrsToList
      (name: path: { inherit name path; })
      individualChecks);
  fastCheckReports = [
    {
      name = "argument-compatibility";
      description = "string and legacy named-set positional argument forms";
      check = individualChecks.argument-compatibility;
    }
    {
      name = "ordinary-flags";
      description = "flags, defaults, environment overrides, and required values";
      check = individualChecks.ordinary-flags;
    }
    {
      name = "ordinary-commands";
      description = "nested dispatch, cleanup hooks, signals, help, and errors";
      check = individualChecks.ordinary-commands;
    }
    {
      name = "ordinary-completion";
      description = "generated command, flag, value, and argument completions";
      check = individualChecks.ordinary-completion;
    }
    {
      name = "ordinary-bash-bible";
      description = "Bash Bible rendering and string helpers";
      check = individualChecks.ordinary-bash-bible;
    }
    {
      name = "host-negative";
      description = "host dependencies, missing commands, and rejected store paths";
      check = individualChecks.host-negative;
    }
    {
      name = "portable-ordinary-script";
      description = "ordinary scripts, commands, failures, and completion installation";
      check = individualChecks.portable-ordinary-script;
    }
    {
      name = "portable-host-script";
      description = "denixified scripts, relative files, dependencies, and commands";
      check = individualChecks.portable-host-script;
    }
  ] ++ optionals isLinux [
    {
      name = "portable-passthru";
      description = "passthru and functional portable-output APIs agree";
      check = individualChecks.portable-passthru;
    }
  ];
  portableParity = import ./portable-parity.nix {
    inherit fixtures pkgs;
  };
  allTests =
    assert builtins.attrNames individualChecks
      == builtins.sort builtins.lessThan (builtins.map (report: report.name) fastCheckReports);
    pkgs.writeShellApplication {
      name = "test";
      text = ''
        printf '%s\n' 'Fast checks:'
        ${pkgs.lib.concatMapStringsSep "\n"
          (report: ''
            test -e ${report.check}
            printf '  PASS  %-28s %s\n' \
              ${pkgs.lib.escapeShellArg report.name} \
              ${pkgs.lib.escapeShellArg report.description}
          '')
          fastCheckReports}
        printf '%s\n\n' 'Fast checks passed.'

        ${pkgs.lib.optionalString isLinux ''
          ${pkgs.lib.getExe portableParity}
          printf '\n'
        ''}printf '%s\n' 'All tests passed.'
      '';
    };
in
{
  inherit allTests fixtures testSuite;

  packages = individualChecks // {
    minimal-fixture = fixtures.minimal;
    command-fixture = fixtures.commands;
    completion-fixture = fixtures.completion;
    flags-fixture = fixtures.flags;
    bash-bible-fixture = fixtures.bashBible;
    portable-fixture = fixtures.portable;
    portable-fixture-host = fixtures.portable.toHostScript;
    test = testSuite;
  } // optionalAttrs isLinux {
    portable-fixture-arx = fixtures.portable.toArx;
    portable-fixture-appimage = fixtures.portable.toAppImage;
    test-portable-parity = portableParity;
  };

  checks = individualChecks // {
    pog = testSuite;
  };
} // optionalAttrs isLinux {
  inherit portableParity;
}
