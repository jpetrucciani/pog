# Portable outputs

A `pog` definition normally builds a Nix package containing a generated Bash
CLI. The same definition can also produce three opt-in, single-file outputs:

- `toHostScript`, a denixified script that uses commands from the host `PATH`.
- `toArx`, an experimental Linux executable containing the tool's Nix closure.
- `toAppImage`, a Linux AppImage containing the tool's Nix closure.

The transformations happen after Pog has rendered, formatted, and checked the
final script. Flags, nested commands, help text, cleanup hooks, and script
behavior therefore come from one source definition.

## Quick start

This flake exports one tool as an ordinary Nix package and in all three portable
formats:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    pog.url = "github:jpetrucciani/pog";
  };

  outputs = { nixpkgs, pog, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ pog.overlays.default ];
      };

      message = pkgs.pog.pog {
        name = "message";
        description = "read a message from JSON";
        runtimeInputs = [ pkgs.jq ];
        flags = [
          {
            name = "uppercase";
            short = "u";
            description = "uppercase the message";
            bool = true;
          }
        ];
        arguments = [ "json_file" ];
        script = helpers: ''
          value="$(${pkgs.jq}/bin/jq -r '.message' "$1")"
          if ${helpers.flag "uppercase"}; then
            printf '%s\n' "$value" |
              ${pkgs.coreutils}/bin/tr '[:lower:]' '[:upper:]'
          else
            printf '%s\n' "$value"
          fi
        '';
      };
    in
    {
      packages.${system} = {
        default = message;
        message-host = message.toHostScript;
        message-arx = message.toArx;
        message-appimage = message.toAppImage;
        message-appimage-wrapped = message.toAppImage.wrapped;
      };

      apps.${system} = {
        default = {
          type = "app";
          program = pkgs.lib.getExe message;
        };
        message-host = message.toHostScript.app;
        message-arx = message.toArx.app;
        message-appimage = message.toAppImage.app;
      };
    };
}
```

Build the single-file artifacts:

```console
nix build .#message-host --out-link result-host
nix build .#message-arx --out-link result-arx
nix build .#message-appimage --out-link result-appimage
```

Or run their app companions:

```console
nix run .#message-arx -- input.json
nix run .#message-appimage -- --uppercase input.json
```

On NixOS, the AppImage's wrapped derivation is also directly runnable:

```console
nix run .#message-appimage.wrapped -- --uppercase input.json
```

The host-script app still expects its declared commands to be installed on the
host:

```console
nix run .#message-host -- input.json
```

## Choosing a format

| Output | Dependencies at runtime | Supported hosts | Best use |
| --- | --- | --- | --- |
| Ordinary package | Nix store closure | Any system supported by the package set | NixOS, development shells, and Nix-managed machines |
| `toHostScript` | Bash 4+, GNU-compatible `getopt`, and declared host commands | Hosts with compatible shell tooling | Bootstrap scripts, managed fleets, and readable handoff artifacts |
| `toArx` | Embedded Nix closure plus a small set of launcher commands | Linux on the architecture it was built for | Internal distribution where closure fidelity matters most |
| `toAppImage` | Embedded Nix closure, Linux user namespaces, and FUSE or extraction | Linux on the architecture it was built for | A familiar single-file Linux application |

Use `toHostScript` when the destination already has the required tools and you
want a readable script with no Nix store references. Use `toAppImage` for the
most conventional single-file Linux experience. Use `toArx` when you want to
experiment with the smallest closure bundle and can accept its cache
limitations.

::: warning Architecture-specific output
Arx and AppImage artifacts are not universal Linux binaries. Build and test one
artifact for every architecture you publish, such as `x86_64-linux` and
`aarch64-linux`.
:::

## Two equivalent APIs

The portable derivations are available as passthru attributes:

```nix
message.toHostScript
message.toArx
message.toAppImage
```

The same transformations are available as functions:

```nix
pkgs.pog.pog.toHostScript message
pkgs.pog.pog.toArx message
pkgs.pog.pog.toAppImage message
```

The ordinary `message` derivation does not fetch or build either bundler. The
portable work remains lazy until a transformation is evaluated.

## Running single-file outputs through Nix

The portable derivations deliberately produce a file at `$out`, not a
conventional package directory containing `$out/bin/<program>`. That makes
`nix build` create a result symlink directly to the distributable file, but it
also means the derivation itself is not a normal `nix run` target.

Each output therefore exposes a flake app value:

```nix
apps.${system}.message-host = message.toHostScript.app;
apps.${system}.message-arx = message.toArx.app;
apps.${system}.message-appimage = message.toAppImage.app;
```

The host-script and Arx app companions execute their files directly. The
AppImage app companion uses Nixpkgs' `appimage-run`, which makes
`nix run .#message-appimage` work on NixOS without relying on a host
`fusermount3`.

