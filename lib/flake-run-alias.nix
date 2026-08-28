{ pkgs, pname, version, packages }:
let
  run-alias = pkgs.writeShellScriptBin "run" ''
    TARGET_SCRIPT="''$1"
    ROOT_DIR=$(${pkgs.git}/bin/git rev-parse --show-toplevel 2>/dev/null)
    ROOT_DIR=''${ROOT_DIR:-$(pwd)}
    SCRIPT_PATH="$ROOT_DIR/scripts/$TARGET_SCRIPT.sh"
    LOCAL_CACHE_DIR="$ROOT_DIR/.direnv/scripts-run-cache"
    LOCAL_CACHE_PATH="$LOCAL_CACHE_DIR/$TARGET_SCRIPT"
    SHELL_CACHE_PATH=$(command -v "${pname}-$TARGET_SCRIPT-${version}" 2>/dev/null)
    if [[ ! -f "$SCRIPT_PATH" ]]; then
      exec nix run .#"$TARGET_SCRIPT" "''${@:2}"
    fi
    if ! ${pkgs.git}/bin/git ls-files --error-unmatch "$SCRIPT_PATH" &>/dev/null; then
      echo -e "\033[1;31mWarning: Git is not tracking '$TARGET_SCRIPT.sh'\033[0m"
      echo -e "\033[1;33mRun 'git add $SCRIPT_PATH' so Nix can see it.\033[0m"
      exit 1
    fi
    SCRIPT_TIME=$(stat -c %Y "$SCRIPT_PATH")
    LOCAL_CACHE_TIME=$(stat -c %Y "$LOCAL_CACHE_PATH" 2>/dev/null || echo 0)
    if [[ -L "$LOCAL_CACHE_PATH" ]] && (( "$LOCAL_CACHE_TIME" >= "$SCRIPT_TIME" )); then
      exec "$(readlink -f "$LOCAL_CACHE_PATH")" "''${@:2}"
    fi
    SHELL_CACHE_TIME=$(nix path-info --json "$SHELL_CACHE_PATH" 2>/dev/null | ${pkgs.jq}/bin/jq '.[].registrationTime // 0')
    if [[ -n "$SHELL_CACHE_PATH" ]] && (( "$SHELL_CACHE_TIME" >= "$SCRIPT_TIME" )); then
      mkdir -p "$LOCAL_CACHE_DIR"
      ln -sf "$SHELL_CACHE_PATH" "$LOCAL_CACHE_PATH"
      exec "$SHELL_CACHE_PATH" "''${@:2}"
    fi
    if BUILD_PATH=$(nix build .#"$TARGET_SCRIPT" --no-link --print-out-paths); then
      BIN_PATH=$(find "$BUILD_PATH/bin" -type f -executable | head -n 1)
      mkdir -p "$LOCAL_CACHE_DIR"
      ln -sf "$BIN_PATH" "$LOCAL_CACHE_PATH"
      exec "$BIN_PATH" "''${@:2}"
    else
      exit $?
    fi
  '';
  packages-cache = pkgs.symlinkJoin { name = "${pname}-${version}-scripts"; paths = builtins.attrValues packages; };
in [
  run-alias
  packages-cache
]
