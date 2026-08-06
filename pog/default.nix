{ pkgs, ... }:
let
  inherit (builtins) filter genList isString listToAttrs replaceStrings stringLength substring;
  inherit (pkgs.lib) nameValuePair optionalAttrs stringToCharacters splitString;
  inherit (pkgs.lib.lists) concatLists reverseList;
  inherit (pkgs.lib.strings) concatStrings concatStringsSep fixedWidthString toUpper;
  reverse = x: concatStringsSep "" (reverseList (stringToCharacters x));
  rightPad = num: text: reverse (fixedWidthString num " " (reverse text));
  _ind = level: text:
    let
      spaces = concatStrings (genList (_: " ") (level * 2));
    in
    concatStringsSep "\n" (map (x: "${spaces}${x}") (filter isString (splitString "\n" text)));
  ind = _ind 1;

  bashbible = import ./bashbible.nix { inherit pkgs; };
  bundlers = import ./bundlers { inherit pkgs; };
  carapaceSpec = pkgs.callPackage ./carapace-spec.nix { };
  yamlFormat = pkgs.formats.yaml { };
  ignoreUnused = "# shellcheck disable=SC2329";
  mkParsingMode = name: { _pogParsingMode = name; };
  parsingModes = {
    interspersed = mkParsingMode "interspersed";
    nonInterspersed = mkParsingMode "non-interspersed";
    passthrough = mkParsingMode "passthrough";
    disabled = mkParsingMode "disabled";
  };
  parsingModeNames = [ "interspersed" "non-interspersed" "passthrough" "disabled" ];
  normalizeParsingMode = path: value:
    let
      mode =
        if isString value then
          value
        else if builtins.isAttrs value
          && value ? _pogParsingMode
          && isString value._pogParsingMode then
          value._pogParsingMode
        else
          null;
    in
    if value == null then
      null
    else if mode != null && builtins.elem mode parsingModeNames then
      mode
    else
      throw "pog: '${path}' parsing must be interspersed, non-interspersed, passthrough, or disabled";
  normalizeArgument = argument:
    if isString argument then
      {
        name = argument;
        description = "";
        variadic = false;
      }
    else if builtins.isAttrs argument
      && argument ? name
      && isString argument.name
      && isString (argument.description or "")
      && builtins.isBool (argument.variadic or false) then
      argument // {
        description = argument.description or "";
        variadic = argument.variadic or false;
      }
    else
      throw "pog: arguments must be strings or sets with a string `name`, string `description`, and boolean `variadic`";
  normalizeArguments = map normalizeArgument;
  encodeCompletion = completion:
    replaceStrings [ "$" ] [ "\\u0024" ] (builtins.toJSON completion);
  mkCompletion = kind: attributes: {
    _pogCompletion = kind;
  } // attributes;
  completions = rec {
    values = candidates: mkCompletion "values" { inherit candidates; };
    files =
      { extensions ? [ ]
      , relativeTo ? null
      }:
      mkCompletion "files" { inherit extensions relativeTo; };
    directories = { relativeTo ? null }:
      mkCompletion "directories" { inherit relativeTo; };
    executables =
      { directories ? [ ]
      , relativeTo ? null
      }:
      mkCompletion "executables" { inherit directories relativeTo; };
    dynamic =
      { script
      , runtimeInputs ? [ ]
      , cache ? null
      }:
      mkCompletion "dynamic" {
        inherit script runtimeInputs cache;
        legacy = "";
      };
    merge = sources: mkCompletion "merge" { inherit sources; };
    list = { separator, completion }:
      mkCompletion "modifier" {
        inherit completion;
        modifier = "list";
        argument = separator;
      };
    uniqueList = { separator, completion }:
      mkCompletion "modifier" {
        inherit completion;
        modifier = "uniquelist";
        argument = separator;
      };
    multipart = { separators, completion }:
      mkCompletion "modifier" {
        inherit completion;
        modifier = "multiparts";
        argument = builtins.toJSON separators;
      };
    prefix = { prefix, completion }:
      mkCompletion "modifier" {
        inherit completion;
        modifier = "prefix";
        argument = prefix;
      };
    suffix = { suffix, completion }:
      mkCompletion "modifier" {
        inherit completion;
        modifier = "suffix";
        argument = suffix;
      };
    noSpace = { characters, completion }:
      mkCompletion "modifier" {
        inherit completion;
        modifier = "nospace";
        argument = concatStringsSep "" characters;
      };
    filterUsed = completion:
      mkCompletion "modifier" {
        inherit completion;
        modifier = "filterargs";
        argument = null;
      };
    withUsage = { usage, completion }:
      mkCompletion "modifier" {
        inherit completion;
        modifier = "usage";
        argument = usage;
      };
    message = message: mkCompletion "message" { inherit message; };
    delegate = completionSpec: mkCompletion "delegate" { inherit completionSpec; };
    rawCarapace = actions: mkCompletion "raw" { inherit actions; };
  };
  normalizeCandidate = candidate:
    if isString candidate then
      {
        value = candidate;
        description = "";
        style = "";
        tag = "";
      }
    else if builtins.isAttrs candidate
      && candidate ? value
      && isString candidate.value
      && isString (candidate.description or "")
      && isString (candidate.style or "")
      && isString (candidate.tag or "") then
      {
        inherit (candidate) value;
        description = candidate.description or "";
        style = candidate.style or "";
        tag = candidate.tag or "";
      }
    else
      throw "pog: completion candidates must be strings or sets with a string `value`";
  normalizeCompletion = legacy: completion:
    if isString completion then
      if completion == "" then
        null
      else if legacy == "argument" && completion == "files" then
        completions.files { }
      else
        mkCompletion "dynamic" {
          script = completion;
          runtimeInputs = [ ];
          cache = null;
          inherit legacy;
        }
    else if builtins.isList completion then
      completions.values completion
    else if builtins.isAttrs completion && completion ? _pogCompletion then
      completion
    else
      throw "pog: completion must be a legacy Bash string, a candidate list, or a value from `pog.completions`";
  cacheSelector = selector:
    if isString selector && builtins.elem selector [ "cwd" "value" ] then
      selector
    else if builtins.isAttrs selector && selector ? flag && isString selector.flag then
      "flag:${selector.flag}"
    else if builtins.isAttrs selector && selector ? argument && builtins.isInt selector.argument then
      "argument:${toString selector.argument}"
    else if builtins.isAttrs selector && selector ? env && isString selector.env then
      "env:${selector.env}"
    else
      throw "pog: cache keys must be `cwd`, `value`, or sets containing `flag`, `argument`, or `env`";
  relativeRoots = {
    git-dir = "$gitdir";
    git-worktree = "$gitworktree";
    nix-profile = "$nixprofile";
    temp = "$tempdir";
    user-cache = "$usercachedir";
    user-config = "$userconfigdir";
    user-home = "$userhomedir";
    xdg-cache = "$xdgcachehome";
    xdg-config = "$xdgconfighome";
  };
  relativeToModifier = relativeTo:
    if relativeTo == null || relativeTo == "cwd" then
      [ ]
    else if isString relativeTo && builtins.hasAttr relativeTo relativeRoots then
      [ "$chdir(${builtins.getAttr relativeTo relativeRoots})" ]
    else if builtins.isAttrs relativeTo && relativeTo ? path && isString relativeTo.path then
      [ "$chdir(${relativeTo.path})" ]
    else
      throw "pog: `relativeTo` must name a supported root or contain a string `path`";
  completionToCarapace = legacy: input:
    let
      completion = normalizeCompletion legacy input;
      kind = if completion == null then "empty" else completion._pogCompletion;
      renderVector = values:
        if values == [ ] then "" else "(${builtins.toJSON values})";
      renderDynamic =
        let
          cache = completion.cache or null;
          cacheSeconds = if cache == null then 0 else cache.ttlSeconds or 0;
          cacheBy = if cache == null then [ ] else map cacheSelector (cache.by or [ ]);
          script =
            if (completion.runtimeInputs or [ ]) == [ ] then
              completion.script
            else
              ''
                export PATH="${pkgs.lib.makeBinPath completion.runtimeInputs}:$PATH"
                ${completion.script}
              '';
          config = {
            inherit script cacheSeconds cacheBy;
            legacy = completion.legacy or "";
          };
        in
        if !isString completion.script then
          throw "pog: dynamic completion `script` must be a string"
        else if !builtins.isInt cacheSeconds || cacheSeconds < 0 then
          throw "pog: completion cache `ttlSeconds` must be a non-negative integer"
        else
          [ "$pogDynamic(${encodeCompletion config})" ];
    in
    if kind == "empty" then
      [ ]
    else if kind == "values" then
      [ "$pogValues(${encodeCompletion (map normalizeCandidate completion.candidates)})" ]
    else if kind == "files" then
      [ "$files${renderVector completion.extensions}" ] ++ relativeToModifier completion.relativeTo
    else if kind == "directories" then
      [ "$directories" ] ++ relativeToModifier completion.relativeTo
    else if kind == "executables" then
      [ "$executables${renderVector completion.directories}" ] ++ relativeToModifier completion.relativeTo
    else if kind == "dynamic" then
      renderDynamic
    else if kind == "merge" then
      concatLists (map (completionToCarapace "") completion.sources)
    else if kind == "modifier" then
      completionToCarapace "" completion.completion ++ [
        ("$" + completion.modifier + (if completion.argument == null then "" else "(${completion.argument})"))
      ]
    else if kind == "message" then
      [ "$message(${completion.message})" ]
    else if kind == "delegate" then
      [ "$spec(${toString completion.completionSpec})" ]
    else if kind == "raw" && builtins.isList completion.actions && builtins.all isString completion.actions then
      completion.actions
    else
      throw "pog: unsupported completion kind `${kind}`";
  formatAndCheckBash = path: ''
    shfmt -w -ln bash -i 2 -ci -sr "${path}"
    bash -n "${path}"
    shfmt -d -ln bash -i 2 -ci -sr "${path}"
    shellcheck "${path}"
  '';
