# 🤯 pog

[![uses nix](https://img.shields.io/badge/uses-nix-%237EBAE4)](https://nixos.org/)

`pog` is a [nix](https://nixos.org/) library that enables you to create comprehensive CLI tools with rich features like flag parsing, auto-documentation, tab completion, and interactive prompts - all purely in Nix leveraging the vast ecosystem of [nixpkgs](https://github.com/NixOS/nixpkgs).

## Features

- 🚀 Create full-featured CLI tools in pure Nix (and bash)
- 📖 Automatic help text generation and documentation
- 🔄 Tab completion out of the box
- 🎯 Interactive prompting capabilities
- 🎨 Rich terminal colors and styling
- 🛠 Comprehensive flag system with:
  - Short and long flag options
  - Environment variable overrides
  - Default values
  - Required flags with prompts
  - Boolean flags
  - Custom completion functions
- ⚡ Runtime input management
- 🔍 Verbose mode support
- 🎭 Color toggle support
- 🧰 Helper functions for common operations
  - `debug` for included verbose flag
  - `die` for exiting with a message and custom exit code
  - much more!

## Quick Start

regular import:

```nix
let
  pog = import (fetchTarball {
    name = "pog-2024-10-25";
    # note, you'll probably want to grab a commit sha for this instead of `main`!
    url = "https://github.com/jpetrucciani/pog/archive/main.tar.gz";
    # this is necessary, but you can find it by letting nix try to evaluate this!
    sha256 = "";
  }) {};
in
pog.pog {
  name = "meme";
  description = "A helpful CLI tool";
  flags = [
    {
      name = "config";
      description = "path to config file";
      argument = "FILE";
    }
  ];
  script = ''
    echo "Config file: $config"
    debug "Verbose mode enabled"
    echo "this is a cool tool!"
  '';
}
```

or if you want to add it as an overlay to nixpkgs, you can add
`pog.overlays.default` to your nixpkgs overlays.

using flakes:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    pog.url = "github:jpetrucciani/pog";
  };
  outputs = { self, nixpkgs, pog, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ pog.overlays.default ];
      };
    in
    {
      devShells.${system}.default = pkgs.mkShell {nativeBuildInputs = [(pkgs.pog.pog {name = "meme"; script= ''echo meme'';})];};
    };
}
```

## Testing

Run every behavioral test, including the portable Arx and AppImage runtime
checks, with:

```console
nix run .#test
```

For only the fast renderer, command, completion, and host-script checks, use:

```console
nix build .#test
```

Each focused check is also independently addressable, for example:

```console
nix build .#ordinary-flags
nix build .#ordinary-commands
nix build .#ordinary-completion
nix build .#ordinary-bash-bible
nix build .#host-negative
```

The closure bundles require a runtime smoke test outside the Nix build sandbox.
To run only that suite, build all four formats and exercise the same behavior
contract against the ordinary package, host script, Arx bundle, and AppImage:

```console
nix run .#test-portable-parity
```

CI runs the fast and portable suites as separate parallel jobs.
`nix flake check` also includes the fast suite.

## API Reference

### Main Function (`pog {}`)

The main function accepts the following arguments:

```nix
pog {
  # Required
  name = "tool-name";           # Name of your CLI tool
  script = ''
    echo "hello, world!"
  '';                           # Bash script or function that uses helpers

  # Optional
  version = "0.0.0";            # Version of your tool
  description = "...";          # Tool description
  flags = [ ];                  # List of flag definitions
  arguments = [ ];              # Positional argument names
  argumentCompletion = "files"; # Completion for positional args
  runtimeInputs = [ ];          # Dependencies shipped in Nix-backed outputs
  hostCommands = [ ];           # Commands supplied by the destination host
  bashBible = false;            # Include bash-bible helpers
  beforeExit = "";              # Code to run before exit
  strict = false;               # Enable strict bash mode
  flagPadding = 20;             # Padding for help text
  showDefaultFlags = false;     # Show built-in flags in usage
  shortDefaultFlags = true;     # Enable short versions of default flags
}
```

Positional arguments use strings as their canonical representation:

```nix
arguments = [ "path" "output" ];
```

For backward compatibility, Pog also accepts the older named-set form and
normalizes it to the same name:

```nix
arguments = [
  { name = "path"; }
];
```

The same forms may be used for nested commands. Any other value fails
evaluation with a targeted argument-shape error.

## Portable outputs

Every generated tool exposes three optional output transformations. The
transformer functions and derivation passthru attributes are equivalent:

```nix
let
  tool = pog.pog {
    name = "message";
    runtimeInputs = [ pkgs.jq ];
    script = ''
      ${pkgs.jq}/bin/jq -r .message "$1"
    '';
  };
