# Programmable completion providers

Pog completions can be static data, filesystem actions, or programs that run
only when completion is requested. A dynamic provider can inspect the current
command line, query a local tool or remote API, and cache its candidates across
shell sessions.

The provider is defined once in Nix. Pog includes it in the Carapace model, so
the same behavior reaches Bash, Fish, Zsh, Nushell, PowerShell, and the other
generated adapters.

## Choosing a completion source

Use the smallest source that can express the candidates:

| Requirement | Pog completion |
| --- | --- |
| Fixed names or enums | A list or `pog.completions.values` |
| Files or directories | `files` or `directories` |
| Commands on `PATH` | `executables` |
| Values from a command or API | `dynamic` |
| Static and generated candidates together | `merge` |
| Comma-separated or multipart values | `list`, `uniqueList`, or `multipart` |
| Another Carapace spec | `delegate` |
| An action Pog does not model yet | `rawCarapace` |

Static sources are fastest and easiest to distribute. Dynamic providers are
appropriate when the answer depends on live state, such as cloud regions,
repositories, clusters, deployment targets, or authenticated API resources.

## A minimal dynamic provider

`pog.completions.dynamic` accepts a Bash script and optional runtime inputs:

```nix
{
  name = "region";
  description = "cloud region";
  completion = pog.completions.dynamic {
    runtimeInputs = [ pkgs.awscli2 pkgs.coreutils ];
    script = ''
      aws ec2 describe-regions \
        --query 'Regions[].RegionName' \
        --output text 2>/dev/null |
        tr '\t' '\n'
    '';
  };
}
```

The script runs when the user asks for completion, not when the shell starts.
Write one candidate per output line. Diagnostics written to standard output
become candidates, so providers should keep normal output machine-readable and
handle expected failures quietly.

Provider `runtimeInputs` are added to the provider's `PATH`. Declare every
program used by the provider there; do not assume the main command's
`runtimeInputs` are available while completing.

### Rich generated candidates

A provider can add a description and style with tab-separated fields:

```nix
completion = pog.completions.dynamic {
  script = ''
    printf '%s\t%s\t%s\n' \
      dev 'local development' green \
      prod 'production environment' red
  '';
};
```

Descriptions are always available to supporting adapters. Style metadata is
included when Carapace coloring is enabled; set `CARAPACE_COLOR=1` when
inspecting styles through the structured `export` protocol.

Keep candidate values free of literal newlines. Use
`pog.completions.values` instead when the candidates are known during Nix
evaluation; the structured form also supports tags and avoids running a
provider process.

## Querying an API

This complete example retrieves project names for the selected account:

```nix
projectctl = pog {
  name = "projectctl";
  description = "operate on a remote project";

  flags = [
    {
      name = "account";
      short = "a";
      description = "API account";
      required = true;
      completion = [ "team-a" "team-b" ];
    }
    {
      name = "project";
      short = "p";
      description = "project slug";
      required = true;
      completion = pog.completions.dynamic {
        runtimeInputs = [ pkgs.curl pkgs.jq ];
        script = ''
          api_url="''${PROJECT_API_URL:-https://api.example.com}"
          token="''${PROJECT_API_TOKEN-}"
          account="''${POG_COMPLETION_FLAG_ACCOUNT-}"

          # Authentication and account context are required, but a missing
          # value should make completion empty rather than disrupt the prompt.
          [[ -n "$token" && -n "$account" ]] || exit 0

          response="$(
            curl --fail --silent \
              --connect-timeout 1 \
              --max-time 3 \
              --header "Authorization: Bearer $token" \
              --get \
              --data-urlencode "account=$account" \
              "$api_url/projects" 2>/dev/null
          )" || exit 0

          jq -r '.projects[]? | .slug // empty' \
            <<< "$response" 2>/dev/null || true
        '';
        cache = {
          ttlSeconds = 300;
          by = [
            { flag = "account"; }
            { env = "PROJECT_API_URL"; }
          ];
        };
      };
    }
  ];

  script = ''
    printf 'account=<%s> project=<%s>\n' "$account" "$project"
  '';
};
```

With `PROJECT_API_TOKEN` in the environment, completing this command queries
the API and returns only the projects for `team-a`:

