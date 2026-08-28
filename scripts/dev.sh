#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

### UTILS ###

CURRENT_DIR="$PWD"
SCRIPT_DIR="$(
  cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &&
  pwd -P
)"
CURRENT_GIT_ROOT_DIR=""
SCRIPT_GIT_ROOT_DIR=""
if command -v git >/dev/null 2>&1; then
  CURRENT_GIT_ROOT_DIR="$(
    git -C "$CURRENT_DIR" rev-parse --show-toplevel 2>/dev/null || true
  )"
  SCRIPT_GIT_ROOT_DIR="$(
    git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || true
  )"
fi

# print an error message
echo_error() {
  echo "Error:" "$@" 1>&2
}

# if the listed commands aren't found, exit with an error message
test_commands() {
  local missing=false
  for command_name in "$@"; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
      echo_error "The required program \"$command_name\" is not installed"
      missing=true
    fi
  done
  if [[ "$missing" == true ]]; then exit 1; fi
}

# get a file from relative path, checking from root dir of git project, then script dir, then current dir
get_file() {
  local file_path="$1"
  local candidate
  if [[ "$file_path" == /* ]]; then
    candidate="$(realpath -e -- "$file_path" 2>/dev/null)" || return 1
    [[ -f "$candidate" && -r "$candidate" ]] || return 1
    printf '%s\n' "$candidate"
    return 0
  fi
  local dir
  for dir in "$SCRIPT_GIT_ROOT_DIR" "$CURRENT_GIT_ROOT_DIR" "$SCRIPT_DIR" "$CURRENT_DIR"; do
    [[ -n "$dir" ]] || continue
    if candidate="$(realpath -e -- "$dir/$file_path" 2>/dev/null)"; then
      [[ -f "$candidate" && -r "$candidate" ]] || continue
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}
test_commands realpath

# load env variables from the secrets file
load_env_variables() {
  local load_env_script
  if ! load_env_script="$(get_file "scripts/load-env.sh")"; then
    echo_error "Could not locate scripts/load-env.sh"
    return 1
  fi
  local secrets_env_file
  for secrets_env_file in "$@"; do
    # shellcheck disable=SC1091 source=/dev/null
    ENV_FILE="$secrets_env_file" source "$load_env_script"
  done
}

# if the listed env variables aren't found, exit with an error message
test_env_variables() {
  local missing=false
  local var_name
  for var_name in "$@"; do
    if [[ -z "${!var_name:-}" ]]; then
      echo_error "The required environment variable \"$var_name\" is not defined"
      missing=true
    fi
  done
  if [[ "$missing" == true ]]; then exit 1; fi
}

### SCRIPT ###

# entrypoint of the script
main() {
  : "${SECRETS_ENV_FILE:=.env}"
  load_env_variables "$SECRETS_ENV_FILE"
  echo "TODO: dev.sh"
}

main "$@"
