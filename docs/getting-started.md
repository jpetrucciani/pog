## fetchTarball + import

```nix
let
  pog = import (fetchTarball {
    name = "pog-2024-10-25";
    # note, you'll probably want to grab a commit sha for this instead of `main`!
    url = "https://github.com/jpetrucciani/pog/main.tar.gz";
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

## flake

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