in
rec {
  overlay = _final: _prev: { inherit pog; };
  _ = with pkgs; let
    core = "${pkgs.coreutils}/bin";
  in
  rec {
    # binaries
    ## text
    awk = "${pkgs.gawk}/bin/awk";
    bat = "${pkgs.bat}/bin/bat";
    curl = "${pkgs.curl}/bin/curl";
    figlet = "${pkgs.figlet}/bin/figlet";
    git = "${pkgs.git}/bin/git";
    gum = "${pkgs.gum}/bin/gum";
    gron = "${pkgs.gron}/bin/gron";
    jq = "${pkgs.jq}/bin/jq";
    rg = "${pkgs.ripgrep}/bin/rg";
    sed = "${pkgs.gnused}/bin/sed";
    grep = "${pkgs.gnugrep}/bin/grep";
    shfmt = "${pkgs.shfmt}/bin/shfmt";
    cut = "${core}/cut";
    head = "${core}/head";
    mktemp = "${core}/mktemp";
    realpath = "${core}/realpath";
    sort = "${core}/sort";
    tail = "${core}/tail";
    tr = "${core}/tr";
    uniq = "${core}/uniq";
    uuid = "${pkgs.libossp_uuid}/bin/uuid";
    yq = "${pkgs.yq-go}/bin/yq";
    y2j = "${pkgs.remarshal}/bin/yaml2json";

    ## nix
    _nix = pkgs.nixVersions.nix_2_32;
    cachix = "${pkgs.cachix}/bin/cachix";
    nixpkgs-fmt = "${pkgs.nixpkgs-fmt}/bin/nixpkgs-fmt";
    nixfmt = "${pkgs.nixfmt}/bin/nixfmt";

    ## common
    ls = "${core}/ls";
    date = "${core}/date";
    find = "${pkgs.findutils}/bin/find";
    xargs = "${pkgs.findutils}/bin/xargs";
    getopt = "${pkgs.getopt}/bin/getopt";
    fzf = "${pkgs.fzf}/bin/fzf";
    sox = "${pkgs.sox}/bin/play";
    ffmpeg = "${pkgs.ffmpeg-full}/bin/ffmpeg";
    ssh = "${pkgs.openssh}/bin/ssh";
    which = "${pkgs.which}/bin/which";

    ## containers
    d = "${pkgs.docker-client}/bin/docker";
    k = "${pkgs.kubectl}/bin/kubectl";

    ## clouds
    aws = "${pkgs.awscli2}/bin/aws";
    gcloud = "${pkgs.google-cloud-sdk}/bin/gcloud";

    # fzf partials
    fzfq = ''${fzf} -q "$1" --no-sort --header-first --reverse'';
    fzfqm = ''${fzfq} -m'';

    # ssh partials
    _ssh = {
      hosts = ''${_.grep} '^Host' ~/.ssh/config ~/.ssh/config.d/* 2>/dev/null | ${_.grep} -v '[?*]' | ${_.cut} -d ' ' -f 2- | ${_.sort} -u'';
    };

    # docker partials
    docker =
      let
        tab = "--format table";
      in
      {
        di = "${d} images ${tab}";
        da = "${d} ps --all ${tab}";
        get_image = "${awk} '{ print $3 }'";
        get_container = "${awk} '{ print $1 }'";
      };

    # k8s partials
    k8s = {
      ka = "${k} get pods | ${sed} '1d'";
      get_id = "${awk} '{ print $1 }'";
      fmt = rec {
        _fmt =
          let
            parseCol = col: "${col.k}:${col.v}";
          in
          columns: "-o custom-columns='${concatStringsSep "," (map parseCol columns)}'";
        _cols = {
          name = { k = "NAME"; v = ".metadata.name"; };
          namespace = { k = "NAMESPACE"; v = ".metadata.namespace"; };
          ready = { k = "READY"; v = ''status.conditions[?(@.type=="Ready")].status''; };
          status = { k = "STATUS"; v = ".status.phase"; };
          ip = { k = "IP"; v = ".status.podIP"; };
          node = { k = "NODE"; v = ".spec.nodeName"; };
          image = { k = "IMAGE"; v = ".spec.containers[*].image"; };
          host_ip = { k = "HOST_IP"; v = ".status.hostIP"; };
          start_time = { k = "START_TIME"; v = ".status.startTime"; };
        };
        pod = _fmt (with _cols; [
          name
          namespace
          ready
          status
          ip
          node
          image
        ]);
      };
    };

    # json partials
    refresh_patch = ''
      echo "spec.template.metadata.labels.date = \"$(${_.date} +'%s')\";" |
        ${_.gron} -u |
        ${_.tr} -d '\n' |
        ${_.sed} -E 's#\s+##g'
    '';

    # flags to reuse
    flags = {
      aws = {
        region = {
          name = "region";
          default = "us-east-1";
          description = "the AWS region in which to do this operation";
          argument = "REGION";
          envVar = "AWS_REGION";
          completion = ''echo -e '${concatStringsSep "\\n" _.globals.aws.regions}' '';
        };
      };
      gcp = {
        project = {
          name = "project";
          description = "the GCP project in which to do this operation";
          argument = "PROJECT_ID";
          completion = ''${_.gcloud} projects list | ${_.sed} '1d' | ${_.awk} '{print $1}' '';
        };
      };
      k8s = {
        all_namespaces = {
          name = "all_namespaces";
          short = "A";
          description = "operate across all namespaces";
          bool = true;
        };
        namespace = {
          name = "namespace";
          default = "default";
          description = "the namespace in which to do this operation";
          argument = "NAMESPACE";
          completion = ''${_.k} get ns | ${_.sed} '1d' | ${_.awk} '{print $1}' '';
        };
        nodes = {
          name = "nodes";
          description = "the node(s) on which to perform this operation";
          argument = "NODES";
          completion = ''${_.k} get nodes -o wide | ${_.sed} '1d' | ${_.awk} '{print $1}' '';
          prompt = ''
            ${_.k} get nodes -o wide |
              ${_.fzfqm} --header-lines=1 |
              ${_.k8s.get_id}
          '';
          promptError = "you must specify one or more nodes!";
        };
        serviceaccount = {
          name = "serviceaccount";
          description = "the service account to use for the workload";
          argument = "SERVICE_ACCOUNT";
          default = "default";
          completion = ''${_.k} get sa -o=jsonpath='{range .items[*].metadata.name}{@}{"\n"}{end}' '';
        };
      };
      docker = {
        image = {
          name = "image";
          description = "the docker image to use";
          argument = "IMAGE";
          prompt = ''
            echo -e "${globals.hacks.docker.default_images}\n$(${globals.hacks.docker.get_local_images})" |
              ${_.sort} -u |
              ${_.fzfq} --header "IMAGE"'';
          promptError = "you must specify a docker image!";
          completion = ''
            echo -e "${globals.hacks.docker.default_images}\n$(${globals.hacks.docker.get_local_images})" |
              ${_.sort} -u
          '';
        };
      };
      common = {
        force = {
          name = "force";
          bool = true;
          description = "forcefully do this thing";
        };
        color = {
          name = "color";
          description = "the bash color/style to use [${bashColorsList}]";
          argument = "COLOR";
          default = "green";
          completion = ''echo "${bashColorsList} ${toUpper bashColorsList}"'';
        };
      };
      github = {
        owner = {
          name = "owner";
          description = "the github user or organization that owns the repo";
          required = true;
        };
        repo = {
          name = "repo";
          description = "the github repo to pull tags from";
          required = true;
        };
      };
      nix = {
        overmind = {
          name = "overmind";
          short = "o";
          bool = true;
          description = "include an overmind config";
        };
      };
      python = {
        package = {
          name = "package";
        };
        version = {
          name = "version";
          short = "r";
        };
      };
      ssh = {
        host = {
          name = "host";
          short = "H";
          description = "the ssh host to use";
          completion = _._ssh.hosts;
          prompt = ''${_._ssh.hosts} | ${_.fzfq} --header "HOST"'';
          promptError = "you must specify a ssh host!";
        };
      };
    };
    globals = {
      hacks = {
        bash_or_sh = "if command -v bash >/dev/null 2>/dev/null; then exec bash; else exec sh; fi";
        docker = {
          default_images = concatStringsSep "\\n" _.globals.images;
          get_local_images = ''
            docker image ls --format "{{.Repository}}:{{.Tag}}" 2>/dev/null |
              ${_.grep} -v '<none>' |
              ${_.sort} -u
          '';
        };
      };

      # docker images to use in various spots
      images = [
        "alpine:3.22"
        "ubuntu:24.04"
        "almalinux:9.6"
        "almalinux:10.0"
        "ghcr.io/jpetrucciani/nix:latest"
        "ghcr.io/jpetrucciani/python-3.13:latest"
        "ghcr.io/jpetrucciani/k8s-aws:latest"
        "ghcr.io/jpetrucciani/k8s-gcp:latest"
        "node:22"
        "node:24"
        "python:3.11"
        "python:3.12"
        "python:3.13"
        "ruby:3.4.5"
        "nicolaka/netshoot:latest"
      ];
      aws = {
        regions = [
          "us-east-1"
          "us-east-2"
          "us-west-1"
          "us-west-2"
          "us-gov-west-1"
          "ca-central-1"
          "eu-west-1"
          "eu-west-2"
          "eu-central-1"
          "ap-southeast-1"
          "ap-southeast-2"
          "ap-south-1"
          "ap-northeast-1"
          "ap-northeast-2"
          "sa-east-1"
          "cn-north-1"
        ];
      };
      gcp = {
        regions = [
          "asia-east1"
          "asia-east2"
          "asia-northeast1"
          "asia-northeast2"
          "asia-northeast3"
          "asia-south1"
          "asia-south2"
          "asia-southeast1"
          "asia-southeast2"
          "australia-southeast1"
          "australia-southeast2"
          "europe-central2"
          "europe-north1"
          "europe-west1"
          "europe-west2"
          "europe-west3"
          "europe-west4"
          "europe-west6"
          "northamerica-northeast1"
          "northamerica-northeast2"
          "southamerica-east1"
          "southamerica-west1"
          "us-central1"
          "us-east1"
          "us-east4"
          "us-west1"
          "us-west2"
          "us-west3"
          "us-west4"
        ];
      };
      tencent = {
        regions = [
          "ap-guangzhou"
          "ap-shanghai"
          "ap-nanjing"
          "ap-beijing"
          "ap-chengdu"
          "ap-chongqing"
          "ap-hongkong"
          "ap-singapore"
          "ap-jakarta"
          "ap-seoul"
          "ap-tokyo"
          "ap-mumbai"
          "ap-bangkok"
          "na-toronto"
          "sa-saopaulo"
          "na-siliconvalley"
          "na-ashburn"
          "eu-frankfurt"
          "eu-moscow"
        ];
      };
    };
  };

  writeBashBinChecked = name: text:
    pkgs.stdenv.mkDerivation {
      inherit name text;
      dontUnpack = true;
      passAsFile = "text";
      nativeBuildInputs = [
        pkgs.bash
        pkgs.shellcheck
        pkgs.shfmt
      ];
      installPhase = ''
        mkdir -p $out/bin
        echo '#!/bin/bash' > $out/bin/${name}
        cat $textPath >> $out/bin/${name}
        chmod +x $out/bin/${name}
        ${formatAndCheckBash "$out/bin/${name}"}
      '';
    };

  bashEsc = ''\033'';
  bashColors = [
    {
      name = "reset";
      code = ''${bashEsc}[0m'';
    }
    # styles
    {
      name = "bold";
      code = ''${bashEsc}[1m'';
    }
    {
      name = "dim";
      code = ''${bashEsc}[2m'';
    }
    {
      name = "italic";
      code = ''${bashEsc}[3m'';
    }
    {
      name = "underlined";
      code = ''${bashEsc}[4m'';
    }
    {
      # note: this probably doesn't work in the majority of terminal emulators
      name = "blink";
      code = ''${bashEsc}[5m'';
    }
    {
      name = "invert";
      code = ''${bashEsc}[7m'';
    }
    {
      name = "hidden";
      code = ''${bashEsc}[8m'';
    }
    # foregrounds
    {
      name = "black";
      code = ''${bashEsc}[1;30m'';
    }
    {
      name = "red";
      code = ''${bashEsc}[1;31m'';
    }
    {
      name = "green";
      code = ''${bashEsc}[1;32m'';
    }
    {
      name = "yellow";
      code = ''${bashEsc}[1;33m'';
    }
    {
      name = "blue";
      code = ''${bashEsc}[1;34m'';
    }
    {
      name = "purple";
      code = ''${bashEsc}[1;35m'';
    }
    {
      name = "cyan";
      code = ''${bashEsc}[1;36m'';
    }
    {
      name = "grey";
      code = ''${bashEsc}[1;90m'';
    }
    # backgrounds
    {
      name = "red_bg";
      code = ''${bashEsc}[41m'';
    }
    {
      name = "green_bg";
      code = ''${bashEsc}[42m'';
    }
    {
      name = "yellow_bg";
      code = ''${bashEsc}[43m'';
    }
    {
      name = "blue_bg";
      code = ''${bashEsc}[44m'';
    }
    {
      name = "purple_bg";
      code = ''${bashEsc}[45m'';
    }
    {
      name = "cyan_bg";
      code = ''${bashEsc}[46m'';
    }
    {
      name = "grey_bg";
      code = ''${bashEsc}[100m'';
    }
  ];
  bashColorsList = concatStringsSep " " (map (x: x.name) (filter (x: x.name != "reset") bashColors));

  writeBashBinCheckedWithFlags = pog;
  pog = {
    inherit (bundlers) toAppImage toArx toHostScript;
    inherit completions;
    parsing = parsingModes;
    helpers = rec {
      fn = {
        add = "${_.awk} '{print $1 + $2}'";
        sub = "${_.awk} '{print $1 - $2}'";
        ts_to_seconds = "${_.awk} -F\: '{ for(k=NF;k>0;k--) sum+=($k*(60^(NF-k))); print sum }'";
      };
      var = {
        empty = name: ''[ -z "''${${name}}" ]'';
        notEmpty = name: ''[ -n "''${${name}}" ]'';
      };
      file = {
        exists = name: ''[ -f "''${${name}}" ]'';
        notExists = name: ''[ ! -f "''${${name}}" ]'';
        empty = name: ''[ ! -s "''${${name}}" ]'';
        notEmpty = name: ''[ -s "''${${name}}" ]'';
      };
      dir = {
        exists = name: ''[ -d "${name}" ]'';
        notExists = name: ''[ ! -d "${name}" ]'';
        empty = name: ''[ -z "$(ls -A '${name}')" ]'';
        notEmpty = name: ''[ ! -z "$(ls -A '${name}')" ]'';
      };
      timer = {
        start = name: ''_pog_start_${name}="$(${_.date} +%s.%N)"'';
        stop = name: ''"$(echo "$(${_.date} +%s.%N) - $_pog_start_${name}" | ${pkgs.pkgs.bc}/bin/bc -l)"'';
        round = places: ''${pkgs.pkgs.coreutils}/bin/printf '%.*f\n' ${toString places}'';
      };
      confirm = yesno;
      yesno = { prompt ? "Would you like to continue?", exit_code ? 0 }: ''
        ${_.gum} confirm "${prompt}" || exit ${toString exit_code}
      '';

      spinner = { command, spinner ? "dot", align ? "left", title ? "processing..." }: ''
        ${_.gum} spin --spinner="${spinner}" --align="${align}" --title="${title}" ${command}
      '';
      spinners = [
        "line"
        "dot"
        "minidot"
        "jump"
        "pulse"
        "points"
        "globe"
        "moon"
        "monkey"
        "meter"
        "hamburger"
      ];

      # shorthands
      flag = var.notEmpty;
      notFlag = var.empty;

      # tmp stuff
      tmp =
        let
          mktmp = "${pkgs.coreutils}/bin/mktemp";
          ext = extension: ''"$(${mktmp} --suffix=.${extension})"'';
        in
        {
          _mktemp = mktmp;
          json = ext "json";
          yaml = ext "yaml";
          csv = ext "csv";
          txt = ext "txt";
        };
    };
    __functor = _: pogFn;
  };
  pogFn =
    { name
    , version ? "0.0.0"
    , script ? ""
    , description ? "a helpful bash script with flags, created through nix + pog!"
    , flags ? [ ]
    , parsedFlags ? map flag flags
    , persistentFlags ? [ ]
    , parsedPersistentFlags ? map (definition: flag (definition // { persistent = true; })) persistentFlags
    , exclusiveFlags ? [ ]
    , arguments ? [ ]
    , argumentCompletion ? "files"
    , commands ? [ ]
    , aliases ? [ ]
    , group ? ""
    , hidden ? false
    , parsing ? null
    , runtimeInputs ? [ ]
    , hostCommands ? [ ]
    , bashBible ? false
    , beforeExit ? ""
    , strict ? false
    , flagPadding ? 20
    , showDefaultFlags ? false
    , shortDefaultFlags ? true
    }:
    let
      inherit (pog) helpers;
      filterBlank = filter (x: x != "");
      shortHelp = if shortDefaultFlags then "-h|" else "";
      shortVerbose = if shortDefaultFlags then "-v|" else "";
      shortHelpDoc = if shortDefaultFlags then "-h, " else "";
      shortVerboseDoc = if shortDefaultFlags then "-v, " else "";
      defaultFlagHelp = if showDefaultFlags then "[${shortHelp}--help] [${shortVerbose}--verbose] [--no-color] " else "";
      # clap-style subcommands: when `commands` is non-empty the binary becomes a
      # recursive dispatcher. each command node is the same shape as a pog call
      # (name/description/flags/arguments/script) and may itself contain `commands`.
      sanitize = replaceStrings [ "-" ] [ "_" ];
      sanitizePath = p: concatStringsSep "__" (map sanitize p);

      # build one tree node; reuses the exact per-flag outputs of `flag`
      mkNode = path: inheritedPersistentFlags: spec:
        let
          nodePath = path ++ [ spec.name ];
          localFlags = spec.parsedFlags or (map flag (spec.flags or [ ]));
          ownPersistentFlags = spec.parsedPersistentFlags or (
            map
              (definition: flag (definition // { persistent = true; }))
              (spec.persistentFlags or [ ])
          );
          declaredFlags = localFlags ++ ownPersistentFlags;
          rawNodeFlags = inheritedPersistentFlags ++ declaredFlags;
          flagNames = map (nodeFlag: nodeFlag.cliName) rawNodeFlags;
          shortFlagNames = filter (short: short != "") (map (nodeFlag: nodeFlag.short) rawNodeFlags);
          nodeFlags =
            if builtins.length flagNames != builtins.length (pkgs.lib.unique flagNames) then
              throw "pog: '${concatStringsSep " " nodePath}' has duplicate long flag names"
            else if builtins.length shortFlagNames != builtins.length (pkgs.lib.unique shortFlagNames) then
              throw "pog: '${concatStringsSep " " nodePath}' has duplicate short flag names"
            else
              rawNodeFlags;
          children = spec.commands or [ ];
          isParent = children != [ ];
          nodeAliases =
            if builtins.isList (spec.aliases or [ ])
              && builtins.all isString (spec.aliases or [ ]) then
              spec.aliases or [ ]
            else
              throw "pog: '${concatStringsSep " " nodePath}' aliases must be strings";
          nodeGroup = spec.group or "";
          nodeHidden = spec.hidden or false;
          requestedParsing = normalizeParsingMode pathStr (spec.parsing or null);
          nodeParsing =
            if requestedParsing == null then
              if isParent then "non-interspersed" else "interspersed"
            else if isParent && requestedParsing == "interspersed" then
              throw "pog: '${concatStringsSep " " nodePath}' cannot use interspersed parsing while dispatching subcommands"
            else if isParent && requestedParsing == "passthrough" then
              throw "pog: '${concatStringsSep " " nodePath}' cannot use passthrough parsing while dispatching subcommands"
            else
              requestedParsing;
          nodeArgs = normalizeArguments (spec.arguments or [ ]);
          nodeDesc = spec.description or "a pog command";
          rawScript = spec.script or "";
          nodeScript = if builtins.isFunction rawScript then rawScript helpers else rawScript;
          hasScript = nodeScript != "";
          nodeBeforeExit = spec.beforeExit or "";
          hasBeforeExit = nodeBeforeExit != "";
          exitFn = "_pog_exit_" + sanitizePath nodePath;
          # define this node's exit hook, and register it on entry so every command
          # on the active path tears down (deepest first) when the process exits
          exitFnDef =
            if hasBeforeExit then ''
              ${ignoreUnused}
              ${exitFn}() {
              ${nodeBeforeExit}
              }
            '' else "";
          register = if hasBeforeExit then "_pog_cleanup_fns+=(${exitFn})" else "";
          fnName = "_pog_cmd_" + sanitizePath nodePath;
          helpFn = "_pog_help_" + sanitizePath nodePath;
          pathStr = concatStringsSep " " nodePath;
          childNodes = map (mkNode nodePath (inheritedPersistentFlags ++ ownPersistentFlags)) children;
          childCommandNames = concatLists (map (child: [ child.name ] ++ child.aliases) childNodes);
          checkedChildNodes =
            if builtins.length childCommandNames != builtins.length (pkgs.lib.unique childCommandNames) then
              throw "pog: '${pathStr}' has duplicate subcommand names or aliases"
            else
              childNodes;
          completionFlags = listToAttrs
            (
              map
                (nodeFlag: nameValuePair nodeFlag.carapaceName nodeFlag.description)
                localFlags
            ) // {
            "${if shortDefaultFlags then "-h, " else ""}--help" = "print this help and exit";
            "${if shortDefaultFlags then "-v, " else ""}--verbose" = "enable verbose logging and info";
            "--no-color" = "disable color and other formatting";
          };
          persistentCompletionFlags = listToAttrs (
            map
              (nodeFlag: nameValuePair nodeFlag.carapaceName nodeFlag.description)
              ownPersistentFlags
          );
          flagCompletions = listToAttrs (
            map
              (nodeFlag: nameValuePair nodeFlag.cliName nodeFlag.carapaceCompletion)
              (filter (nodeFlag: nodeFlag.carapaceCompletion != null) nodeFlags)
          );
          fallbackCompletion = spec.argumentCompletion or "files";
          variadicArguments = filter (argument: argument.variadic) nodeArgs;
          checkedArguments =
            if builtins.length variadicArguments > 1 then
              throw "pog: '${pathStr}' has more than one variadic argument"
            else if variadicArguments != [ ] && !(builtins.elemAt nodeArgs (builtins.length nodeArgs - 1)).variadic then
              throw "pog: '${pathStr}' has a variadic argument that is not last"
            else
              nodeArgs;
          hasVariadicArgument = checkedArguments != [ ]
            && (builtins.elemAt checkedArguments (builtins.length checkedArguments - 1)).variadic;
          fixedArguments =
            if hasVariadicArgument then
              builtins.genList
                (index: builtins.elemAt checkedArguments index)
                (builtins.length checkedArguments - 1)
            else
              checkedArguments;
          argumentCompletionActions = argument:
            completionToCarapace "argument" (argument.completion or fallbackCompletion)
            ++ pkgs.lib.optional (argument.description != "") "$usage(${argument.description})";
          positionalCompletion =
            if isParent then
              [ ]
            else
              map argumentCompletionActions fixedArguments;
          positionalAnyCompletion =
            if isParent then
              [ ]
            else if hasVariadicArgument then
              argumentCompletionActions
                (builtins.elemAt checkedArguments (builtins.length checkedArguments - 1))
            else
              completionToCarapace "argument" fallbackCompletion;
          rawExclusiveFlags = spec.exclusiveFlags or [ ];
          exclusiveFlagNames = concatLists rawExclusiveFlags;
          checkedExclusiveFlags =
            if !builtins.isList rawExclusiveFlags
              || !(builtins.all
              (flagGroup: builtins.isList flagGroup && builtins.all isString flagGroup)
              rawExclusiveFlags) then
              throw "pog: '${pathStr}' exclusive flag groups must be lists of flag names"
            else if !(builtins.all (flagName: builtins.elem flagName flagNames) exclusiveFlagNames) then
              throw "pog: '${pathStr}' has an exclusive group containing an unknown flag"
            else
              rawExclusiveFlags;
          flagByName = flagName:
            builtins.head (filter (nodeFlag: nodeFlag.cliName == flagName) nodeFlags);
          exclusiveChecks = concatStringsSep "\n" (map
            (flagGroup: ''
              local _pog_exclusive_count=0
              ${concatStringsSep "\n" (map
                (flagName:
                  let nodeFlag = flagByName flagName;
                  in ''
                    if [[ ''${${nodeFlag.seenName}:-0} -eq 1 ]]; then
                      _pog_exclusive_count=$((_pog_exclusive_count + 1))
                    fi
                  '')
                flagGroup)}
              if [[ $_pog_exclusive_count -gt 1 ]]; then
                die "flags ${concatStringsSep ", " (map (flagName: "--${flagName}") flagGroup)} are mutually exclusive" 2
              fi
            '')
            checkedExclusiveFlags);
          passthroughShortFlags = filter (nodeFlag: nodeFlag.short != "") nodeFlags;
          passthroughShortNames =
            pkgs.lib.optionals shortDefaultFlags [ "h" "v" ]
            ++ map (nodeFlag: nodeFlag.short) passthroughShortFlags;
          passthroughParser = ''
              local -a _pog_passthrough_args=()
              local _pog_cluster _pog_cluster_char _pog_cluster_consume_next
              local _pog_cluster_known _pog_cluster_value _pog_index
              while [[ $# -gt 0 ]]; do
                case "$1" in
                  --)
                    shift
                    _pog_passthrough_args+=("$@")
                    break
                    ;;
                  ${if shortDefaultFlags then "-h | " else ""}--help)
                    ${helpFn}
                    ;;
                  ${if shortDefaultFlags then "-v | " else ""}--verbose)
                    VERBOSE=1
                    shift
                    ;;
                  --no-color)
                    NO_COLOR=1
                    shift
                    ;;
            ${_ind 4 (concatStringsSep "\n" (map (nodeFlag: nodeFlag.passthroughCases) nodeFlags))}
                  -)
                    _pog_passthrough_args+=("$1")
                    shift
                    ;;
                  -*)
                    _pog_cluster="''${1#-}"
                    _pog_cluster_known=1
                    ${if passthroughShortNames == [ ] then
                      "_pog_cluster_known=0"
                    else ''
                      for (( _pog_index = 0; _pog_index < ''${#_pog_cluster}; _pog_index++ )); do
                        _pog_cluster_char="''${_pog_cluster:_pog_index:1}"
                        case "$_pog_cluster_char" in
                          ${if shortDefaultFlags then "h | v) ;;" else ""}
            ${_ind 8 (concatStringsSep "\n" (map (nodeFlag: nodeFlag.passthroughShortValidationCase) passthroughShortFlags))}
                          *)
                            _pog_cluster_known=0
                            break
                            ;;
                        esac
                      done
                    ''}
                    if [[ $_pog_cluster_known -eq 1 ]]; then
                      _pog_cluster_consume_next=0
                      for (( _pog_index = 0; _pog_index < ''${#_pog_cluster}; _pog_index++ )); do
                        _pog_cluster_char="''${_pog_cluster:_pog_index:1}"
                        case "$_pog_cluster_char" in
                          ${if shortDefaultFlags then ''
                            h) ${helpFn} ;;
                            v) VERBOSE=1 ;;
                          '' else ""}
            ${_ind 8 (concatStringsSep "\n" (map (nodeFlag: nodeFlag.passthroughShortCase) passthroughShortFlags))}
                        esac
                      done
                      if [[ $_pog_cluster_consume_next -eq 1 ]]; then
                        shift 2
                      else
                        shift
                      fi
                    else
                      _pog_passthrough_args+=("$1")
                      shift
                    fi
                    ;;
                  *)
                    _pog_passthrough_args+=("$1")
                    shift
                    ;;
                esac
              done
              set -- "''${_pog_passthrough_args[@]}"
          '';
          # a child may mark itself `default = true`; bare invocation of this node
          # then forwards to that child instead of running a script or printing help.
          # the forward chains, so a default child that is itself a parent with its
          # own default subcommand keeps descending.
          defaultChildren = filter (child: child.default) checkedChildNodes;
          defaultChild =
            if defaultChildren == [ ] then null
            else if builtins.length defaultChildren > 1
            then throw "pog: '${pathStr}' has more than one subcommand marked `default = true`"
            else builtins.head defaultChildren;
          hasDefaultChild = defaultChild != null;
          usageTail = if isParent then "<COMMAND>" else
          concatStringsSep " " (
            map
              (argument: "${toUpper argument.name}${if argument.variadic then "..." else ""}")
              checkedArguments
          );
          argumentHelp = concatStringsSep "\n" (map
            (argument:
              "${rightPad flagPadding (toUpper argument.name + (if argument.variadic then "..." else ""))}"
              + "\t${argument.description}")
            (filter (argument: argument.description != "") checkedArguments));
          visibleChildren = filter (child: !child.hidden) checkedChildNodes;
          childGroups = pkgs.lib.unique (map (child: child.group) visibleChildren);
          childHelp = concatStringsSep "\n" (map
            (childGroup:
              let
                groupedChildren = filter (child: child.group == childGroup) visibleChildren;
                entries = concatStringsSep "\n" (map
                  (child:
                    "${rightPad flagPadding child.name}\t${child.description}"
                    + "${if child.aliases == [ ] then "" else " [aliases: ${concatStringsSep ", " child.aliases}]"}"
                    + "${if child.default then " (default)" else ""}")
                  groupedChildren);
              in
              if childGroup == "" then entries else "${childGroup}:\n${ind entries}")
            childGroups);
          # what runs when this node is invoked bare (no subcommand). a node's own
          # `script` and a default subcommand are both "bare action" behaviours, so
          # allowing both would be ambiguous — reject it at eval time.
          bareAction =
            if hasScript && hasDefaultChild
            then throw "pog: '${pathStr}' sets both a `script` and a `default = true` subcommand; pick one"
            else if hasScript then nodeScript
            else if hasDefaultChild then ''${defaultChild.fnName} "$@"''
            else helpFn;
          dispatch = ''
            case "''${1:-}" in
            ${concatStringsSep "\n" (map
              (child: ''${concatStringsSep "|" ([ child.name ] ++ child.aliases)}) shift; ${child.fnName} "$@" ;;'')
              checkedChildNodes)}
            "")
            ${bareAction}
            ;;
            *)
            die "unknown command: '$1'" 3
            ;;
            esac'';
          body = if isParent then dispatch else nodeScript;
          fnText = ''
            ${exitFnDef}
            ${ignoreUnused}
            ${helpFn}() {
              # help is a no-op meta action; drop the trap so no exit hooks fire
              trap - SIGINT SIGTERM ERR EXIT
              ${pkgs.coreutils}/bin/cat <<EOF
              Usage: ${pathStr} ${defaultFlagHelp}${concatStringsSep " " (map (x: x.ex) (filter (nodeFlag: !nodeFlag.hidden) nodeFlags))} ${usageTail}

              ${nodeDesc}

              Flags:
            ${ind (concatStringsSep "\n" (map (x: x.helpDoc) (filter (nodeFlag: !nodeFlag.hidden) nodeFlags)))}
              ${rightPad flagPadding "${shortHelpDoc}--help"}${"\t"}print this help and exit
              ${rightPad flagPadding "${shortVerboseDoc}--verbose"}${"\t"}enable verbose logging and info
              ${rightPad flagPadding "--no-color"}${"\t"}disable color and other formatting${if argumentHelp == "" then "" else "\n\n  Arguments:\n" + ind argumentHelp}${if isParent then "\n\n  Commands:\n" + ind childHelp else ""}
            EOF
              exit 0
            }
            ${ignoreUnused}
            ${fnName}() {
              # shellcheck disable=SC2034
            ${_ind 3 (concatStringsSep "\n" (map (x: x.flagDefault) declaredFlags))}
            ${_ind 3 (concatStringsSep "\n" (map (x: x.seenDefault) declaredFlags))}
            ${if nodeParsing == "disabled" then "" else if nodeParsing == "passthrough" then passthroughParser else ''
              local OPTIONS LONGOPTS PARSED
              OPTIONS="${if nodeParsing == "non-interspersed" then "+" else ""}${if shortDefaultFlags then "h,v," else ""}${concatStringsSep "," (map (x: x.shortOpt) nodeFlags)}"
              LONGOPTS="help,no-color,verbose,${concatStringsSep "," (map (x: x.longOpt) nodeFlags)}"
              # shellcheck disable=SC2251
              ! PARSED=$(${_.getopt} --options=$OPTIONS --longoptions=$LONGOPTS --name "${spec.name}" -- "$@")
              if [[ ''${PIPESTATUS[0]} -ne 0 ]]; then
                exit 2
              fi
              eval set -- "$PARSED"
              while true; do
                case "$1" in
                  ${shortHelp}--help)
                    ${helpFn}
                    ;;
                  ${shortVerbose}--verbose)
                    VERBOSE=1
                    shift
                    ;;
                  --no-color)
                    NO_COLOR=1
                    shift
                    ;;
            ${_ind 5 (concatStringsSep "\n" (map (x: x.definition) nodeFlags))}
                  --)
                    shift
                    break
                    ;;
                  *)
                    echo "unknown flag passed"
                    exit 3
                    ;;
                  esac
                done
            ''}
            ${_ind 3 exclusiveChecks}
            ${_ind 3 register}
            ${_ind 3 (concatStringsSep "\n" (filterBlank (map (x: x.flagPrompt) declaredFlags)))}
            # User code stays unindented so literal heredoc terminators remain valid.
            ${body}
            }
          '';
          self = {
            inherit fnName fnText pathStr isParent nodeFlags declaredFlags checkedExclusiveFlags;
            inherit (spec) name;
            aliases = nodeAliases;
            description = nodeDesc;
            group = nodeGroup;
            hidden = nodeHidden;
            default = spec.default or false;
            parsing = nodeParsing;
            carapace = {
              inherit (spec) name;
              aliases = nodeAliases;
              description = nodeDesc;
              group = nodeGroup;
              hidden = nodeHidden;
              flags = completionFlags;
              persistentflags = persistentCompletionFlags;
              exclusiveflags = checkedExclusiveFlags;
              completion = optionalAttrs (flagCompletions != { })
                {
                  flag = flagCompletions;
                }
              // optionalAttrs (positionalCompletion != [ ]) {
                positional = positionalCompletion;
              }
              // optionalAttrs (positionalAnyCompletion != [ ]) {
                positionalany = positionalAnyCompletion;
              };
              commands = map (node: node.carapace) checkedChildNodes;
            } // optionalAttrs (requestedParsing != null && nodeParsing != "passthrough") {
              parsing = nodeParsing;
            };
          };
        in
        self // { all = [ self ] ++ concatLists (map (node: node.all) checkedChildNodes); };

      rootNode = mkNode [ ] [ ] {
        inherit
          name description flags parsedFlags persistentFlags parsedPersistentFlags exclusiveFlags
          arguments argumentCompletion script commands aliases group hidden parsing beforeExit
          ;
      };
      allNodes = rootNode.all;
      hasPassthrough = builtins.any (node: node.parsing == "passthrough") allNodes;
      completionSpec = yamlFormat.generate "${name}-carapace-spec.yaml" rootNode.carapace;

      commandsText = ''
        # shellcheck disable=SC2317
        ${if strict then "set -o errexit -o pipefail -o noclobber" else ""}
        VERBOSE="''${POG_VERBOSE-}"
        NO_COLOR="''${POG_NO_COLOR-}"
        export PATH="${pkgs.lib.makeBinPath runtimeInputs}:$PATH"

        setup_colors() {
          if [[ -t 2 ]] && [[ -z "''$NO_COLOR" ]] && [[ "''$TERM" != "dumb" ]]; then
            ${concatStringsSep " " (map (x: ''${toUpper x.name}="${x.code}"'') bashColors)}
          else
            ${concatStringsSep " " (map (x: ''${toUpper x.name}=""'') bashColors)}
          fi
        }
        # shellcheck disable=SC2329
        debug() {
          if [ -n "$VERBOSE" ]; then
            echo -e "''${PURPLE}$1''${RESET}" >&2
          fi
        }
        # exit hooks registered (in path order) by each command on the active path;
        # cleanup runs them in reverse so the deepest command tears down first
        _pog_cleanup_fns=()
        ${ignoreUnused}
        cleanup() {
          trap - SIGINT SIGTERM ERR EXIT
          local _i
          for (( _i = ''${#_pog_cleanup_fns[@]} - 1; _i >= 0; _i-- )); do
            "''${_pog_cleanup_fns[_i]}"
          done
        }
        ${ignoreUnused}
        _pog_signal() {
          local status=$1
          cleanup
          exit "$status"
        }
        trap '_pog_signal 130' SIGINT
        trap '_pog_signal 143' SIGTERM
        trap cleanup ERR EXIT

        ${concatStringsSep "\n" (map (x: ''
          ${ignoreUnused}
          ${x.name}(){
            echo -e "''${${toUpper x.name}}$1''${RESET}"
          }
        '') bashColors)}

        # shellcheck disable=SC2329
        die() {
          local msg=$1
          local code=''${2-1}
          echo >&2 -e "''${RED}$msg''${RESET}"
          exit "$code"
        }
        setup_colors
        ${if bashBible then bashbible.bible else ""}
        ${concatStringsSep "\n" (map (n: n.fnText) allNodes)}
        ${rootNode.fnName} "$@"
      '';

    in
    pkgs.stdenv.mkDerivation (finalAttrs: {
      inherit version;
      pname = name;
      dontUnpack = true;
      nativeBuildInputs = [
        carapaceSpec
        pkgs.bash
        pkgs.installShellFiles
        pkgs.lua
        pkgs.shellcheck
        pkgs.shfmt
      ];
      passAsFile = [ "text" ];
      text = commandsText;
      installPhase = ''
        mkdir -p $out/bin
        echo '#!/bin/bash' >$out/bin/${name}
        cat $textPath >>$out/bin/${name}
        chmod +x $out/bin/${name}
        ${formatAndCheckBash "$out/bin/${name}"}

        spec=$out/share/carapace/specs/${name}.yaml
        install -Dm644 ${completionSpec} "$spec"
        completion_command=$out/bin/_${name}_complete
        cat > "$completion_command" <<EOF
        #!/bin/bash
        ${if hasPassthrough then "export CARAPACE_LENIENT=1" else ""}
        exec ${carapaceSpec}/bin/carapace-spec "$spec" "\$@"
        EOF
        chmod +x "$completion_command"
        ${formatAndCheckBash "$completion_command"}

        completion_root=$out/share/pog/completions

        generate_completion() {
          local shell=$1
          local extension=$2
          local target=$completion_root/$shell/${name}.$extension

          mkdir -p "$(dirname "$target")"
          ${carapaceSpec}/bin/carapace-spec "$spec" "$shell" > "$target"
          test -s "$target"
          if [[ $shell == xonsh ]]; then
            substituteInPlace "$target" \
              --replace-fail "'carapace-spec', '$spec'," "'$completion_command',"
          else
            substituteInPlace "$target" \
              --replace-fail "carapace-spec '$spec'" "$completion_command"
          fi
          substituteInPlace "$target" \
            --replace-quiet "xargs $completion_command" "${pkgs.findutils}/bin/xargs $completion_command" \
            --replace-quiet "| sed " "| ${pkgs.gnused}/bin/sed "
        }

        generate_completion bash bash
        generate_completion bash-ble bash
        generate_completion cmd-clink lua
        generate_completion elvish elv
        generate_completion fish fish
        generate_completion nushell nu
        generate_completion oil oil
        generate_completion powershell ps1
        generate_completion tcsh csh
        generate_completion xonsh py
        generate_completion zsh zsh
        # Avoid inserting a second separator when completing before existing text.
        substituteInPlace "$completion_root/zsh/${name}.zsh" \
          --replace-fail '    [[ ''${#valuesArr[@]} -gt 1 ]]' \
          '    [[ ''${RBUFFER:-} != [[:space:]]* ]] || valuesArr=("''${valuesArr[@]% }")
            [[ ''${#valuesArr[@]} -gt 1 ]]'

        bash -n "$completion_root/bash/${name}.bash"
        ${pkgs.lua}/bin/luac -p "$completion_root/cmd-clink/${name}.lua"
        installShellCompletion --bash --name ${name} "$completion_root/bash/${name}.bash"
        installShellCompletion --fish --name ${name}.fish "$completion_root/fish/${name}.fish"
        installShellCompletion --zsh --name _${name} "$completion_root/zsh/${name}.zsh"
        install -Dm644 "$completion_root/nushell/${name}.nu" \
          "$out/share/nushell/vendor/autoload/${name}.nu"
      '';
      passthru = {
        pog = {
          inherit carapaceSpec hostCommands runtimeInputs;
          completionSpec = "${finalAttrs.finalPackage}/share/carapace/specs/${name}.yaml";
          completionCommand = "${finalAttrs.finalPackage}/bin/_${name}_complete";
        };
        toArx = pog.toArx finalAttrs.finalPackage;
        toAppImage = pog.toAppImage finalAttrs.finalPackage;
        toHostScript = pog.toHostScript finalAttrs.finalPackage;
      };
      meta = {
        inherit description;
        mainProgram = name;
      };
    });

  flag =
    { name
    , _name ? (replaceStrings [ "-" ] [ "_" ] name)
    , short ? substring 0 1 name
    , shortDef ? if short != "" then "-${short}|" else ""
    , default ? ""
    , hasDefault ? (stringLength default) > 0
    , bool ? false
    , optionalValue ? false
    , repeatable ? false
    , hidden ? false
    , persistent ? false
    , marker ? if bool then "" else if optionalValue then "::" else ":"
    , description ? "a flag"
    , argument ? "VAR"
    , envVar ? "POG_" + (replaceStrings [ "-" ] [ "_" ] (toUpper name))
    , required ? false
    , prompt ? if required then "true" else ""
    , promptError ? "you must specify a value for '--${name}'!"
    , promptErrorExitCode ? 3
    , hasPrompt ? (stringLength prompt) > 0
    , completion ? ""
    , hasCompletion ? !(isString completion && completion == "")
    , flagPadding ? 20
    }:
    if bool && optionalValue then
      throw "pog: flag `--${name}` cannot be boolean and take an optional value"
    else
      let
        assign = value: ''
          _pog_seen_${_name}=1
          ${
            if repeatable && bool then
              ''${_name}=$(( ''${${_name}:-0} + 1 ))''
            else if repeatable then
              ''${_name}+=(${value})''
            else if bool then
              ''${_name}=1''
            else
              ''${_name}=${value}''
          }
        '';
        missingValue = option: ''
          printf 'option %s requires an argument\n' '${option}' >&2
          return 2
        '';
        unexpectedValue = option: ''
          printf 'option %s does not accept an argument\n' '${option}' >&2
          return 2
        '';
        longPassthroughCase =
          if bool then ''
            --${name})
              ${assign "1"}
              shift
              ;;
            --${name}=*)
              ${unexpectedValue "--${name}"}
              ;;
          '' else if optionalValue then ''
            --${name})
              ${assign ''""''}
              shift
              ;;
            --${name}=*)
              ${assign ''"''${1#*=}"''}
              shift
              ;;
          '' else ''
            --${name})
              if [[ $# -lt 2 ]]; then
                ${missingValue "--${name}"}
              fi
              ${assign ''"$2"''}
              shift 2
              ;;
            --${name}=*)
              ${assign ''"''${1#*=}"''}
              shift
              ;;
          '';
        shortPassthroughCase =
          if short == "" then
            ""
          else if bool then ''
            -${short})
              ${assign "1"}
              shift
              ;;
          '' else if optionalValue then ''
            -${short})
              ${assign ''""''}
              shift
              ;;
            -${short}?*)
              ${assign ''"''${1#-${short}}"''}
              shift
              ;;
          '' else ''
            -${short})
              if [[ $# -lt 2 ]]; then
                ${missingValue "-${short}"}
              fi
              ${assign ''"$2"''}
              shift 2
              ;;
            -${short}?*)
              ${assign ''"''${1#-${short}}"''}
              shift
              ;;
          '';
      in
      {
        inherit short default bool marker description optionalValue repeatable hidden persistent;
        cliName = name;
        name = _name;
        seenName = "_pog_seen_${_name}";
        carapaceName = "${if short != "" then "-${short}, " else ""}--${name}"
          + "${if optionalValue then "?" else if bool then "" else "="}"
          + "${if repeatable then "*" else ""}"
          + "${if hidden then "&" else ""}";
        carapaceCompletion = if hasCompletion then completionToCarapace "flag" completion else null;
        shortOpt = "${short}${marker}";
        longOpt = "${name}${marker}";
        flagDefault =
          if repeatable && bool then
            ''${_name}="''${${envVar}:-${if hasDefault then default else "0"}}"''
          else if repeatable then
            ''
              ${_name}=()
              _pog_default_${_name}="''${${envVar}:-${default}}"
              if [[ -n "''${_pog_default_${_name}}" ]]; then
                ${_name}+=("''${_pog_default_${_name}}")
              fi
            ''
          else
            ''${_name}="''${${envVar}:-${default}}"'';
        seenDefault = '': "''${_pog_seen_${_name}:=0}"'';
        flagPrompt =
          if hasPrompt then ''
            [ -z "''${${_name}}" ] && ${_name}="$(${prompt})"
            [ -z "''${${_name}}" ] && die "${promptError}" ${toString promptErrorExitCode}
          '' else "";
        ex = "[${shortDef}--${name}${if bool then "" else " ${if optionalValue then "[${argument}]" else argument}"}]${if repeatable then "..." else ""}";
        helpDoc =
          let
            base = (if short != "" then "-${short}, " else "") + "--${name}";
          in
          (rightPad flagPadding base) +
          "\t${description}" +
          "${if hasDefault then " [default: '${default}']" else ""}" +
          "${if hasPrompt then " [will prompt if not passed in]" else ""}" +
          "${if bool then " [bool]" else ""}" +
          "${if optionalValue then " [optional value]" else ""}" +
          "${if repeatable then " [repeatable]" else ""}" +
          "${if persistent then " [persistent]" else ""}"
        ;
        definition = ''
          ${shortDef}--${name})
              ${assign (if bool then "1" else ''"$2"'')}
              shift ${if bool then "" else "2"}
              ;;'';
        passthroughCases = longPassthroughCase + shortPassthroughCase;
        passthroughShortValidationCase =
          if short == "" then
            ""
          else if bool then ''
            ${short}) ;;
          '' else ''
            ${short}) break ;;
          '';
        passthroughShortCase =
          if short == "" then
            ""
          else if bool then ''
            ${short})
              ${assign "1"}
              ;;
          '' else if optionalValue then ''
            ${short})
              _pog_cluster_value="''${_pog_cluster:$((_pog_index + 1))}"
              ${assign ''"$_pog_cluster_value"''}
              break
              ;;
          '' else
            ''
              ${short})
                _pog_cluster_value="''${_pog_cluster:$((_pog_index + 1))}"
                if [[ -n "$_pog_cluster_value" ]]; then
                  ${assign ''"$_pog_cluster_value"''}
                else
                  if [[ $# -lt 2 ]]; then
                    ${missingValue "-${short}"}
                  fi
                  ${assign ''"$2"''}
                  _pog_cluster_consume_next=1
                fi
                break
                ;;
            '';
      };

  foo = pog {
    name = "foo";
    description = "a tester script for pog, my classic bash bin + flag + bashbible meme";
    bashBible = true;
    beforeExit = ''
      green "this is beforeExit - foo test complete!"
    '';
    flags = [
      _.flags.common.color
      {
        name = "functions";
        short = "";
        description = "list all functions! (this is a lot of text)";
        bool = true;
      }
    ];
    script = h: with h; ''
      color="''${color^^}"
      trim_string "     foo       "
      upper 'foo'
      lower 'FOO'
      lstrip "The Quick Brown Fox" "The "
      urlencode "https://github.com/dylanaraps/pure-bash-bible"
      remove_array_dups 1 1 2 2 3 3 3 3 3 4 4 4 4 4 5 5 5 5 5 5
      hex_to_rgb "#FFFFFF"
      rgb_to_hex "255" "255" "255"
      date "%a %d %b  - %l:%M %p"
      uuid
      bar 1 10
      ''${functions:+get_functions}
      debug "''${GREEN}this is a debug message, only visible when passing -v (or setting POG_VERBOSE)!"
      black "this text is 'black'"
      red "this text is 'red'"
      green "this text is 'green'"
      yellow "this text is 'yellow'"
      blue "this text is 'blue'"
      purple "this text is 'purple'"
      cyan "this text is 'cyan'"
      grey "this text is 'grey'"
      green_bg "this text has a green background"
      purple_bg "this text has a purple background"
      yellow_bg "this text has a yellow background"
      bold "this text should be bold!"
      dim "this text should be dim!"
      italic "this text should be italic!"
      underlined "this text should be underlined!"
      blink "this text might blink on certain terminal emulators!"
      invert "this text should be inverted!"
      hidden "this text should be hidden!"
      echo -e "''${GREEN_BG}''${RED}this text is red on a green background and looks awful''${RESET}"
      echo -e "''${!color}this text has its color set by a flag '--color' or env var 'POG_COLOR' (default green)''${RESET}"
      ${spinner {command="sleep 3";}}
      ${confirm {exit_code=69;}}
      die "this is a die" 0
    '';
  };

  # a tester for clap-style recursive subcommands
  tool = pog {
    name = "tool";
    description = "a tester for pog's recursive subcommands";
    flags = [ _.flags.common.color ];
    # top-level exit hook (runs last, after any command's hook)
    beforeExit = ''echo "[tool] root cleanup"'';
    # default action when invoked with no subcommand
    script = ''echo -e "''${!color}tool root - no subcommand given (color=$color)''${RESET}"'';
    commands = [
      {
        name = "remote";
        description = "manage remotes";
        commands = [
          {
            name = "list";
            description = "list remotes";
            # bare `tool remote` forwards here instead of printing help
            default = true;
            script = ''echo "listing remotes (default subcommand)"'';
          }
          {
            name = "add";
            description = "add a remote";
            arguments = [ "remote_name" ];
            # per-command exit hook (runs first, before the root hook)
            beforeExit = ''echo "[tool remote add] cleanup"'';
            flags = [
              {
                name = "url";
                description = "the remote url";
                required = true;
              }
              _.flags.k8s.namespace
            ];
            script = ''echo "adding remote '$1' -> $url (ns=$namespace)"'';
          }
          {
            name = "remove";
            description = "remove a remote";
            script = ''echo "removing remote '$1'"'';
          }
          {
            name = "list-all";
            description = "list every remote (hyphenated command name)";
            script = ''echo "listing all remotes"'';
          }
        ];
      }
      {
        name = "status";
        description = "show status";
        flags = [
          {
            name = "short";
            description = "short output";
            bool = true;
          }
        ];
        script = ''echo "status (short=''${short:-0})"'';
      }
    ];
  };
}
