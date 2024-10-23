{
  name,
  pkgs ? import <nixpkgs> { },
  src,
  buildroot ? (
    builtins.fetchGit {
      url = "https://gitlab.com/buildroot.org/buildroot.git";
      ref = "ref/tags/2024.08";
      rev = "638dc5c8ddb5e05aef35f371e195c2166b407803";
    }
  ),
  defconfig,
  lockfile,
  nativeBuildInputs ? [ ],
  extraHashes ? { },
}:
let
  inherit (pkgs) stdenv;
  makeFHSEnv = pkgs.buildFHSEnv {
    name = "make-fhs";
    runScript = "make";
    targetPkgs =
      pkgs:
      with pkgs;
      [
        bc
        cpio
        file
        perl
        rsync
        unzip
        util-linux
        wget
        which
      ]
      ++ nativeBuildInputs;
  };
  buildDir = "/build/br";
  buildrootMake = "${makeFHSEnv}/bin/make-fhs --silent BR2_EXTERNAL=$PWD O=${buildDir} -C ${buildroot}";
  devShell = (makeFHSEnv.overrideAttrs { runScript = "bash"; }).env.overrideAttrs {
    shellHook = ''
      alias make="${buildrootMake}"
      echo -e "The 'make' command is aliased to use relevant Buildroot flags.\nUse \\make to call the original make command."
    '';
  };
  buildrootBase = {
    inherit src;
    configurePhase = ''
      mkdir -p ${buildDir}
      ${buildrootMake} ${defconfig}
    '';
    hardeningDisable = [ "format" ];
  };
  lockedPackageInputs =
    let
      lockedInputs = builtins.fromJSON (builtins.readFile lockfile);
      symlinkCommands = builtins.map (
        file:
        let
          lockedAttrs = lockedInputs.${file};
          input = pkgs.fetchurl {
            name = file;
            urls = lockedInputs.${file}.uris;
            hash = "${lockedAttrs.algo}:${lockedAttrs.checksum}";
          };
        in
        "ln -s ${input} $out/'${file}'"
      ) (builtins.attrNames lockedInputs);
    in
    stdenv.mkDerivation {
      name = "${name}-sources";
      dontUnpack = true;
      dontConfigure = true;
      buildPhase = "mkdir $out";
      installPhase = pkgs.lib.concatStringsSep "\n" symlinkCommands;
    };
  extraHashesFile = (pkgs.formats.json { }).generate "hashes.json" extraHashes;
in
rec {
  inherit devShell;
  packageInputs = lockedPackageInputs;
  packageInfo = stdenv.mkDerivation (
    buildrootBase
    // {
      name = "${name}-packageinfo.json";
      buildPhase = ''
        ${buildrootMake} show-info > packageinfo.json
      '';
      installPhase = ''
        cp packageinfo.json $out
      '';
    }
  );
  lockFile = pkgs.stdenv.mkDerivation {
    name = "${name}-buildroot.lock";
    buildInputs = with pkgs; [ python3 ];
    dontUnpack = true;
    dontConfigure = true;
    dontInstall = true;
    buildPhase = ''
      python3 ${./make-package-lock.py} --hashes ${extraHashesFile} --buildroot ${buildroot} --input ${packageInfo} --output $out
    '';
  };
  build = stdenv.mkDerivation (
    buildrootBase
    // {
      inherit name;
      outputs = [
        "out"
        "sdk"
      ];
      buildPhase = ''
        export BR2_DL_DIR=/build/source/downloads
        mkdir -p $BR2_DL_DIR
        for lockedInput in ${lockedPackageInputs}/*; do
          ln -s $lockedInput "$BR2_DL_DIR/$(basename $lockedInput)"
        done
        ${buildrootMake}
        ${buildrootMake} sdk
      '';
      installPhase = ''
        mkdir $out $sdk
        cp -r output/images $out/
        cp -r output/host $sdk
        sh $sdk/host/relocate-sdk.sh
      '';
      dontFixup = true;
    }
  );
}
