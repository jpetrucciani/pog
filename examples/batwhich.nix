{ pkgs, pog }:
pog {
  name = "batwhich";
  description = "inspect an executable found on PATH";
  runtimeInputs = [ pkgs.bat pkgs.which ];
  arguments = [
    {
      name = "command";
      description = "executable to inspect";
      completion = pog.completions.executables { };
    }
  ];
  script = ''
    if ! command_path=$(which "$1"); then
      die "command not found: $1" 127
    fi
    bat --paging=never "$command_path"
  '';
}
