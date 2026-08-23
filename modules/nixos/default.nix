{
  pkgs ? import <nixpkgs> {},
  mkContainer ? pkgs.lib.mkContainer,
}: let
  name = "nixos";
  version = "0.0.0";
in rec {
  packages = {
    # appImage = pkgs.callPackage ./packages/app-image.nix {
    #   inherit name version;
    # };
    # containerDebug = pkgs.callPackage ./packages/container.nix {
    #   inherit mkContainer;
    #   image = packages.appImage.override { includeDevTools = true; };
    # };
    # containerSlim = packages.containerDebug.override {
    #   image = packages.appImage.override { includeDevTools = false; };
    # };
  };
  devShells.default = import ./shell.nix { inherit pkgs; };
}