```console
projectctl --account team-a --project <TAB>
```

Keep credentials in the user's environment or credential tooling. Never place
tokens directly in a Nix string: evaluated Nix expressions and store paths are
not secret storage.

## Provider context

Every dynamic provider receives the current completion state:

| Variable | Meaning |
| --- | --- |
| `POG_COMPLETION_VALUE` | The incomplete value under the cursor |
| `POG_COMPLETION_INDEX` | Zero-based positional argument index being completed |
| `POG_COMPLETION_DIR` | Completion working directory |
| `POG_COMPLETION_ARG_<N>` | One previously parsed positional argument |
| `POG_COMPLETION_ARGS_JSON` | Parsed positional arguments as JSON |
| `POG_COMPLETION_FLAG_<NAME>` | Value parsed for a named flag |
| `POG_COMPLETION_FLAGS_JSON` | Parsed flags as JSON |

Dashes and dots in flag names become underscores in individual environment
variables. For example, `--cloud.profile` is exposed as
`POG_COMPLETION_FLAG_CLOUD_PROFILE`.

The provider also inherits the user's ordinary environment. That is the right
place for API tokens, service endpoints, and credentials selected by tools such
as the AWS CLI.

### Completing from another flag

```nix
completion = pog.completions.dynamic {
  script = ''
    case "''${POG_COMPLETION_FLAG_ACCOUNT-}" in
      team-a) printf '%s\n' us-east-1 us-west-2 ;;
      team-b) printf '%s\n' eu-west-1 ;;
    esac
  '';
};
```

### Completing from positional arguments

```nix
arguments = [
  {
    name = "KIND";
    completion = [ "job" "service" ];
  }
  {
    name = "NAME";
    completion = pog.completions.dynamic {
      script = ''
        case "''${POG_COMPLETION_ARG_0-}" in
          job) printf '%s\n' cleanup migrate ;;
          service) printf '%s\n' api web ;;
        esac
      '';
    };
  }
];
```

### Using JSON context

Use the JSON variables when a provider needs all arguments or flags rather
than one known value:

```nix
completion = pog.completions.dynamic {
  runtimeInputs = [ pkgs.jq ];
  script = ''
    jq -r 'to_entries[] | "\(.key)=\(.value)"' \
      <<< "$POG_COMPLETION_FLAGS_JSON"
  '';
};
```

## Caching

Dynamic completion may execute once for every tab press. API calls, cloud CLIs,
and repository scans should normally use a short cache:

```nix
cache = {
  ttlSeconds = 300;
  by = [ { flag = "profile"; } ];
};
```

Carapace stores the completed action in its on-disk cache. Calls with the same
provider and cache-key values reuse the candidates until the TTL expires. The
provider configuration itself is part of the key, so changing its script or
cache configuration creates a different entry.

`ttlSeconds` must be a non-negative integer. Omitting `cache`, or using
`ttlSeconds = 0`, disables caching.

### Cache selectors

`cache.by` controls which pieces of completion context partition the cache:

| Selector | Cache varies by | Typical use |
| --- | --- | --- |
| `"cwd"` | Working directory | Repository-local resources |
| `"value"` | Text currently being completed | Server-side prefix search |
| `{ flag = "profile"; }` | A parsed flag | Account, cluster, or profile selection |
| `{ argument = 0; }` | A positional argument | Resources nested below a kind or owner |
| `{ env = "TENANT"; }` | An environment variable | Endpoint or tenant selection |

With an empty `by` list, every invocation of that provider shares one cache
entry for the TTL. That is correct for global data but wrong when different
accounts or repositories return different results.

Avoid adding `"value"` when the API can return the complete candidate set.
Fetching once and allowing Carapace to filter locally gives every typed prefix
the same cache entry. Use `"value"` only when the provider sends the prefix to
the server and different prefixes genuinely produce different result sets.

Do not use an authentication token itself as a cache selector. Prefer a
non-secret account, profile, or identity name. Remember that cached candidates
are written to disk; disable caching or shorten the TTL when candidate names are
sensitive.

### Cache-key examples

Per repository and profile:

```nix
cache = {
  ttlSeconds = 60;
  by = [ "cwd" { flag = "profile"; } ];
};
```

