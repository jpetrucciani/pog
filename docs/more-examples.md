# More examples

The repository includes three deterministic, runnable tools adapted from the
larger collection in
[`jpetrucciani/nix`](https://github.com/jpetrucciani/nix/tree/main/mods/pog):

- `batwhich`, executable completion, runtime inputs, and normal error handling.
- `jwt-decode`, a boolean flag, completion message, and JSON transformation.
- `nix-summary`, repeatable flags, rich static values, directory completion,
  and filenames containing spaces.

Build or run them from a Pog checkout:

```console
nix build .#example-batwhich
nix run .#example-jwt-decode -- --help
nix run .#example-nix-summary -- \
  --directory examples \
  --extension nix \
  --extension md
```

Inspect the generated completion interface:

```console
nix build .#example-nix-summary
result/bin/_nix-summary_complete export nix-summary --extension n
find -L result/share/pog/completions -type f -print | sort
```

The source definitions live in the repository's `examples` directory and run
as regression fixtures through `nix build .#ordinary-examples`. The external
collection remains useful for larger wrappers involving cloud APIs, media
tools, containers, databases, and local services.

## Subcommands

Pass a `commands` list to build a clap-style tool that dispatches to nested subcommands.
Each command can have its own flags, arguments, help, and script, and can nest further
`commands` to any depth. A parent command may also define a `script` that runs as the
default action when no subcommand is given.

```nix
tool = pog {
  name = "tool";
  description = "a tester for pog's recursive subcommands";
  flags = [ _.flags.common.color ];
  # top-level exit hook (runs last, after any command's hook)
  beforeExit = ''echo "[tool] root cleanup"'';
  # default action when invoked with no subcommand
  script = ''echo -e "''${!color}tool root - no subcommand given''${RESET}"'';
  commands = [
    {
      name = "remote";
      description = "manage remotes";
      # parent default action (bare `tool remote`)
      script = ''echo "listing remotes (default action)"'';
      commands = [
        {
          name = "add";
          description = "add a remote";
          arguments = [ "remote_name" ];
          # per-command exit hook (runs first, before the root hook)
          beforeExit = ''echo "[tool remote add] cleanup"'';
          flags = [
            { name = "url"; description = "the remote url"; required = true; }
            _.flags.k8s.namespace
          ];
          script = ''echo "adding remote '$1' -> $url (ns=$namespace)"'';
        }
        {
          name = "remove";
          description = "remove a remote";
          script = ''echo "removing remote '$1'"'';
        }
        {
          # subcommand names may be hyphenated
          name = "list-all";
          description = "list every remote";
          script = ''echo "listing all remotes"'';
        }
      ];
    }
    {
      name = "status";
      description = "show status";
      flags = [ { name = "short"; description = "short output"; bool = true; } ];
      script = ''echo "status (short=''${short:-0})"'';
    }
  ];
};
```

This generates a single `tool` binary that supports:

```bash
tool                            # runs the root default action
tool --help                     # lists the `remote` and `status` subcommands
tool remote                     # runs the `remote` default action
tool remote add --url x myremote
tool remote list-all
tool status --short
```

Tab completion works recursively: completing after `tool` offers the subcommand names,
after `tool remote` offers `add remove list-all`, and after a leaf command offers that
command's flags and argument completions.

See [Commands and parsing](/command-line) for aliases, command groups,
persistent flags, exclusive flags, and pass-through wrappers.

Each command can also define a `beforeExit` hook. Every command on the active path runs
its hook as the process exits, deepest command first. So `tool remote add --url x foo`
prints:

```
adding remote 'foo' -> x (ns=default)
[tool remote add] cleanup
[tool] root cleanup
```
