# Commands and parsing

Pog turns one Nix definition into a checked Bash CLI with generated help,
flags, positional metadata, recursive commands, and shell completion. Existing
definitions retain strict flag parsing by default. Wrappers that sit in front
of another command can explicitly consume only Pog's recognized flags.

## Parsing modes

Leave `parsing` unset for the compatible default: parent commands use
non-interspersed parsing and leaf commands use interspersed parsing. New code
can select a mode through `pog.parsing`:

| Mode | Recognized flags | Unknown flags | Stops at first positional |
| --- | --- | --- | --- |
| `pog.parsing.interspersed` | Consumed anywhere before `--` | Error | No |
| `pog.parsing.nonInterspersed` | Consumed before the first positional | Error before the first positional | Yes |
| `pog.parsing.passthrough` | Consumed anywhere before `--` | Preserved in `$@` | No |
| `pog.parsing.disabled` | Never consumed | Preserved in `$@` | Not applicable |

The legacy strings `"interspersed"`, `"non-interspersed"`, `"passthrough"`,
and `"disabled"` remain accepted.

### Wrapping another CLI

`passthrough` is useful when Pog owns a small set of wrapper flags and the
underlying command owns everything else:

```nix
kubectl-for = pog {
  name = "kubectl-for";
  description = "run kubectl with a selected kubeconfig";
  parsing = pog.parsing.passthrough;
  runtimeInputs = [ pkgs.kubectl ];
  flags = [
    {
      name = "profile";
      short = "p";
      description = "kubeconfig profile";
      default = "default";
      completion = [ "default" "development" "production" ];
    }
  ];
  arguments = [{ name = "KUBECTL_ARG"; variadic = true; }];
  script = ''
    export KUBECONFIG="$HOME/.kube/$profile"
    exec kubectl "$@"
  '';
};
```

This invocation consumes `--profile development` and forwards the other six
arguments in their original order:

```console
kubectl-for get pods --profile development --namespace api -o wide
```

Use `--` when the underlying command must receive an option whose name is also
declared by Pog:

```console
kubectl-for --profile development -- get pods --profile server-side-value
```

Pog consumes the separator itself and forwards everything after it. A missing
value for a recognized Pog flag remains an error. Pass-through parsing is
restricted to leaf commands because forwarding unknown tokens while also
choosing a Pog subcommand would be ambiguous.

`disabled` is more literal: it forwards every argument, including `--help`,
`--verbose`, and declared flag names. Flag variables may still receive their
configured default or environment value.

## Advanced flags

Flags can be optional, repeatable, hidden, persistent, or members of an
exclusive group:

```nix
persistentFlags = [
  {
    name = "profile";
    short = "p";
    default = "default";
    completion = [ "dev" "prod" ];
  }
];

commands = [
  {
    name = "deploy";
    aliases = [ "ship" ];
    group = "operations";
    exclusiveFlags = [ [ "json" "yaml" ] ];
    flags = [
      { name = "json"; bool = true; }
      { name = "yaml"; bool = true; }
      { name = "tag"; repeatable = true; }
      { name = "color"; optionalValue = true; default = "auto"; }
      { name = "secret"; bool = true; hidden = true; }
      { name = "verbose-count"; short = "V"; bool = true; repeatable = true; }
    ];
    arguments = [ "TARGET" ];
    script = ''printf '%s\n' "$@"'';
  }
];
```

- A repeatable value flag becomes a Bash array.
- A repeatable boolean becomes a count.
- An optional value accepts `--color` or `--color=blue`.
- Persistent flags are accepted by the declaring command and descendants.
- Hidden commands and flags remain invocable but are omitted from help and
  normal completion.
- Using two members of an exclusive group exits with status 2.

## Positional arguments

Strings remain the compact, compatible representation:

```nix
arguments = [ "INPUT" "OUTPUT" ];
```

Named arguments add documentation and local completion. Only the final
argument may be variadic:

```nix
arguments = [
  {
    name = "KIND";
    description = "resource kind";
    completion = [ "job" "service" ];
  }
  {
    name = "LABEL";
    description = "labels to apply";
    variadic = true;
    completion = pog.completions.uniqueList {
      separator = ",";
      completion = [ "blue" "green" "red" ];
    };
  }
];
```

Argument names describe help and completion. The values themselves remain in
the generated script's positional `$@` array.

See the [full specification](/specs) for every field and the [completion
guide](/completions) for completion constructors and generated artifacts.
