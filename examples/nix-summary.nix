{ pkgs, pog }:
pog {
  name = "nix-summary";
  description = "summarize source files as a Markdown index";
  runtimeInputs = [ pkgs.coreutils pkgs.findutils pkgs.gnugrep ];
  flags = [
    {
      name = "directory";
      short = "";
      description = "directory to summarize";
      default = ".";
      completion = pog.completions.directories { };
    }
    {
      name = "extension";
      short = "e";
      description = "file extension to include";
      repeatable = true;
      completion = [ "md" "nix" "sh" ];
    }
    {
      name = "depth";
      description = "maximum directory depth";
      default = "1";
      completion = pog.completions.values [
        { value = "1"; description = "only the selected directory"; }
        { value = "2"; description = "include one nested directory"; }
        { value = "3"; description = "include two nested directories"; }
      ];
    }
  ];
  script = ''
    if [[ ''${#extension[@]} -eq 0 ]]; then
      extension=(nix)
    fi
    extension_pattern=$(IFS='|'; printf '%s' "''${extension[*]}")

    find "$directory" \
      -maxdepth "$depth" \
      -type f \
      -regextype posix-extended \
      -regex ".*\.($extension_pattern)" \
      -print0 |
      sort --zero-terminated |
      while IFS= read -r -d "" file; do
        relative_path="''${file#"$directory"/}"
        heading=$(grep --max-count 1 '^#' "$file" || true)
        heading="''${heading#\#}"
        heading="''${heading# }"
        printf '### [%s](%s)\n\n%s\n\n' \
          "$relative_path" \
          "$file" \
          "$heading"
      done
  '';
}
