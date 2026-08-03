{ pkgs, pog }:
pog {
  name = "jwt-decode";
  description = "decode the payload of a JSON Web Token";
  runtimeInputs = [ pkgs.jq ];
  flags = [
    {
      name = "compact";
      short = "c";
      description = "print the decoded JSON on one line";
      bool = true;
    }
  ];
  arguments = [
    {
      name = "token";
      description = "JSON Web Token to decode";
      completion = pog.completions.message "paste a JSON Web Token";
    }
  ];
  script = ''
    jq_args=()
    if [[ -n $compact ]]; then
      jq_args+=(--compact-output)
    fi
    printf '%s\n' "$1" |
      jq "''${jq_args[@]}" -R \
        'gsub("-"; "+") | gsub("_"; "/") | split(".") | .[1] | @base64d | fromjson'
  '';
}
