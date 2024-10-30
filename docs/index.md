---
layout: home

hero:
  name: 'pog'
  text: 'Nix-Powered CLI tools'
  tagline: Create feature-rich CLI tools with Nix and bash - complete with flags, documentation, and more
  actions:
    - theme: brand
      text: Get Started
      link: /getting-started
    - theme: alt
      text: View on GitHub
      link: https://github.com/jpetrucciani/pog

features:
  - icon: 🚀
    title: Pure Nix Power
    details: Create comprehensive CLI tools using pure Nix, leveraging the vast nixpkgs ecosystem
  - icon: 📖
    title: Auto-Documentation
    details: Automatic help text generation, documentation, and tab completion out of the box
  - icon: 🎯
    title: Rich Flag System
    details: Comprehensive flag system with short/long options, env vars, defaults, and interactive prompts
  - icon: 🎨
    title: Terminal Enhancement
    details: Rich terminal colors, styling, and interactive features like spinners and prompts
  - icon: 🛠
    title: Developer Friendly
    details: Helper functions, runtime input management, verbose mode, and automatic shellcheck
  - icon: ⚡
    title: Quick Integration
    details: Easy to integrate with existing Nix projects through overlays or direct imports
---

### Quick Example

```nix
pog {
  name = "deploy";                                     # derivation/script name
  description = "Deploy application to cloud";         # used in the help doc
  flags = [
    pog._.flags.aws.region                             # a flag with bash completion, included in pog
    {
      name = "environment";
      short = "e";                                     # defaults to the first character of the name
      description = "deployment environment";          # used in the help doc
      required = true;                                 # forces the user to specify, or prompts for it
      completion = ''echo "dev staging prod"'';        # used for tab completion
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
