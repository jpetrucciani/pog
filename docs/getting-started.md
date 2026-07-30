# Getting Started

## install

### fetchTarball + import

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

Or add `pog.overlays.default` to your nixpkgs overlays.

### flake

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
      meme = pkgs.pog.pog {
        name = "meme";
        script = ''echo meme'';
      };
    in
    {
      packages.${system}.default = meme;
      devShells.${system}.default = pkgs.mkShell {
        nativeBuildInputs = [ meme ];
      };
    };
}
```

Once the ordinary package works, you can also export it as a host script, Arx
bundle, or AppImage. See the [portable outputs guide](/portable-outputs).
