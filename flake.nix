{
  description = "MTCBPC Home Server";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs = { self, nixpkgs, flake-utils, ... }: let
    pname = "mtcbpc-home-server";
    version = "0.0.0";
    utils = flake-utils;
    _lib = import ./lib;
    _modules = import ./modules;
  in {
    lib = _lib;
    modules = _modules;
  } // utils.lib.eachDefaultSystem (
    system: let
      pkgs = _lib.extend (import nixpkgs { inherit system; });
      modules = _modules { inherit pkgs; };
    in rec {
      legacyPackages = pkgs;
      packages = {
        # aa = pkgs.lib.run {
        #   name = "${pname}-aa-${version}";
        #   target = ./scripts/aa.sh;
        # };
        help = pkgs.lib.run {
           name = "${pname}-help-${version}";
           target = ./scripts/help.sh;
        };
      };
      apps = {
        help = utils.lib.mkApp { drv = packages.help; };
        default = apps.help;
      };
      devShells = {
        default = pkgs.mkShell {
          inputsFrom = pkgs.lib.mapAttrsToList (n: v: v.devShells.default) modules;
          packages = pkgs.lib.flakeRunAlias { inherit pname version packages; } ++ [];
          shellHook = ''
            # load .env
            ENV_FILE=".env" source ./scripts/load-env.sh
            # suppress warning about dirty git for nix commands
            export NIX_CONFIG="warn-dirty = false"
            # print success message
            echo -e "\033[1;32mSUCCESSFULLY LOADED DEVSHELL FOR ${pname}-${version}\033[0m"
          '';
        };
      };
    }
  );
}