in {
  arx = tool.toArx;                 # same as pog.pog.toArx tool
  appImage = tool.toAppImage;       # same as pog.pog.toAppImage tool
  hostScript = tool.toHostScript;   # same as pog.pog.toHostScript tool
  nixosAppImage = tool.toAppImage.wrapped;

  # Single-file derivations are not conventional $out/bin packages. Use their
  # app companions when exporting them through a flake's `apps` output.
  apps.${pkgs.stdenv.hostPlatform.system}.message-arx = tool.toArx.app;
  apps.${pkgs.stdenv.hostPlatform.system}.message-appimage = tool.toAppImage.app;
  apps.${pkgs.stdenv.hostPlatform.system}.message-host = tool.toHostScript.app;
}
```

The AppImage app companion and `.wrapped` derivation launch through Nixpkgs'
`appimage-run`, making both suitable for `nix run` on NixOS. The app value is
ready to export under `apps.<system>`. The wrapped derivation also works through
nested package selectors such as:

```console
nix run .#pog.foo.toAppImage.wrapped
```

Neither convenience changes the raw, distributable `toAppImage` artifact.

`toArx` and `toAppImage` produce single-file, architecture-specific Linux
executables containing the tool's Nix closure. Both require Linux user
namespaces at runtime. Bundling does not change the licenses or redistribution
terms of anything in that closure; publishers must review every
`runtimeInputs` dependency, especially unfree or non-redistributable packages.

Both closure bundles put `runtimeInputs` before the caller's existing `PATH`.
This lets a bundled program invoke another bundled tool while still allowing
configuration-driven plugins and helpers supplied by the destination. Declare
those external commands with `hostCommands` to check for them before the
program starts:

```nix
runtimeInputs = [ pkgs.kubectl ];
hostCommands = [ "kubectl-oidc_login" ];
```

There is one important Nix boundary. The bundle mounts its own store at `/nix`,
so a host command whose executable or interpreter lives in the host's
`/nix/store` is not accessible. Add that package to `runtimeInputs` instead:

```nix
runtimeInputs = [
  pkgs.kubectl
  pkgs.kubelogin-oidc
];
```

Files under normal host paths, including the working directory and home
directory, remain visible. Kubeconfig files and similar user configuration do
not need a separate declaration.

The output filenames are `<pname>-arx`, `<pname>.AppImage`, and
`<pname>-host-script`. Actual sizes depend on the closure. The x86_64 test
fixture containing Bash, `jq`, and their runtime libraries is approximately
17.7 MB as Arx and 20.8 MB as AppImage.

`toArx` is experimental. Its shared extraction cache lives under
`$HOME/.cache/tmpx-<hash>`, and concurrent first execution can race while
populating that cache. The launcher also needs the host commands listed in
[`pog/bundlers/README.md`](pog/bundlers/README.md).

Normal AppImage execution requires FUSE and `fusermount3`. Set
`APPIMAGE_EXTRACT_AND_RUN=1` to use the runtime's extraction fallback when FUSE
is unavailable. On NixOS, either use that fallback or run the artifact through
`appimage-run`:

```console
APPIMAGE_EXTRACT_AND_RUN=1 ./message.AppImage
nix run nixpkgs#appimage-run -- ./message.AppImage
```

`toHostScript` produces a Bash script with no Nix store references. Its header
lists the commands that must be installed on the host, and it reports all
missing commands before running. Exact executable references such as
`${pkgs.jq}/bin/jq` are converted to `jq`. Other store references, such as data
files under `${pkgs.foo}/share`, fail the host-script build rather than producing
a partly portable artifact. The host script requires Bash 4 or newer and
GNU-compatible `getopt`. It does not include the ordinary package's separately
installed Bash completion file.

The main program of each `runtimeInputs` package is included in the host-script
dependency check. Use `hostCommands` for additional commands invoked by bare
name. Closure bundles also check these commands against the destination's
`PATH`:

```nix
hostCommands = [ "git" "ssh" ];
```

Command-name conversion does not change command semantics. Scripts using
Nix-provided GNU tools such as `find` or `xargs` still require compatible GNU
implementations on the host.

Generated scripts and completions are formatted with
`shfmt -ln bash -i 2 -ci -sr`, checked with `bash -n`, and linted with
ShellCheck.

### Flag Definition

Flags are defined using the following schema:

```nix
{
  # Required
  name = "flag-name";         # Name of the flag

  # Optional
  short = "f";                # Single-char short version
  description = "...";        # Flag description
  default = "";               # Default value
  bool = false;               # Is this a boolean flag?
  argument = "VAR";           # Argument name in help text
  envVar = "POG_FLAG_NAME";   # Override env variable
  required = false;           # Is this flag required?
  prompt = "";                # Interactive prompt command
  promptError = "...";        # Error message for failed prompt
  completion = "";            # Tab completion command
  flagPadding = 20;           # Help text padding
}
```

Hyphens remain hyphens in CLI options. The generated Bash variable replaces
them with underscores, so `name = "output-format"` produces
`--output-format` and `$output_format`.

### Built-in Flag Features

- Environment variable overrides: Each flag can be set via environment variable
- Default values: Flags can have default values
- Required flags: Mark flags as required with custom error messages
- Boolean flags: Simple on/off flags
- Custom completion: Define custom tab completion for each flag
- Interactive prompts: Add interactive selection for flag values

### Helper Functions

pog provides various helper functions for common operations:

```nix
helpers = {
  fn = {
    add = "...";              # Addition helper
    sub = "...";              # Subtraction helper
    ts_to_seconds = "...";    # Timestamp conversion
  };
  var = {
    empty = name: "...";      # Check if variable is empty
    notEmpty = name: "...";   # Check if variable is not empty
  };
  file = {
    exists = name: "...";     # Check if file exists
    notExists = name: "...";  # Check if file doesn't exist
    empty = name: "...";      # Check if file is empty
    notEmpty = name: "...";   # Check if file is not empty
  };
  # ... and more
};
```

You can use these helpers by making `script` a function that takes an arg:

```nix
script = helpers: ''
    ${helpers.flag "force"} && debug "executed with --force flag!"