Per resource owner selected by the first positional argument:

```nix
cache = {
  ttlSeconds = 600;
  by = [ { argument = 0; } ];
};
```

Per API deployment and non-secret identity:

```nix
cache = {
  ttlSeconds = 300;
  by = [
    { env = "PROJECT_API_URL"; }
    { env = "PROJECT_API_IDENTITY"; }
  ];
};
```

## Composing providers

Dynamic providers can participate in the same composition operations as static
values and filesystem completion.

### Add local defaults to remote results

```nix
completion = pog.completions.merge [
  [ "default" "local" ]
  (pog.completions.dynamic {
    runtimeInputs = [ pkgs.gh ];
    script = ''
      gh repo list --limit 100 \
        --json nameWithOwner \
        --jq '.[].nameWithOwner' 2>/dev/null || true
    '';
    cache = { ttlSeconds = 120; };
  })
];
```

### Complete a unique comma-separated remote list

```nix
completion = pog.completions.uniqueList {
  separator = ",";
  completion = pog.completions.dynamic {
    runtimeInputs = [ pkgs.gh ];
    script = ''
      gh label list --limit 100 \
        --json name \
        --jq '.[].name' 2>/dev/null || true
    '';
    cache = {
      ttlSeconds = 120;
      by = [ "cwd" ];
    };
  };
};
```

### Attach usage or insertion behavior

`withUsage` can explain the expected value. `prefix`, `suffix`, and `noSpace`
can transform how candidates are inserted. See the [completion overview](/completions)
for every constructor.

## Latency and failure behavior

Completion sits directly in the typing loop, so providers should feel nearly
instantaneous even when their backing service is not.

- Cache remote and expensive results.
- Set short connection and total request timeouts.
- Prefer one broad request that Carapace can filter locally.
- Avoid interactive authentication, prompts, pagers, and colorized output.
- Return no candidates when optional credentials or context are missing.
- Keep diagnostics off standard output.
- Use read-only API operations. A tab press must never mutate remote state.
- Bound large result sets before printing them.

An uncached provider runs again whenever completion is requested. Caching
reduces that frequency but does not prefetch, refresh in the background, or
serve stale results after expiration.

## Legacy Bash providers

Existing completion strings remain supported:

```nix
{
  name = "environment";
  completion = ''printf '%s\n' dev staging production'';
}
```

Legacy flag providers receive `$current` and `$previous`; legacy positional
providers receive the current value as `$1`. They run through the same packaged
completion command for every generated shell.

Use `pog.completions.dynamic` for new providers. It adds explicit runtime
inputs, structured context, and caching without depending on legacy calling
conventions.

## Testing a provider directly

The installed `_<command>_complete` executable is the fastest way to inspect
completion without starting an interactive shell:

```console
nix build .#projectctl --out-link result-projectctl

PROJECT_API_TOKEN=example \
  result-projectctl/bin/_projectctl_complete \
  export projectctl --account team-a --project "" |
  jq .
```

Use a temporary cache root when testing cache misses repeatedly:

```console
completion_cache=$(mktemp -d)
PROJECT_API_TOKEN=example XDG_CACHE_HOME="$completion_cache" \
  result-projectctl/bin/_projectctl_complete \
  export projectctl --account team-a --project "" |
  jq .
```

The repository's structured completion check verifies provider context, rich
values, and separate cache entries for separate flag values:

```console
nix build -L --no-link \
  .#ordinary-structured-completion \
  .#ordinary-completion-fish \
  .#ordinary-completion-zsh
```

See [Shell completions](/completions#shell-loading) for manual Fish and Zsh
loading instructions.

## Current boundaries

- Providers execute with the invoking user's permissions and environment.
- API access still requires network connectivity when a cache entry is absent.
- Cache invalidation is TTL- and key-based; Pog does not receive remote change
  notifications.
- The enhanced dynamic-provider context is implemented by Pog's packaged
  completion engine. The generated YAML is not guaranteed to run unchanged
  through an unmodified external `carapace` binary.
- Completion commands, specs, and adapters belong to ordinary Nix package
  outputs. Portable host scripts, Arx bundles, and AppImages intentionally omit
  them.
