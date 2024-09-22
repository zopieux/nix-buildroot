{
  description = "Flake for building out-of-tree Buildroot using nix";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";

  outputs =
    { self, nixpkgs }:
    let
      supportedSystems = [ "x86_64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      pkgs = forAllSystems (system: nixpkgs.legacyPackages.${system});
    in
    {
      lib.mkBuildroot = args: import ./default.nix args;
      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-rfc-style);
    };
}
