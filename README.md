A Nix flake that makes it (relatively) easy to build an out-of-tree Buildroot image using Nix.

### Example flake and usage

Assuming the `./` (`src`) directory contains the `BR2_EXTERNAL` skeleton, with at least `Config.in`, `external.mk`, `external.desc`, `configs/my_cool_defconfig`. 

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-24.05";
    buildroot-nix.url = "github:zopieux/nix-buildroot";
  };

  outputs = { self, nixpkgs, buildroot-nix, ... }@inputs:
    let
      pkgs = import nixpkgs { system = "x86_64-linux"; };
      myBuildRoot = buildroot-nix.lib.mkBuildroot {
        name = "cool";
        src = ./.;
        inherit pkgs;  # pkgs = pkgs;
        defconfig = "my_cool_defconfig";
        # This won't exist yet, and that's okay.
        lockfile = ./buildroot.lock;
        # Any extra host build inputs needed by Buildroot.
        nativeBuildInputs = with pkgs; [ libxcrypt ];
      };
    in {
      packages.x86_64-linux.lockFile = myBuildRoot.lockFile;
      packages.x86_64-linux.default = myBuildRoot.build;
      devShells.x86_64-linux.default = myBuildRoot.devShell;
    };
}
```

Then you first need to lock the input source downloads for reproducibility, as Nix sandbox prevents arbitrary downloads:

```shell
$ nix build '.#lockFile'
$ cp result buildroot.lock
$ git add buildroot.lock
```

Now you're settled and can proceed with the full build:

```shell
$ nix build
```

You can also drop into the dev shell, which aliases the `make` command so that it's ready to use:

```shell
$ nix develop
bash$ make menuconfig
```


### External hashes

External files referenced in `*_defconfig` etc. are not known to Buildroot and therefore the hash is unavailable. Typically:

```
# Random out-of-tree URL or local file.
BR2_LINUX_KERNEL_CUSTOM_TARBALL_LOCATION=https://example.org/foo.tar.gz
```

For those, you need to explicitely provide the sha256 hash (no other type supported) to the builder:

```shell
$ nix-prefetch-url https://example.org/foo.tar.gz
4d3403d32df5f9a2a2053a4ff667bfab4d11a31932db5779560000429403d785
```

```nix
myBuildRoot = buildroot-nix.lib.mkBuildroot {
  name = "cool";
  # ...
  # NEW:
  extraHashes = {
    "foo.tar.gz" = "4d3403d32df5f9a2a2053a4ff667bfab4d11a31932db5779560000429403d785";
  };
};
```

### Buildroot clone

This flake builds with Buildroot tag `2024.08` if not otherwise provided. You can use any clone you like, for example using a flake input:

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-24.05";
    buildroot-nix.url = "github:zopieux/nix-buildroot";
    # NEW:
    buildroot = {
      url = "https://gitlab.com/buildroot.org/buildroot.git";
      type = "git";
      rev = "769d71ae84c7a3d43ee92a1d126b2937713cc811"; # 2024.08
      flake = false;
    };
  };

  outputs = { self, nixpkgs, buildroot-nix, ... }@inputs:
    # ...
      myBuildRoot = buildroot-nix.lib.mkBuildroot {
        name = "cool";
        # ...
        # NEW:
        buildroot = inputs.buildroot;
      }; 
}
```

## License

MIT.

## Acknowledgments

This is in great part adapted from https://github.com/velentr/buildroot.nix, which is also MIT licensed.