'';
```

## Example

Here's a bit more complete example showing various features:

```nix
pog {
  name = "deploy";
  description = "Deploy application to cloud";
  flags = [
    pog._.flags.aws.region            # this is a predefined flag from this repo, with tab completion!
    {
      name = "environment";
      short = "e";
      description = "deployment environment";
      required = true;
      completion = ''echo "dev staging prod"'';
    }
    {
      name = "force";
      bool = true;
      description = "skip confirmation prompts";
    }
  ];
  runtimeInputs = with pkgs; [
    awscli2
    kubectl
  ];
  script = helpers: with helpers; ''
    if ${flag "force"}; then
      debug "forcing deployment!"
      ${confirm { prompt = "Ready to deploy?"; }}
    fi

    ${spinner {
      command = "kubectl apply -f ./manifests/";
      title = "Deploying...";
    }}

    green "Deployment complete!"
  '';
}
```

## More (useful) examples

for more comprehensive examples, check out [this directory in my main nix repo!](https://github.com/jpetrucciani/nix/tree/main/mods/pog)

## Terminal Colors and Styling

pog includes comprehensive terminal styling capabilities:

- Text colors: black, red, green, yellow, blue, purple, cyan, grey
- Background colors: red_bg, green_bg, yellow_bg, blue_bg, purple_bg, cyan_bg, grey_bg
- Styles: bold, dim, italic, underlined, blink, invert, hidden

Colors can be disabled globally using `--no-color` or the `NO_COLOR` environment variable.

## Contributing

Feel free to open issues and pull requests! We welcome contributions to make pog even more powerful/useful.
