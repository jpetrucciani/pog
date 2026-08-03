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
    , persistentFlags ? [ ]
    , parsedPersistentFlags ? map (definition: flag (definition // { persistent = true; })) persistentFlags
    , exclusiveFlags ? [ ]
    , arguments ? [ ]
    , argumentCompletion ? "files"
    , commands ? [ ]
    , aliases ? [ ]
    , group ? ""
    , hidden ? false
    , parsing ? null
    , runtimeInputs ? [ ]
    , hostCommands ? [ ]
    , bashBible ? false
    , beforeExit ? ""
    , strict ? false
    , flagPadding ? 20
    , showDefaultFlags ? false
    , shortDefaultFlags ? true
    }: {}
```

`arguments` may contain strings:

```nix
arguments = [ "input" "output" ];
```

The named-set representation adds local completion metadata. `variadic` is
allowed only once and only on the final argument:

```nix
arguments = [
  {
    name = "input";
    description = "input document";
    completion = [ "stdin" "example.json" ];
  }
  {
    name = "labels";
    description = "labels to apply";
    variadic = true;
    completion = pog.completions.uniqueList {
      separator = ",";
      completion = [ "blue" "green" "red" ];
    };
  }
];
```

Legacy argument sets containing only `name` remain accepted. A command-level
`argumentCompletion` remains the fallback for arguments without their own
`completion`, and legacy Bash completion strings keep their existing calling
convention.

## completions (`pog.completions`)

Pog compiles a shell-neutral completion definition to a Carapace spec, then
generates Bash, Bash/ble.sh, Clink, Elvish, Fish, Nushell, Oil, PowerShell,
tcsh, Xonsh, and Zsh adapters from that single spec. The spec and every adapter
are included in the normal derivation output.

The ordinary package also installs `bin/_<name>_complete`. Every generated
adapter calls this entrypoint, and callers can request Carapace's structured
JSON export directly:

```console
_deploy_complete export deploy --environment d
```

The derivation exposes the paths as `package.pog.completionCommand` and
`package.pog.completionSpec`.

A bare list is shorthand for `values`, so existing definitions such as
`completion = [ "dev" "prod" ];` need no constructor. Values may include
descriptions, styles, and tags:

```nix
completion = pog.completions.values [
  {
    value = "dev";
    description = "local development";
    style = "green";
    tag = "local";
  }
  "production"
];
```

The available constructors are:

```nix
let c = pog.completions; in rec {
  static = c.values [ "one" "two" ];
  files = c.files {
    extensions = [ ".nix" ".yaml" ];
    relativeTo = "git-worktree";
  };
  directories = c.directories { relativeTo = "user-home"; };
  executables = c.executables {
    directories = [ "/opt/tool/bin" ];
  };
  generated = c.dynamic {
    runtimeInputs = [ pkgs.jq ];
    script = ''printf '%s\n' "$POG_COMPLETION_VALUE"'';
    cache = {
      ttlSeconds = 60;
      by = [ "cwd" { flag = "profile"; } { argument = 0; } ];
    };
  };
  merged = c.merge [ static files ];
  list = c.list { separator = ","; completion = static; };
  unique = c.uniqueList { separator = ","; completion = static; };
  multipart = c.multipart { separators = [ "=" ":" ]; completion = static; };
  prefixed = c.prefix { prefix = "feature/"; completion = static; };
  suffixed = c.suffix { suffix = ".json"; completion = static; };
  noSpace = c.noSpace { characters = [ "/" "=" ]; completion = static; };
  unused = c.filterUsed static;
  explained = c.withUsage { usage = "a target"; completion = static; };
  message = c.message "no candidates are available";
  delegated = c.delegate ./another-carapace-spec.yaml;
  raw = c.rawCarapace [ "$directories" ];
}
```

`relativeTo` accepts `"cwd"`, `"git-dir"`, `"git-worktree"`,
`"nix-profile"`, `"temp"`, `"user-cache"`, `"user-config"`,
`"user-home"`, `"xdg-cache"`, `"xdg-config"`, or `{ path = "..."; }`.

Dynamic providers receive a stable environment:

- `POG_COMPLETION_VALUE`, the fragment currently being completed.
- `POG_COMPLETION_INDEX`, the zero-based positional index.
- `POG_COMPLETION_DIR`, the completion working directory.
- `POG_COMPLETION_ARG_<N>` and `POG_COMPLETION_ARGS_JSON`.
- `POG_COMPLETION_FLAG_<NAME>` and `POG_COMPLETION_FLAGS_JSON`. Dashes and
  dots become underscores in the individual environment names.

Cache selectors are `"cwd"`, `"value"`, `{ flag = "name"; }`,
`{ argument = 0; }`, or `{ env = "VARIABLE"; }`. `ttlSeconds = 0` disables
caching. Cache misses execute the provider; hits reuse Carapace's on-disk
action cache.

## portable outputs

See the [portable outputs guide](/portable-outputs) for complete flake examples,
format selection, NixOS usage, CI patterns, and troubleshooting.

Each result has lazy `toArx`, `toAppImage`, and `toHostScript` passthru
derivations. The same transformations are available as functions on `pog`:

```nix
tool.toArx == pog.toArx tool
tool.toAppImage == pog.toAppImage tool
tool.toHostScript == pog.toHostScript tool
```

Each single-file derivation also exposes an app value for consumer flakes:

```nix
apps.${pkgs.stdenv.hostPlatform.system}.tool-arx = tool.toArx.app;
apps.${pkgs.stdenv.hostPlatform.system}.tool-appimage = tool.toAppImage.app;
apps.${pkgs.stdenv.hostPlatform.system}.tool-host = tool.toHostScript.app;
```

The AppImage app companion uses Nixpkgs' `appimage-run`; the underlying
single-file derivation is unchanged.

The AppImage also exposes a conventional wrapped derivation for direct nested
`nix run` selectors on NixOS:

```nix
tool.toAppImage.wrapped
```

```console
nix run .#pog.foo.toAppImage.wrapped
```

`toArx` and `toAppImage` are Linux-only, architecture-specific closure bundles.
`toHostScript` removes exact executable store references, lists its host command
dependencies in a generated header, checks for missing commands at startup, and
rejects any remaining `/nix/store` reference. It requires Bash 4 or newer and
GNU-compatible `getopt`; the single-file output does not carry the package's
completion command, spec, or shell adapters.

The output filenames are `<pname>-arx`, `<pname>.AppImage`, and
`<pname>-host-script`. Both closure bundles require Linux user namespaces.
Normal AppImage mounting additionally requires FUSE and `fusermount3`;
`APPIMAGE_EXTRACT_AND_RUN=1` selects its extraction fallback. On NixOS,
`appimage-run ./tool.AppImage` is another supported launch path. `toArx` is
experimental because simultaneous first executions can race while populating its
shared `$HOME/.cache/tmpx-<hash>` extraction cache.

`runtimeInputs` is added before the caller's `PATH` and is included in the Arx
and AppImage closure. It also contributes each package's `meta.mainProgram` to
the host-script dependency list. `hostCommands` names bare commands supplied by
the destination host. Host scripts and closure bundles check those declarations
before running.

Arx and AppImage preserve normal host paths and the caller's `PATH`, but mount
their embedded store at `/nix`. A host command backed by the host's
`/nix/store` is therefore not reachable and must be included in
`runtimeInputs`.

## subcommands (`commands`)

Pass a list of `commands` to build a clap-style dispatcher (e.g. `tool remote add`).
Each command has the same shape as a top-level `pog` call, including flags,
arguments, completion, aliases, grouping, parsing behavior, and nested
commands. Subcommands can nest to any depth.

- A command with `commands` (a "parent") dispatches to its subcommands. When no subcommand
  is given, bare invocation runs, in order of precedence: the parent's own `script` (default
  action), or a subcommand marked `default = true` (the parent forwards to it), or — if
  neither is set — auto-generated help listing the subcommands. Setting both a `script` and a
  `default = true` subcommand on the same parent is an error. The forward chains, so a default
  subcommand that is itself a parent with its own default keeps descending.
- Every command gets its own `--help`, flags, prompts, and tab completion.
- `aliases` dispatch to the same command. `group` groups commands in help, and
  `hidden = true` keeps a command out of parent help while retaining direct
  invocation.
- `persistentFlags` are accepted on their declaring command and every
  descendant, both before and after the subcommand name. Normal `flags` retain
  the legacy command-local parsing behavior.
- `parsing` accepts values from `pog.parsing`. Parents default to
  non-interspersed parsing, leaves default to interspersed parsing, and legacy
  string values remain accepted.
- `runtimeInputs` is set once at the top level and applies to all commands.
- `beforeExit` is a per-command exit hook. Each command on the active path registers its
  hook as it runs, and they fire in reverse (deepest command first, then its ancestors,
  ending with the top-level `beforeExit`) when the process exits, including on errors and
  prompt failures. Signal cleanup preserves status 130 for SIGINT and 143 for SIGTERM.
  `--help` is a no-op and fires no hooks.

```nix
{
  name = "name-of-this-command";
  description = "what this command does";  # optional
  flags = [ ];                              # optional, same as the flag spec below
  persistentFlags = [ ];                    # inherited by descendants
  exclusiveFlags = [ [ "json" "yaml" ] ]; # long names, at most one may occur
  arguments = [ ];                          # optional, for leaf commands
  argumentCompletion = "files";             # optional
  script = "";                              # leaf action, or default action for a parent
  default = false;                          # optional, mark as the parent's default subcommand
  aliases = [ "alias" ];                   # optional alternate names
  group = "operations";                    # optional help/completion group
  hidden = false;                           # optional, hide from parent help
  parsing = pog.parsing.nonInterspersed;    # optional parser override
  beforeExit = "";                          # optional, this command's exit hook
  commands = [ ];                           # optional, nest subcommands here
}
```

## parsing (`pog.parsing`)

Pog exposes four enum-style parsing values:

| Value | Recognized flags | Unknown flags | Positional behavior |
| --- | --- | --- | --- |
| `pog.parsing.interspersed` | Consumed anywhere before `--` | Error | Parsing continues after positionals |
| `pog.parsing.nonInterspersed` | Consumed before the first positional | Error before the first positional | The first positional ends parsing |
| `pog.parsing.passthrough` | Consumed anywhere before `--` | Preserved in `$@` | Positionals and unknown options retain their order |
| `pog.parsing.disabled` | Never consumed | Preserved in `$@` | The complete argv is retained |

When `parsing` is omitted, parents select `nonInterspersed` and leaves select
`interspersed`. The strings `"interspersed"`, `"non-interspersed"`,
`"passthrough"`, and `"disabled"` remain accepted for compatibility.

`passthrough` is restricted to leaf commands. Known Pog flags and their values
are removed from `$@`; all other tokens are retained exactly. `--` forces the
remaining tokens through even when their names match Pog flags. Completion for
this mode is lenient toward unknown flags so wrapper-owned completion can still
operate beside options belonging to the underlying command.

`disabled` skips CLI parsing entirely, including built-in help, verbose, and
color flags. Declared variables can still receive defaults and environment
values.

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
    , optionalValue ? false
    , repeatable ? false
    , hidden ? false
    , marker ? if bool then "" else if optionalValue then "::" else ":"
    , description ? "a flag"
    , argument ? "VAR"
    , envVar ? "POG_" + (replaceStrings [ "-" ] [ "_" ] (toUpper name))
    , required ? false
    , prompt ? if required then "true" else ""
    , promptError ? "you must specify a value for '--${name}'!"
    , promptErrorExitCode ? 3
    , hasPrompt ? (stringLength prompt) > 0
    , completion ? ""
    , hasCompletion ? !(isString completion && completion == "")
    , flagPadding ? 20
    }: {}
```

The declared `name` is used for the CLI option. Hyphens are replaced by
underscores only for the generated Bash variable and helper expressions.
`optionalValue` accepts `--flag` and `--flag=value`. `repeatable` collects a
value flag into a Bash array and turns a repeated boolean into a count. Hidden
flags remain accepted but are omitted from help and ordinary completion.
`exclusiveFlags` is declared on the containing command as groups of long flag
names; using more than one member exits with status 2.

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
