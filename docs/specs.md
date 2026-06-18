# specs

## pog spec

```nix
pog =
    { name
    , version ? "0.0.0"
    , script ? ""
    , description ? "a helpful bash script with flags, created through nix + pog!"
    , flags ? [ ]
    , parsedFlags ? map flag flags
    , arguments ? [ ]
    , argumentCompletion ? "files"
    , commands ? [ ]
    , runtimeInputs ? [ ]
    , bashBible ? false
    , beforeExit ? ""
    , strict ? false
    , flagPadding ? 20
    , showDefaultFlags ? false
    , shortDefaultFlags ? true
    }: {}
```

## subcommands (`commands`)

Pass a list of `commands` to build a clap-style dispatcher (e.g. `tool remote add`).
Each command has the same shape as a top-level `pog` call — `name`, `description`,
`flags`, `arguments`, `script` — and may itself contain a nested `commands` list, so
subcommands can nest to any depth.

- A command with `commands` (a "parent") dispatches to its subcommands. If it also has a
  `script`, that script runs as the **default action** when no subcommand is given;
  otherwise bare invocation prints auto-generated help listing the subcommands.
- Every command gets its own `--help`, flags, prompts, and tab completion.
- `runtimeInputs` is set once at the top level and applies to all commands.
- `beforeExit` is a per-command exit hook. Each command on the active path registers its
  hook as it runs, and they fire in reverse (deepest command first, then its ancestors,
  ending with the top-level `beforeExit`) when the process exits — including on errors and
  prompt failures. `--help` is a no-op and fires no hooks.

```nix
{
  name = "name-of-this-command";
  description = "what this command does";  # optional
  flags = [ ];                              # optional, same as the flag spec below
  arguments = [ ];                          # optional, for leaf commands
  argumentCompletion = "files";             # optional
  script = "";                              # leaf action, or default action for a parent
  beforeExit = "";                          # optional, this command's exit hook
  commands = [ ];                           # optional, nest subcommands here
}
```

## flag spec

```nix
flag =
    { name
    , _name ? (replaceStrings [ "-" ] [ "_" ] name)
    , short ? substring 0 1 name
    , shortDef ? if short != "" then "-${short}|" else ""
    , default ? ""
    , hasDefault ? (stringLength default) > 0
    , bool ? false
    , marker ? if bool then "" else ":"
    , description ? "a flag"
    , argument ? "VAR"
    , envVar ? "POG_" + (replaceStrings [ "-" ] [ "_" ] (toUpper name))
    , required ? false
    , prompt ? if required then "true" else ""
    , promptError ? "you must specify a value for '--${name}'!"
    , promptErrorExitCode ? 3
    , hasPrompt ? (stringLength prompt) > 0
    , completion ? ""
    , hasCompletion ? (stringLength completion) > 0
    , flagPadding ? 20
    }: {}
```

## full spec example

```nix
  foo = pog {
    name = "foo";
    description = "a tester script for pog, my classic bash bin + flag + bashbible meme";
    bashBible = true;
    beforeExit = ''
      green "this is beforeExit - foo test complete!"
    '';
    flags = [
      _.flags.common.color
      {
        name = "functions";
        short = "";
        description = "list all functions! (this is a lot of text)";
        bool = true;
      }
    ];
    script = h: with h; ''
      color="''${color^^}"
      trim_string "     foo       "
      upper 'foo'
      lower 'FOO'
      lstrip "The Quick Brown Fox" "The "
      urlencode "https://github.com/dylanaraps/pure-bash-bible"
      remove_array_dups 1 1 2 2 3 3 3 3 3 4 4 4 4 4 5 5 5 5 5 5
      hex_to_rgb "#FFFFFF"
      rgb_to_hex "255" "255" "255"
      date "%a %d %b  - %l:%M %p"
      uuid
      bar 1 10
      ''${functions:+get_functions}
      debug "''${GREEN}this is a debug message, only visible when passing -v (or setting POG_VERBOSE)!"
      black "this text is 'black'"
      red "this text is 'red'"
      green "this text is 'green'"
      yellow "this text is 'yellow'"
      blue "this text is 'blue'"
      purple "this text is 'purple'"
      cyan "this text is 'cyan'"
      grey "this text is 'grey'"
      green_bg "this text has a green background"
      purple_bg "this text has a purple background"
      yellow_bg "this text has a yellow background"
      bold "this text should be bold!"
      dim "this text should be dim!"
      italic "this text should be italic!"
      underlined "this text should be underlined!"
      blink "this text might blink on certain terminal emulators!"
      invert "this text should be inverted!"
      hidden "this text should be hidden!"
      echo -e "''${GREEN_BG}''${RED}this text is red on a green background and looks awful''${RESET}"
      echo -e "''${!color}this text has its color set by a flag '--color' or env var 'POG_COLOR' (default green)''${RESET}"
      ${spinner {command="sleep 3";}}
      ${confirm {exit_code=69;}}
      die "this is a die" 0
    '';
  };
```
