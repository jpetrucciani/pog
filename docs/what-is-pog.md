# What is pog?

Pog is a [Nix](https://nixos.org/) library for declaring complete command-line
tools around readable Bash. A definition describes flags, positional arguments,
commands, dependencies, completion, and runtime behavior. Pog renders and
checks the program, generates its help, and packages its completion artifacts.

## What does it enable?

Pog is aimed at tools where Bash remains the clearest implementation language
but hand-written parser, help, dependency, and completion boilerplate would not.
The generated program still looks and behaves like a normal CLI.

Some key capabilities that pog enables include:

- Self-documenting tools with generated usage, argument, flag, and command help
- Recursive commands with aliases, groups, defaults, and cleanup hooks
- Strict, non-interspersed, pass-through, or disabled argument parsing
- Short, long, optional, repeatable, persistent, hidden, and exclusive flags
- Integration of interactive prompts and color-coded output
- One shell-neutral completion definition for Bash, Fish, Zsh, Nushell,
  PowerShell, and other generated adapters
- Required flags, and the option to provide interactive prompts for them
- Environment variable override support
- Strict mode operation for enhanced reliability
- Runtime dependencies from Nixpkgs and optional host-provided commands
- Ordinary Nix packages plus host-script, Arx, and AppImage outputs

## Why use pog?

The primary benefit of using pog lies in its ability to combine the reproducibility of Nix with the practical needs of CLI tool development. Here's why pog stands out:

1. **Reproducibility**: Being built on Nix, pog inherits all the benefits of Nix's reproducible builds. Every CLI tool created with pog is guaranteed to have the same behavior across different environments, as all dependencies are explicitly declared and managed through Nix.

2. **Declarative Development**: Rather than imperatively writing bash scripts and manually handling argument parsing, help text, and other boilerplate, pog allows developers to declare what they want their CLI tool to do in a clean, maintainable format.

3. **Rich Feature Set**: Pog provides a comprehensive set of features that would typically require multiple libraries or significant development time to implement, including:

   - Advanced flag parsing and pass-through wrappers
   - Interactive prompts and spinners
   - Color-coded output and styling
   - Structured and dynamic multi-shell completion
   - Verbose mode and debugging support

4. **Integration with [Nixpkgs](https://github.com/NixOS/nixpkgs)**: Pog seamlessly integrates with the vast ecosystem of [Nixpkgs](https://github.com/NixOS/nixpkgs), making it easy to include runtime dependencies and leverage existing tools in your CLI applications.

5. **Reduced Boilerplate**: Common CLI patterns like help text generation, flag parsing, and environment variable handling are automated, reducing the amount of code developers need to write and maintain.

## Why is it called pog?

The name "pog" draws inspiration from the internet slang term "POG" or "PogChamp," which expresses excitement or amazement at something extraordinary. Just as the term represents something impressive or exciting, pog aims to provide an impressive and exciting way to create CLI tools. The name reflects the library's goal of making CLI development not just functional, but genuinely enjoyable and remarkable.

The choice of name also aligns with the library's philosophy of being both powerful and playful – it's a serious tool that doesn't take itself too seriously. Like the cultural phenomenon it references, pog aims to make developers' lives better while maintaining a touch of fun in the often complex world of CLI tool development.