The AppImage also exposes the same runner as a conventional derivation:

```nix
message.toAppImage.wrapped
```

Unlike an app value, a derivation can be addressed below `packages` or
`legacyPackages`. This makes nested selectors runnable without adding a
top-level app alias:

```console
nix run .#message-appimage.wrapped -- input.json
nix run .#pog.foo.toAppImage.wrapped -- --help
```

Use `.app` when defining a consumer flake's `apps.<system>` output. Use
`.wrapped` when you want a conventional Nix package or a directly runnable
nested selector. Both are Nix conveniences and use `appimage-run`; neither
alters the distributable single-file artifact.

## Host scripts and dependency discovery

`toHostScript` removes the generated Nix `PATH` and translates exact executable
references into command names. For example:

```nix
runtimeInputs = [ pkgs.jq ];

script = ''
  ${pkgs.jq}/bin/jq -r '.message' "$1"
'';
```

becomes a call to `jq`. The generated header records the required command and
the Nix provider used when creating the script.

Pog automatically adds the main program from every `runtimeInputs` package.
Declare commands invoked by bare name with `hostCommands`:

```nix
hostCommands = [ "curl" "git" ];

script = ''
  git status --short
  curl --fail --silent --show-error https://example.com/health
'';
```

At startup, the host script checks every required command and reports all
missing commands together:

```text
Missing required commands: curl git jq
```

The generated header lists command names rather than guessing package-manager
names:

```bash
# Generated by pog. This variant uses programs installed on the host.
# Required commands:
#   - bash
#   - curl
#   - getopt
#   - git
#   - jq
```

## Bundled and host-provided dependencies

Arx and AppImage use two explicit dependency modes:

| Dependency | Declaration | Result |
| --- | --- | --- |
| A command that must travel with the artifact | `runtimeInputs = [ pkgs.foo ];` | Its closure is embedded and its `bin` directory is placed before the caller's `PATH`. |
| A command supplied by the destination | `hostCommands = [ "foo" ];` | The caller's `PATH` is preserved and the artifact reports the command if it is missing. |
| A host file or configuration directory | No Pog declaration | Normal host paths, the working directory, and the home directory remain visible. Pass the path or its usual environment variable. |

This distinction matters for tools that discover plugins dynamically. Kubernetes
clients, for example, can execute a credential plugin named by kubeconfig:

```nix
let
  k = pog {
    name = "k";
    runtimeInputs = [ pkgs.kubectl ];
    hostCommands = [ "kubectl-oidc_login" ];
    script = ''kubectl "$@"'';
  };
in
k.toArx
```

That form intentionally relies on `kubectl-oidc_login` being installed on the
destination's `PATH`. It works when the command is a native host executable,
such as one under `/usr/local/bin`.

### The host Nix store is not merged

Both launchers mount the artifact's embedded store at `/nix`. This hides the
host's own `/nix/store`, so profile links such as
`$HOME/.nix-profile/bin/kubectl-oidc_login` cannot reach a host Nix package from
inside the artifact. Preserving `PATH` alone cannot repair that link.

Bundle the plugin when the destination installs it through Nix:

```nix
runtimeInputs = [
  pkgs.kubectl
  pkgs.kubelogin-oidc
];
```

This is also the reliable choice when every destination must use the same
plugin version. Keep `hostCommands` for intentionally host-managed or
configuration-selected commands. Undeclared commands can still resolve from
the caller's `PATH`, which supports kubeconfig-selected plugins whose names are
not known when the artifact is built, but declaring known commands produces a
clear startup error.

### Store data is intentionally rejected

Only exact executable references under a dependency's `bin` directory can be
translated safely. A data reference such as:

```nix
script = ''
  cat ${pkgs.example}/share/example/data.json
'';
```

causes the host-script build to fail. Pog prints the offending line and asks you
to use an executable dependency or retain the Nix-backed output. It never emits
a supposedly portable script containing hidden `/nix/store` dependencies.

## AppImage on NixOS

The raw AppImage supports the usual AppImage launch modes. If FUSE and
`fusermount3` are available:

```console
./message.AppImage input.json
```

Use the extraction fallback when FUSE mounting is unavailable:

```console
APPIMAGE_EXTRACT_AND_RUN=1 ./message.AppImage input.json
```

