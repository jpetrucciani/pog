{ pkgs, pog }:
let
  ordinaryString = pog {
    name = "pog-string-argument";
    arguments = [ "string_arg" ];
    script = ":";
  };

  ordinaryNamedSet = pog {
    name = "pog-named-set-argument";
    arguments = [
      { name = "named_arg"; }
    ];
    script = ":";
  };

  subcommands = pog {
    name = "pog-mixed-subcommand-arguments";
    commands = [
      {
        name = "mixed";
        arguments = [
          "string_arg"
          { name = "named_arg"; }
        ];
        script = ":";
      }
    ];
  };

  invalidArgument =
    let
      result = pog {
        name = "pog-invalid-argument";
        arguments = [{ name = 42; }];
        script = ":";
      };
    in
    builtins.tryEval (builtins.seq result.drvPath true);
in
assert !invalidArgument.success;
pkgs.runCommand "pog-argument-compatibility-check"
{
  nativeBuildInputs = [ pkgs.gnugrep ];
}
  ''
    ${ordinaryString}/bin/pog-string-argument --help > string-help
    grep -F 'Usage: pog-string-argument' string-help
    grep -F 'STRING_ARG' string-help

    ${ordinaryNamedSet}/bin/pog-named-set-argument --help > named-set-help
    grep -F 'Usage: pog-named-set-argument' named-set-help
    grep -F 'NAMED_ARG' named-set-help

    ${subcommands}/bin/pog-mixed-subcommand-arguments mixed --help \
      > subcommand-help
    grep -F 'Usage: pog-mixed-subcommand-arguments mixed' subcommand-help
    grep -F 'STRING_ARG NAMED_ARG' subcommand-help

    touch "$out"
  ''
