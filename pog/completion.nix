{ name, argumentCompletion, shortDefaultFlags, parsedFlags, pkgs, ... }:
let
  inherit (builtins) concatStringsSep filter map;
in
{
  bash =
    let
      argCompletion =
        if argumentCompletion == "files" then ''
          compopt -o default
          COMPREPLY=()
        '' else ''
          completions=$(${argumentCompletion} "$current")
          # shellcheck disable=SC2207
          COMPREPLY=( $(compgen -W "$completions" -- "$current") )
        '';
    in
    pkgs.writeScript "completion.sh"
      # bash
      ''
        #! ${pkgs.bash}/bin/bash
        # shellcheck disable=SC2317
        _${name}()
        {
          local current previous completions
          compopt +o default

          flags(){
            echo "\
              ${if shortDefaultFlags then "-h -v " else ""}${concatStringsSep " " (map (x: "-${x.short}") (filter (x: x.short != "") parsedFlags))} \
              --help --verbose --no-color ${concatStringsSep " " (map (x: "--${x.name}") parsedFlags)}"
          }

          COMPREPLY=()
          current="''${COMP_WORDS[COMP_CWORD]}"
          previous="''${COMP_WORDS[COMP_CWORD-1]}"

          if [[ $current = -* ]]; then
            completions=$(flags)
            # shellcheck disable=SC2207
            COMPREPLY=( $(compgen -W "$completions" -- "$current") )
          ${concatStringsSep "\n" (map (x: x.completionBlock) parsedFlags)}
          elif [[ $COMP_CWORD = 1 ]] || [[ $previous = -* && $COMP_CWORD = 2 ]]; then
            ${argCompletion}
          else
            compopt -o default
            COMPREPLY=()
          fi
          return 0
        }
        complete -F _${name} ${name}
      '';

  fish =
    let
      completeFlag = flag: ''
        complete -c ${name} \
          -l "${flag.name}" \
          -s "${flag.short}" \
          -d "${flag.description}" \
          ${if flag.required then "-r" else ""} \
          ${if flag.hasCompletion then ''-fa "(${flag.completion})"'' else "-F"}
      '';
    in
    pkgs.writeScript "completion.fish"
      # fish
      ''
        #! ${pkgs.fish}/bin/fish
        # Plain argument completion
        complete -c ${name} ${if argumentCompletion == "files" then "-F" else "-fa (${argumentCompletion})"}

        # Flags
        ${concatStringsSep "\n" (map completeFlag parsedFlags)}
      '';
}
