# Shell completions

Every ordinary Pog package contains one shell-neutral Carapace specification,
one installed completion command, and adapters generated from that same source.

```text
Pog flags, arguments, and commands
                 |
                 v
       Carapace YAML specification
                 |
                 v
       bin/_<command>_complete
                 |
       +---------+---------+---------+
       |         |         |         |
      Bash      Fish      Zsh      other adapters
```

This keeps completion behavior aligned across shells while retaining the
existing Bash completion syntax used by older Pog definitions.

## Installed artifacts

For a command named `deploy`, the package contains:

```text
$out/bin/deploy
$out/bin/_deploy_complete
$out/share/carapace/specs/deploy.yaml
$out/share/bash-completion/completions/deploy
$out/share/fish/vendor_completions.d/deploy.fish
$out/share/zsh/site-functions/_deploy
$out/share/nushell/vendor/autoload/deploy.nu
$out/share/pog/completions/<shell>/...
```

`share/pog/completions` includes Bash, Bash with ble.sh, Clink, Elvish, Fish,
Nushell, Oil, PowerShell, tcsh, Xonsh, and Zsh adapters.

The installed completion command fixes the package's spec path and exposes the
Carapace protocols directly:

```console
_deploy_complete export deploy --environment d
_deploy_complete bash deploy --environment d
_deploy_complete fish deploy --environment d
```

`export` returns structured JSON containing values, descriptions, styles,
tags, usage text, and spacing behavior. Its Nix path is also available as
`package.pog.completionCommand`; the YAML path is
`package.pog.completionSpec`.

## Static completion

A list is the compact shell-neutral form:

```nix
{
  name = "environment";
  completion = [ "development" "staging" "production" ];
}
```

Use `values` to add display metadata:

```nix
{
  name = "environment";
  completion = pog.completions.values [
    {
      value = "dev";
      description = "local development";
      style = "green";
      tag = "local";
    }
    {
      value = "prod";
      description = "production";
      style = "red";
      tag = "remote";
    }
  ];
}
```

## Files, directories, and executables

```nix
flags = [
  {
    name = "config";
    completion = pog.completions.files {
      extensions = [ ".nix" ".yaml" ];
    };
  }
  {
    name = "directory";
    completion = pog.completions.directories { };
  }
  {
    name = "command";
    completion = pog.completions.executables { };
  }
];
```

`relativeTo` can anchor filesystem completion to the current directory, Git
directory or worktree, Nix profile, user directories, XDG directories, or an
explicit path. See the [completion reference](/specs#completions-pog-completions)
for the complete list.

## Dynamic providers and caching

Dynamic completion runs only when the user requests candidates:

```nix
{
  name = "region";
  completion = pog.completions.dynamic {
    runtimeInputs = [ pkgs.awscli2 pkgs.coreutils ];
    script = ''
      aws ec2 describe-regions \
        --query 'Regions[].RegionName' \
        --output text |
        tr '\t' '\n'
    '';
    cache = {
      ttlSeconds = 300;
      by = [ { flag = "profile"; } ];
    };
  };
}
```

Providers receive:

- `POG_COMPLETION_VALUE`, the fragment being completed.
- `POG_COMPLETION_INDEX`, the zero-based positional index.
- `POG_COMPLETION_DIR`, the completion working directory.
- `POG_COMPLETION_ARG_<N>` and `POG_COMPLETION_ARGS_JSON`.
- `POG_COMPLETION_FLAG_<NAME>` and `POG_COMPLETION_FLAGS_JSON`.

Cache keys can select the working directory, current value, a flag, an
argument, or an environment variable. A zero-second TTL disables caching.

## Composition

The remaining constructors compose completion sources without shell code:

- `merge`, combine several sources.
- `list` and `uniqueList`, complete separated lists.
- `multipart`, complete values containing separators such as `=` or `:`.
- `prefix`, `suffix`, and `noSpace`, control insertion behavior.
- `filterUsed`, remove positional values already present.
- `withUsage` and `message`, explain what is expected.
- `delegate`, invoke another Carapace spec.
- `rawCarapace`, use explicit Carapace actions when no higher-level helper fits.

## Legacy definitions

Existing strings remain Bash providers:

```nix
{
  name = "environment";
  completion = ''printf '%s\n' dev staging production'';
}
```

Pog runs the provider through the packaged completion engine and translates its
newline-separated candidates for the active shell. Flag providers keep the
legacy `$current` variable. `argumentCompletion` providers continue to receive
the current prefix as `$1`; the special legacy value `"files"` remains file
completion.

## Shell loading

Nix profiles and development shells normally load conventional completion
directories automatically. For direct build-result testing:

### Bash

```console
source result/share/bash-completion/completions/deploy
```

### Fish

```fish
source result/share/fish/vendor_completions.d/deploy.fish
```

### Zsh

```zsh
fpath=("$PWD/result/share/zsh/site-functions" $fpath)
autoload -Uz compinit
compinit
```

## Validation coverage

| Shell or interface | Current validation |
| --- | --- |
| Bash adapter | Shared 66-case semantic contract and syntax check |
| Fish adapter | Shared 66-case semantic contract |
| Bash Readline | Real interactive tab presses, cursor movement, files, directories, and quoting |
| Zsh ZLE | Real interactive tab presses, cursor movement, files, directories, and escaping |
| Installed completion command | Structured JSON, provider context, caching, and adapter integration |
| Clink | Generated adapter and Lua syntax check |
| Elvish, Nushell, Oil, PowerShell, tcsh, Xonsh | Generated non-empty adapter and package-path smoke test |

Pass-through commands enable Carapace's lenient flag handling so unknown flags
owned by an underlying command do not prevent Pog's known flags from completing.
