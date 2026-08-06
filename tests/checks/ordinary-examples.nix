{ pkgs, examples }:
pkgs.runCommand "pog-ordinary-examples-check"
{
  nativeBuildInputs = [ pkgs.jq ];
}
  ''
    mkdir -p "$TMPDIR/bin" "$TMPDIR/work/source/nested"
    printf '#!/bin/sh\nprintf "%%s\\n" example\n' > "$TMPDIR/bin/example-tool"
    chmod +x "$TMPDIR/bin/example-tool"

    PATH="$TMPDIR/bin:$PATH" \
      ${examples.batwhich}/bin/batwhich example-tool > "$TMPDIR/batwhich.out"
    grep -F 'printf "%s\n" example' "$TMPDIR/batwhich.out"

    set +e
    ${examples.batwhich}/bin/batwhich absent-example-command \
      > "$TMPDIR/missing.stdout" \
      2> "$TMPDIR/missing.stderr"
    status=$?
    set -e
    test "$status" -eq 127
    grep -Fx 'command not found: absent-example-command' "$TMPDIR/missing.stderr"

    token='eyJhbGciOiJub25lIiwidHlwIjoiSldUIn0.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.'
    output="$(${examples.jwtDecode}/bin/jwt-decode --compact "$token")"
    test "$output" = '{"sub":"1234567890","name":"John Doe","iat":1516239022}'

    printf '# Alpha\nalpha = true;\n' > "$TMPDIR/work/source/a.nix"
    printf '# Shell helper\nprintf example\n' > "$TMPDIR/work/source/nested/b script.sh"
    printf '# Ignored\n' > "$TMPDIR/work/source/ignored.md"
    output="$(${examples.nixSummary}/bin/nix-summary \
      --directory "$TMPDIR/work/source" \
      --depth 2 \
      --extension nix \
      --extension sh)"
    test "$output" = "$(printf '%s\n' \
      '### [a.nix]('"$TMPDIR"'/work/source/a.nix)' \
      "" \
      'Alpha' \
      "" \
      '### [nested/b script.sh]('"$TMPDIR"'/work/source/nested/b script.sh)' \
      "" \
      'Shell helper')"

    export HOME="$TMPDIR/home"
    export XDG_CACHE_HOME="$TMPDIR/cache"
    mkdir -p "$HOME" "$XDG_CACHE_HOME"

    PATH="$TMPDIR/bin:$PATH" \
      ${examples.batwhich.pog.completionCommand} \
      export batwhich example- > "$TMPDIR/batwhich-completion.json"
    jq -e '.values | any(.value == "example-tool")' \
      "$TMPDIR/batwhich-completion.json" > /dev/null

    ${examples.jwtDecode.pog.completionCommand} \
      export jwt-decode "" > "$TMPDIR/jwt-completion.json"
    jq -e '.messages | any(. == "paste a JSON Web Token")' \
      "$TMPDIR/jwt-completion.json" > /dev/null

    (
      cd "$TMPDIR/work"
      ${examples.nixSummary.pog.completionCommand} \
        export nix-summary --directory sou
    ) > "$TMPDIR/summary-directory.json"
    jq -e '.values | any(.value == "source/")' \
      "$TMPDIR/summary-directory.json" > /dev/null

    ${examples.nixSummary.pog.completionCommand} \
      export nix-summary --extension n > "$TMPDIR/summary-extension.json"
    jq -e '.values | any(.value == "nix")' \
      "$TMPDIR/summary-extension.json" > /dev/null

    touch "$out"
  ''
