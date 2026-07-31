# Portable bundler sources

`default.nix` pins the implementation sources instead of evaluating moving
branches or accepting the sources' own nixpkgs pins.

## `nix-community/nix-bundle`

- Purpose: build the `toArx` self-extracting closure.
- License: MIT.
- Pin: `eff01593f62794d458ec714090091419194ab64d`.
- Local policy: import it with the caller's `pkgs`. Its upstream flake lock is
  intentionally not used.
- Local patch: `nix-user-chroot.patch` maps host root directories and restores
  the caller's working directory after entering the chroot. The adapter passes
  the caller's `PATH` through the launcher's supported environment option.
  Rebase and compile this patch whenever the source pin changes.

Upstream describes this project as unstable. Its launcher also requires Linux
user namespaces. The generated Arx launcher expects host `sh`, `sed`, `tr`,
`date`, `head`, `tar`, `hexdump`, and `bzip2`; these tools are not part of the
embedded application closure. Its shared extraction cache is
`$HOME/.cache/tmpx-<hash>`. The upstream cache population is not atomic, so
simultaneous first executions may race; `toArx` remains experimental until that
is fixed. Keep it isolated behind the adapter rather than making it part of the
ordinary `pog` derivation.

## `ralismark/nix-appimage`

- Purpose: build the `toAppImage` closure.
- License: MIT.
- Pin: `7946addbc0d97e358a6d7aefe5e82310f0fe6b18`.
- Local policy: construct `mkAppImage`, its runtime, and its AppRun with the
  caller's `pkgs.pkgsStatic`.

The selected AppRun preserves the caller's working directory and maps the host
filesystem before mounting the bundled closure at `/nix`. It still requires
Linux user namespaces. Normal AppImage mounting also needs FUSE and
`fusermount3`; `APPIMAGE_EXTRACT_AND_RUN=1` avoids the FUSE dependency by
extracting the image for that execution. On NixOS, `appimage-run` is also a
working launch path when normal FUSE mounting is unavailable. The generated
`.app` companion uses `appimage-run` automatically; the raw AppImage does not.

Both adapters wrap programs with declared `hostCommands` in a checked
entrypoint. Host executables outside `/nix/store` can be resolved through the
preserved `PATH`. The host's Nix store is intentionally not merged with the
embedded store; Nix-managed command dependencies must be included in
`runtimeInputs`.

## Updating

1. Review upstream commits, open regressions, maintenance activity, and license.
2. Replace the exact revision in `default.nix`.
3. Download and unpack the GitHub archive outside the Nix store.
4. Calculate its unpacked hash with `nix hash path --type sha256 --sri`.
5. Rebase `nix-user-chroot.patch` when updating `nix-bundle`, then compile the
   patched `main.cpp`.
6. Build and run the ordinary, host-script, Arx, and AppImage test artifacts.
7. Run both closure bundles from a relative working directory on a Linux host
   without Nix installed.
