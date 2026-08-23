#!/usr/bin/env bash
# Note: This script is intended to be SOURCED, not executed.

go_to_top_level_directory() {
  # if git is not installed, return
  if ! [ -x "$(command -v git)" ]; then
    return
  fi
  # if current directory is not a git directory, return
  if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    return
  fi
  # go to top-level of git directory
  local base_dir="$(git rev-parse --show-toplevel)"
  cd "$base_dir"
}

load_env_file() {
  local target_file="${ENV_FILE:-.env}"
  local force=false;
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -f|--force) force=true; shift ;;
      *) shift ;;
    esac
  done
  if [ ! -r "$target_file" ]; then go_to_top_level_directory; fi
  if [ ! -r "$target_file" ]; then return; fi
  if [ "$force" = "true" ]; then
    set -a
    # shellcheck disable=SC1091 source=/dev/null
    source "$target_file"
    set +a
    return
  fi
  while IFS='=' read -r key value || [[ -n "$key" ]]; do
    # 1. Clean Key: Strip 'export ' and all whitespace
    key=$(echo "$key" | sed -E 's/^export[[:space:]]+//; s/[[:space:]]//g')
    
    [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue

    # 2. Clean Value: Strip leading/trailing whitespace ONLY
    # (We don't strip internal whitespace because it's part of the value)
    value=$(echo "$value" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')

    # 3. Strip ONE layer of matching outer quotes (Consistency Check)
    # This specifically looks for "..." or '...' and peels only the outermost pair.
    if [[ ($value == \"*\" ) || ($value == \'*\' ) ]]; then
      if [[ $value == \"*\" ]]; then
        value="${value%\"}"; value="${value#\"}"
      elif [[ $value == \'*\' ]]; then
        value="${value%\'}"; value="${value#\'}"
      fi
    fi
    
    if [ -z "${!key}" ]; then
      export "$key"="$value"
    else
      # warn the user if a value is skipped and unique
      if [[ $- == *i* ]] && [ "${!key}" != "$value" ]; then
        echo -e "\033[1;93m[!] Ignoring $key: Value already set to '${!key}'\033[0m"
      fi
    fi
  done < "$target_file"
}

INITIAL_PWD="$PWD"
cleanup() {
  cd "$INITIAL_PWD" > /dev/null 2>&1
  if [[ $- == *i* ]]; then
    trap - INT EXIT
  fi
  unset -f go_to_top_level_directory load_env_file cleanup
  unset INITIAL_PWD
}
if [[ $- == *i* ]]; then
  trap cleanup INT EXIT
fi

load_env_file "$@"
cleanup
