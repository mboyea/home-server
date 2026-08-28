{
  pkgs,
}: let
  _pkgs = let
    libSrc = if
      builtins.pathExists ../lib/default.nix
    then import ../lib
    else {};
  in if
    !(pkgs.lib ? mkContainer)
    && (builtins.isAttrs libSrc)
    && (libSrc ? extend)
  then libSrc.extend pkgs
  else pkgs;
  allDirs = pkgs.lib.filterAttrs (n: v: v == "directory") (builtins.readDir ./.);
  validDirs = pkgs.lib.filterAttrs (n: v: builtins.pathExists (./. + "/${n}/default.nix")) allDirs;
in _pkgs.lib.mapAttrs'
  (n: v: let
    name = pkgs.lib.toCamelCase n;
    value = import (./. + "/${n}") { pkgs = _pkgs; };
  in _pkgs.lib.nameValuePair name value)
  validDirs
