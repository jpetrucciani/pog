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

or if you want to add it as an overlay to nixpkgs, you can add `pog.overlays.${system}.default` in your overlays for nixpkgs!

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
    in
    {
      packages = nixpkgs { inherit system; overlays = [ pog.overlays.${system}.default ]; };
      devShells.${system}.default = pkgs.mkShell {nativeBuildInputs = [(pkgs.pog.pog {name = "meme"; script= ''echo meme'';})];};
    };
}
```

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
  arguments = [ ];              # Positional arguments
  argumentCompletion = "files"; # Completion for positional args
  runtimeInputs = [ ];          # Runtime dependencies
  bashBible = false;            # Include bash-bible helpers
  beforeExit = "";              # Code to run before exit
  strict = false;               # Enable strict bash mode
  flagPadding = 20;             # Padding for help text
  showDefaultFlags = false;     # Show built-in flags in usage
  shortDefaultFlags = true;     # Enable short versions of default flags
}
```

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
