---
layout: home

hero:
  name: 'pog 🤯'
  text: 'Nix-Powered CLI tools'
  tagline: Declare complete Bash CLIs in Nix, with rich parsing, portable outputs, and native completion across shells
  actions:
    - theme: brand
      text: Get Started
      link: /getting-started
    - theme: alt
      text: Shell Completions
      link: /completions
    - theme: alt
      text: Portable Outputs
      link: /portable-outputs
    - theme: alt
      text: View on GitHub
      link: https://github.com/jpetrucciani/pog

features:
  - icon: 🚀
    title: Pure Nix Power
    details: Create comprehensive CLI tools using pure Nix, leveraging the vast nixpkgs ecosystem
  - icon: 📖
    title: Automatic Documentation
    details: Generated help, positional documentation, recursive command groups, aliases, and usage text
  - icon: 🎯
    title: Rich Flag System
    details: Strict or pass-through parsing with defaults, prompts, repeatable values, and persistent or exclusive flags
  - icon: 🔄
    title: Native Shell Completion
    details: One Carapace spec generates Bash, Fish, Zsh, Nushell, PowerShell, and six other adapters
    link: /completion-providers
    linkText: Build programmable providers
  - icon: 🎨
    title: Terminal Enhancement
    details: Rich terminal colors, styling, and interactive features like spinners and prompts
  - icon: 🛠
    title: Developer Friendly
    details: Helper functions, runtime input management, verbose mode, and automatic shellcheck
  - icon: ⚡
    title: Quick Integration
    details: Easy to integrate with existing Nix projects through overlays or direct imports
  - icon: 📦
    title: Portable Distribution
    details: Turn one pog definition into a host script, an Arx bundle, or an AppImage
    link: /portable-outputs
    linkText: Explore portable outputs
---

### Define once, choose how to ship

A normal `pog` package can also produce three opt-in, single-file outputs:

| Output | Dependency model | Good fit |
| --- | --- | --- |
| `toHostScript` | Uses commands already installed on the host | Bootstrap scripts and managed fleets |
| `toArx` | Carries the Nix closure inside an experimental Linux bundle | Internal tools that need exact Nix dependencies |
| `toAppImage` | Carries the Nix closure inside an AppImage | Distributing a Linux CLI as one familiar artifact |

The normal Nix package stays unchanged until one of these outputs is requested.
Each format uses the same flags, commands, help, runtime inputs, and script
definition.

[See the portable outputs guide →](/portable-outputs)

### Quick Example

```nix
pog {
  name = "deploy";                                     # derivation/script name
  description = "Deploy application to cloud";         # used in the help doc
  flags = [
    pog._.flags.aws.region                             # a flag with shell completion, included in pog
    {
      name = "environment";
      short = "e";                                     # defaults to the first character of the name
      description = "deployment environment";          # used in the help doc
      required = true;                                 # forces the user to specify, or prompts for it
      completion = [ "dev" "staging" "prod" ];       # shell-neutral tab completion
    }
  ];
  script = helpers: ''
    green "Deploying to $environment in $region..."
    ${helpers.spinner {
      command = "kubectl apply -f ./manifests/";
      title = "Deploying...";
    }}
  '';
}
```