On NixOS, `appimage-run` is another supported path:

```console
nix run nixpkgs#appimage-run -- ./message.AppImage input.json
```

When you export `message.toAppImage.app`, Pog wires `appimage-run`
automatically:

```console
nix run .#message-appimage -- input.json
```

The wrapped passthru provides the same NixOS launch path without a top-level app
export:

```console
nix run .#message-appimage.wrapped -- input.json
```

All AppImage modes still require Linux user namespaces.

## Arx behavior and limitations

Arx packages the program and its Nix closure into a compressed executable. The
launcher extracts the closure into a shared cache under:

```text
$HOME/.cache/tmpx-<hash>
```

The caller's working directory and normal host paths remain visible to the
program. Arx preserves the caller's `PATH`; bundled `runtimeInputs` still take
precedence once the Pog program starts. The launcher itself still expects these
host commands:

```text
sh sed tr date head tar hexdump bzip2
```

Arx also requires Linux user namespaces. Its upstream cache population is not
atomic, so simultaneous first executions of the same artifact can race.
`toArx` is therefore experimental.

## Copying and publishing artifacts

Nix build results are symlinks into the store. Dereference the symlink when
preparing a release directory:

```console
mkdir -p dist

nix build .#message-arx --out-link result-arx
nix build .#message-appimage --out-link result-appimage
nix build .#message-host --out-link result-host

cp -L result-arx dist/message-x86_64-linux-arx
cp -L result-appimage dist/message-x86_64-linux.AppImage
cp -L result-host dist/message-host
chmod 755 dist/message-*
```

Use architecture names in published filenames. Before publishing, copy the
exact files to a Linux machine or CI runner without Nix installed and exercise
the real CLI contract there.

Bundling preserves the license and redistribution obligations of every path in
the closure. Review `runtimeInputs` before distributing an Arx or AppImage,
especially when a dependency is unfree or non-redistributable.

## CI example

Keep fast renderer tests separate from runtime bundle tests. A portable job can
build each artifact, run its behavior checks, and then retain the files:

```yaml
jobs:
  portable:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v7
      - uses: cachix/install-nix-action@v31
      - run: nix run .#test-portable-parity
      - run: nix build .#message-arx --out-link result-arx
      - run: nix build .#message-appimage --out-link result-appimage
      - run: |
          printf '{"message":"ci smoke"}\n' > input.json
          test "$(./result-arx input.json)" = "ci smoke"
          test "$(APPIMAGE_EXTRACT_AND_RUN=1 ./result-appimage input.json)" = "ci smoke"
```

For release confidence, pass the realized files to a second runner that has not
installed Nix, assert that `/nix` is absent, and repeat the smoke tests there.

## Troubleshooting

### `Missing required commands`

The host script found commands absent from `PATH`. Install every listed command
or run the ordinary Nix package instead.

### `Missing required host commands`

An Arx or AppImage artifact could not resolve one or more declared
`hostCommands`. Install native host executables on `PATH`, or add their Nix
packages to `runtimeInputs`. A command reached through a host Nix profile must
be bundled because the artifact's `/nix` hides the host store.

### `unresolved Nix store references remain`

The generated script still references store data or another path that cannot be
mapped safely to a host command. Use an executable under a dependency's `bin`
directory, redesign that dependency boundary, or keep the Nix-backed output.

### `Cannot mount AppImage`

Install FUSE and `fusermount3`, set `APPIMAGE_EXTRACT_AND_RUN=1`, or use
`appimage-run` on NixOS.

### User namespaces are disabled

Arx and AppImage both enter a user-namespace-backed environment. Enable
unprivileged user namespaces on the host or use `toHostScript` instead.

### `Exec format error`

The artifact was built for a different CPU architecture. Build it from the
matching Nix system and publish architecture-specific filenames.

## Current boundaries

- `toHostScript` requires Bash 4 or newer and GNU-compatible `getopt`.
- The host script does not include the ordinary package's completion command,
  spec, or shell adapters.
- Declare known host-provided bare commands with `hostCommands`; dynamically
  selected commands may use the caller's `PATH` without a declaration.
- Host commands backed by the host's `/nix/store` are not accessible from Arx
  or AppImage and must be bundled through `runtimeInputs`.
- Arx and AppImage require Linux user namespaces.
- Normal AppImage mounting requires FUSE; extraction and `appimage-run` are
  alternatives.
- Arx remains experimental because concurrent first execution can race.
- Portable artifacts still need testing on every architecture and target
  environment you publish.
