let
  extend = p: p.extend (final: prev: {
    lib = prev.lib // (import ./. { pkgs = final; lib = prev.lib; });
  });
  mkLib = { pkgs, lib ? pkgs.lib }: let
    toCamelCase = str: let
      parts = lib.splitString "-" str;
      upperFirst = word: (lib.toUpper (builtins.substring 0 1 word)) + (builtins.substring 1 (builtins.stringLength word) word);
    in if (builtins.length parts) < 2
      then str
      else let
        first = lib.head parts;
        rest = map upperFirst (lib.tail parts);
      in builtins.concatStringsSep "" ([first] ++ rest);
  in (lib.mapAttrs'
    (fileName: _: let
      baseName = lib.removeSuffix ".nix" fileName;
      camelName = toCamelCase baseName;
      importedFile = import (./. + "/${fileName}");
      args = if builtins.isFunction importedFile then builtins.functionArgs importedFile else {};
      value = if builtins.isFunction importedFile
        then (overrides: let
          provider = { inherit pkgs lib; stdenv = pkgs.stdenv; } // pkgs;
          requested = builtins.intersectAttrs args provider;
        in importedFile (requested // overrides))
        else importedFile;
    in lib.nameValuePair camelName value)
    (lib.filterAttrs (name: type: 
      type == "regular" && lib.hasSuffix ".nix" name && name != "default.nix"
    ) (builtins.readDir ./.))
  ) // {
    inherit toCamelCase;
    strings = lib.strings // { inherit toCamelCase; };
  };
in
{
  __functor = self: mkLib;
  inherit extend;
}
