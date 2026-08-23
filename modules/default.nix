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
in _pkgs.lib.mapAttrs'
  (n: v: let
    name = _pkgs.lib.toCamelCase n;
    value = import (./. + "/${n}") { pkgs = _pkgs; };
  in _pkgs.lib.nameValuePair name value)
  (_pkgs.lib.filterAttrs (n: v: v == "directory") (builtins.readDir ./.))
