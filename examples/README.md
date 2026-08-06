# Pog examples

These are small, buildable Pog tools adapted from wrappers used in
[`jpetrucciani/nix`](https://github.com/jpetrucciani/nix/tree/main/mods/pog).
They are kept deterministic enough to run as part of Pog's normal test suite.

- `batwhich.nix` adapts `mods/pog/general.nix` and demonstrates executable
  completion, positional metadata, runtime inputs, and a normal exit error.
- `jwt-decode.nix` adapts `mods/pog/general.nix` and demonstrates a boolean
  flag, a completion message, and a real JSON transformation.
- `nix-summary.nix` adapts `mods/pog/nix.nix` and demonstrates repeatable
  flags, rich static values, directory completion, and safe filename handling.

Import all examples with:

```nix
examples = import ./examples {
  inherit pkgs;
  pog = pog.pog;
};
```

The repository flake exposes each example directly:

```console
nix build .#example-batwhich
nix run .#example-jwt-decode -- --help
nix run .#example-nix-summary -- \
  --directory examples \
  --extension nix \
  --extension md
```

Every result contains its executable, Carapace spec, installed completion
command, and all generated shell adapters. For example:

```console
nix build .#example-nix-summary
result/bin/_nix-summary_complete export nix-summary --extension n
find -L result/share/pog/completions -type f -print | sort
```

`nix build .#ordinary-examples` executes the tools and checks their completion
results without network access or credentials.
