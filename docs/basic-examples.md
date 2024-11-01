# basic examples

## github tags fetcher

```nix
github_tags = pog.pog {
  name = "github_tags";
  description = "a nice wrapper for getting github tags for a repo!";
  flags = [
    {
      name = "latest";
      description = "fetch only the latest tag";
      bool = true;
    }
    pog._.flags.github.owner
    pog._.flags.github.repo
  ];
  script = helpers: ''
    tags="$(${pog._.curl} -Ls "https://api.github.com/repos/''${owner}/''${repo}/tags" |
      ${pkgs.lib.getExe pkgs.jaq} -r '.[].name')"
    if ${helpers.flag "latest"}; then
      echo "$tags" | ${pog._.head} -n 1
    else
      echo "$tags"
    fi
  '';
};
```

### generated docs

```bash
Usage: github_tags [-l|--latest] [-o|--owner VAR] [-r|--repo VAR]

a nice wrapper for getting github tags for a repo!

Flags:
-l, --latest          fetch only the latest tag [bool]
-o, --owner           the github user or organization that owns the repo [will prompt if not passed in]
-r, --repo            the github repo to pull tags from [will prompt if not passed in]
-h, --help            print this help and exit
-v, --verbose         enable verbose logging and info
--no-color            disable color and other formatting
```
