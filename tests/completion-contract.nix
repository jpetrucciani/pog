[
  {
    name = "recursive";
    fixture = "completion";
    command = "pog-completion-fixture";
    cases = [
      {
        name = "root commands";
        words = [ "" ];
        expected = [ "admin" "project" "status" ];
      }
      {
        name = "root command prefix";
        words = [ "pr" ];
        expected = [ "project" ];
      }
      {
        name = "root long flag prefix";
        words = [ "--d" ];
        expected = [ "--dry-run" ];
      }
      {
        name = "root long-only flag";
        words = [ "--long" ];
        expected = [ "--long-only" ];
      }
      {
        name = "root short flag value attaches";
        words = [ "-c" ];
        expected = [ "-cdev" "-cprod" ];
      }
      {
        name = "root long flag value";
        words = [ "--config" "d" ];
        expected = [ "dev" ];
      }
      {
        name = "root short flag value";
        words = [ "-c" "p" ];
        expected = [ "prod" ];
      }
      {
        name = "root flag before command";
        words = [ "--config" "dev" "" ];
        expected = [ "admin" "project" "status" ];
      }
      {
        name = "child commands";
        words = [ "project" "" ];
        expected = [ "list" "open" ];
      }
      {
        name = "child command prefix";
        words = [ "project" "l" ];
        expected = [ "list" ];
      }
      {
        name = "parent flag prefix";
        words = [ "project" "--s" ];
        expected = [ "--scope" ];
      }
      {
        name = "parent flag value";
        words = [ "project" "--scope" "p" ];
        expected = [ "private" "public" ];
      }
      {
        name = "parent flag before child";
        words = [ "project" "--scope" "private" "" ];
        expected = [ "list" "open" ];
      }
      {
        name = "leaf long flag prefix";
        words = [ "project" "open" "--p" ];
        expected = [ "--profile" ];
      }
      {
        name = "leaf long-only flag";
        words = [ "project" "open" "--output" ];
        expected = [ "--output-format" ];
      }
      {
        name = "leaf short flag value attaches";
        words = [ "project" "open" "-p" ];
        expected = [ "-pdev" "-pprod" ];
      }
      {
        name = "leaf long flag value";
        words = [ "project" "open" "--profile" "d" ];
        expected = [ "dev" ];
      }
      {
        name = "leaf short flag value";
        words = [ "project" "open" "-p" "p" ];
        expected = [ "prod" ];
      }
      {
        name = "leaf long-only flag value";
        words = [ "project" "open" "--output-format" "y" ];
        expected = [ "yaml" ];
      }
      {
        name = "leaf positional value";
        words = [ "project" "open" "a" ];
        expected = [ "alpha" ];
      }
      {
        name = "leaf positional after flag value";
        words = [ "project" "open" "--profile" "dev" "b" ];
        expected = [ "beta" ];
      }
      {
        name = "leaf positional after boolean flag";
        words = [ "project" "open" "--force" "a" ];
        expected = [ "alpha" ];
      }
      {
        name = "deep child command";
        words = [ "admin" "" ];
        expected = [ "cache" ];
      }
      {
        name = "third-level child command";
        words = [ "admin" "cache" "" ];
        expected = [ "clear" ];
      }
      {
        name = "deep built-in flag";
        words = [ "admin" "cache" "clear" "--no" ];
        expected = [ "--no-color" ];
      }
      {
        name = "root built-in flag";
        words = [ "--he" ];
        expected = [ "--help" ];
      }
      {
        name = "flags are node-local";
        words = [ "project" "--config" ];
        expected = [ ];
      }
      {
        name = "unknown command prefix";
        words = [ "missing" ];
        expected = [ ];
      }
    ];
  }
  {
    name = "flat";
    fixture = "flatCompletion";
    command = "pog-flat-completion-fixture";
    cases = [
      {
        name = "first positional values";
        words = [ "" ];
        expected = [ "alpha" "beta" ];
      }
      {
        name = "positional prefix";
        words = [ "b" ];
        expected = [ "beta" ];
      }
      {
        name = "long flag prefix";
        words = [ "--f" ];
        expected = [ "--format" ];
      }
      {
        name = "long-only flag";
        words = [ "--long" ];
        expected = [ "--long-only" ];
      }
      {
        name = "short flag value attaches";
        words = [ "-f" ];
        expected = [ "-fjson" "-fyaml" ];
      }
      {
        name = "long flag value";
        words = [ "--format" "j" ];
        expected = [ "json" ];
      }
      {
        name = "short flag value";
        words = [ "-f" "y" ];
        expected = [ "yaml" ];
      }
      {
        name = "short boolean before positional";
        words = [ "-q" "a" ];
        expected = [ "alpha" ];
      }
      {
        name = "long boolean before positional";
        words = [ "--quiet" "b" ];
        expected = [ "beta" ];
      }
      {
        name = "flag after positional";
        words = [ "alpha" "--q" ];
        expected = [ "--quiet" ];
      }
      {
        name = "built-in long flag";
        words = [ "--he" ];
        expected = [ "--help" ];
      }
      {
        name = "short boolean flag clustering";
        words = [ "-h" ];
        expected = [ "-hf" "-hq" "-hv" ];
      }
      {
        name = "unknown positional prefix";
        words = [ "missing" ];
        expected = [ ];
      }
    ];
  }
  {
    name = "no-short-defaults";
    fixture = "noShortDefaultCompletion";
    command = "pog-no-short-default-completion-fixture";
    cases = [
      {
        name = "long default flags remain";
        words = [ "--" ];
        expected = [ "--feature" "--help" "--no-color" "--verbose" ];
      }
      {
        name = "short default help is absent";
        words = [ "-" ];
        expected = [ "--feature" "--help" "--no-color" "--verbose" "-f" ];
      }
      {
        name = "completed declared short flag";
        words = [ "-f" ];
        expected = [ ];
      }
    ];
  }
  {
    name = "structured";
    fixture = "structuredCompletion";
    command = "pog-structured-completion-fixture";
    cases = [
      {
        name = "rich static flag value";
        words = [ "--environment" "d" ];
        expected = [ "dev" ];
      }
      {
        name = "dynamic flag sees parsed flag context";
        words = [ "--account" "team-a" "--region" "us-" ];
        expected = [ "us-east-1" "us-west-2" ];
      }
      {
        name = "first argument has local completion";
        words = [ "" ];
        expected = [ "job" "service" ];
      }
      {
        name = "second argument sees first argument";
        words = [ "service" "" ];
        expected = [ "api" "web" ];
      }
      {
        name = "second argument prefix";
        words = [ "job" "m" ];
        expected = [ "migrate" ];
      }
      {
        name = "filtered file extensions";
        words = [ "--config" "structured" ];
        expected = [ "structured-dir/" "structured.nix" "structured.yaml" ];
      }
      {
        name = "directory helper";
        words = [ "--directory" "structured" ];
        expected = [ "structured-dir/" ];
      }
      {
        name = "unique comma-separated values";
        words = [ "service" "api" "blue,r" ];
        expected = [ "blue,red" ];
      }
      {
        name = "merged completion sources";
        words = [ "--merged" "b" ];
        expected = [ "beta" ];
      }
      {
        name = "list completion";
        words = [ "--list" "blue,r" ];
        expected = [ "blue,red" ];
      }
      {
        name = "multipart completion";
        words = [ "--multipart" "key=a" ];
        expected = [ "key=alpha" ];
        # Bash exposes only the fragment after a COMP_WORDBREAKS character.
        # Readline preserves `key=` when it inserts this reply.
        bashExpected = [ "alpha" ];
      }
      {
        name = "prefixed values";
        words = [ "--prefixed" "feature/a" ];
        expected = [ "feature/alpha" ];
      }
      {
        name = "suffixed values";
        words = [ "--suffixed" "a" ];
        expected = [ "alpha.json" ];
      }
      {
        name = "executables from explicit directories";
        words = [ "--executable" "pog-structured" ];
        expected = [ "pog-structured-helper" ];
      }
      {
        name = "files relative to an explicit root";
        words = [ "--relative" "r" ];
        expected = [ "relative.txt" ];
      }
      {
        name = "delegated spec";
        words = [ "--delegated" "delegated-o" ];
        expected = [ "delegated-one" ];
      }
      {
        name = "raw Carapace action";
        words = [ "--raw-directory" "structured" ];
        expected = [ "structured-dir/" ];
      }
      {
        name = "no-space values";
        words = [ "--no-space" "path" ];
        expected = [ "path/" ];
      }
      {
        name = "filter used arguments";
        words = [ "service" "--used" "" ];
        expected = [ "job" ];
      }
      {
        name = "usage-wrapped values";
        words = [ "--usage" "a" ];
        expected = [ "api" ];
      }
    ];
  }
  {
    name = "passthrough";
    fixture = "passthrough";
    command = "pog-passthrough-fixture";
    cases = [
      {
        name = "known flag after unknown option";
        words = [ "--foreign" "value" "--profile" "d" ];
        expected = [ "dev" ];
      }
      {
        name = "known flag name after unknown option";
        words = [ "--foreign" "value" "--pro" ];
        expected = [ "--profile" ];
      }
    ];
  }
]
