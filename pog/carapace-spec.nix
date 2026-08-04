{ lib
, bash
, buildGoModule
, fetchFromGitHub
, makeWrapper
}:
buildGoModule rec {
  pname = "carapace-spec";
  version = "1.8.0";

  src = fetchFromGitHub {
    owner = "carapace-sh";
    repo = "carapace-spec";
    rev = "v${version}";
    hash = "sha256-a1Urgp1Fbd8FeWyT9SxNkK0vQY1HAEBp0YV6mpyAEzw=";
  };

  patches = [ ./carapace-spec-pog.patch ];

  vendorHash = "sha256-kHCppNzUL6uO9RNzh1XjLLvWPP4SKGs+2rn+0sdVxmk=";
  modRoot = "cmd";
  subPackages = [ "carapace-spec" ];

  env.GOWORK = "off";

  postConfigure = ''
    chmod u+w vendor/github.com/carapace-sh/carapace-spec/core.go
    cp ../core.go vendor/github.com/carapace-sh/carapace-spec/core.go
  '';

  ldflags = [
    "-s"
    "-w"
    "-X main.version=${version}"
  ];

  nativeBuildInputs = [ makeWrapper ];

  postInstall = ''
    # Adapter generation embeds the executable basename. Keep the wrapped
    # binary named carapace-spec instead of exposing makeWrapper's hidden name.
    mkdir -p "$out/libexec/carapace-spec"
    mv "$out/bin/carapace-spec" "$out/libexec/carapace-spec/carapace-spec"
    makeWrapper "$out/libexec/carapace-spec/carapace-spec" "$out/bin/carapace-spec" \
      --prefix PATH : ${lib.makeBinPath [ bash ]}
  '';

  meta = {
    description = "Define simple command argument completion using YAML";
    homepage = "https://carapace.sh/";
    license = lib.licenses.mit;
    mainProgram = "carapace-spec";
    platforms = lib.platforms.unix;
  };
}
