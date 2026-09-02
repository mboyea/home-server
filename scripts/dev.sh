#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

### DOCUMENTATION ###

# CHANGELOG
# 1.0.0 published on 2026-09-XX by Matthew Boyea
# - User can run one or more targets with zero or more options
# - The special help target is only viable as the first target; otherwise it will be interpreted as an option
# - The special all target will pass its options to every other possible target (excluding the help target)
# - Options passed with the all target are inherited softly; they're placed first in the arg list regardless of position of the all target:
#   > run dev vw --debug all --slim
#   will pass '--slim' to all targets; vw will execute with '--slim --debug'; if these args conflict, '--debug' should take precedence

show_help() {
  cat <<'EOF'
  Usage:
    run dev <target> [options...]
  Targets:
    all
    help|--help|-h
    vaultwarden|vw
EOF
}

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
  # handle absolute paths
  if [[ "$file_path" == /* ]]; then
    candidate="$(realpath -e -- "$file_path" 2>/dev/null)" || return 1
    [[ -f "$candidate" && -r "$candidate" ]] || return 1
    printf '%s\n' "$candidate"
    return 0
  fi
  # search for the file in the preferred directory order
  local dir
  for dir in "$SCRIPT_GIT_ROOT_DIR" "$CURRENT_GIT_ROOT_DIR" "$SCRIPT_DIR" "$CURRENT_DIR"; do
    [[ -n "$dir" ]] || continue
    # resolve and utilize the first matching readable file
    if candidate="$(realpath -e -- "$dir/$file_path" 2>/dev/null)"; then
      [[ -f "$candidate" && -r "$candidate" ]] || continue
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  # fail in the case that no valid file was found
  return 1
}

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

# run dev all --slim vw --debug

# [0]='all'
# [1]='vaultwarden.sh'
declare -a STAGED_TARGETS=()

# [all]='TARGET_ARGS_ALL'
# [vaultwarden.sh]='TARGET_ARGS_VAULTWARDEN'
declare -A STAGED_TARGET_ARG_ARRAY_NAMES=()

# TARGET_ARGS_ALL=('--slim')
# TARGET_ARGS_VAULTWARDEN=('--debug')

# get the name of arg array for a target
get_target_arg_array_name() {
  local target_key="${1%.sh}"
  target_key="${target_key^^}"
  target_key="${target_key//[^A-Z0-9_]/_}"
  printf '%s\n' "TARGET_ARGS_$target_key"
}

# stage target and its args to the list
stage_target() {
  local target_script="$1"
  shift
  local arg_array_name="${STAGED_TARGET_ARG_ARRAY_NAMES[$target_script]:-}"
  if [[ -z "$arg_array_name" ]]; then
    arg_array_name="$(get_target_arg_array_name "$target_script")"
    STAGED_TARGET_ARG_ARRAY_NAMES["$target_script"]="$arg_array_name"
    STAGED_TARGETS+=("$target_script")
    declare -g -a "$arg_array_name=()"
  fi
  local -n target_args="$arg_array_name"
  target_args+=("$@")
}

# first expand staged args from all to the other targets; then execute scripts
process_staged_targets() {
  # expand staged args from all, if any
  local all_target_arg_array_name="${STAGED_TARGET_ARG_ARRAY_NAMES[all]:-}"
  if [[ -n "$all_target_arg_array_name" ]]; then
    local -n all_args_ref="$all_target_arg_array_name"
    local target_script
    local target_arg_array_name
    # for each potential target
    for target_script in "${ALL_TARGETS[@]}"; do
      target_arg_array_name="${STAGED_TARGET_ARG_ARRAY_NAMES[$target_script]:-}"
      # stage target if it was not already staged
      if [[ -z "$target_arg_array_name" ]]; then
        stage_target "$target_script"
        target_arg_array_name="${STAGED_TARGET_ARG_ARRAY_NAMES[$target_script]}"
      fi
      # prepend args from all to the target
      local -n target_args_ref="$target_arg_array_name"
      target_args_ref=(
        "${all_args_ref[@]}"
        "${target_args_ref[@]}"
      )
      unset -n target_args_ref
    done
    # remove all from the execution list
    local target_index 
    for target_index in "${!STAGED_TARGETS[@]}"; do
      if [[ "${STAGED_TARGETS[$target_index]}" == 'all' ]]; then
        unset "STAGED_TARGETS[$target_index]"
      fi
    done
    STAGED_TARGETS=("${STAGED_TARGETS[@]}")
    unset 'STAGED_TARGET_ARG_ARRAY_NAMES[all]'
  fi
  # execute each staged target
  # TODO HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH
  local target_script
  local arg_array_name

  for target_script in "${STAGED_TARGETS[@]}"; do
    arg_array_name="${STAGED_TARGET_ARG_ARRAY_NAMES[$target_script]}"

    local -n atarget_args_ref="$arg_array_name"

    printf 'Target: %s\n' "$TARGET_BASE_PATH/$target_script"
    printf 'Args:'

    if [[ "${#atarget_args_ref[@]}" -eq 0 ]]; then
      printf ' <none>'
    else
      printf ' %q' "${atarget_args_ref[@]}"
    fi

    printf '\n'
  done
}

# interpret args, distribute args across targets
interpret_args() {
  # default to all --debug
  if [[ "$#" -eq 0 ]]; then
    set -- 'all' '--debug'
  fi

  # interpret args
  local target_script=''
  local target_args=()
  local potential_target_script=''
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      all)
        if [[ -n "$target_script" ]]; then
          stage_target "$target_script" "${target_args[@]}"
        fi
        target_script='all'
        target_args=()
        shift
        continue
        ;;
      help|--help|-h)
        if [[ -z "$target_script" ]]; then
          show_help
          return
        fi
        ;;&
      *)
        potential_target_script="${TARGETS_BY_ALIAS[$1]:-}"
        if [[ -n "$potential_target_script" ]]; then
          if [[ -n "$target_script" ]]; then
            stage_target "$target_script" "${target_args[@]}"
          fi
          target_script="$potential_target_script"
          target_args=()
          shift
          continue
        fi
        if [[ -n "$target_script" ]]; then
          target_args+=("$1")
          shift
          continue
        fi
        echo_error "The argument \"$1\" is not a recognized target"
        exit 1
        ;;
    esac
  done
  if [[ -n "$target_script" ]]; then
    stage_target "$target_script" "${target_args[@]}"
  fi
}

# entrypoint of the script
main() {
  : "${SECRETS_ENV_FILE:=.env}"
  load_env_variables "$SECRETS_ENV_FILE"
  interpret_args "$@"
  process_staged_targets
}

### CONFIG ###

TARGET_BASE_PATH='scripts/dev'

declare -A TARGETS_BY_ALIAS=(
  [vaultwarden]='vaultwarden.sh'
  [vw]='vaultwarden.sh'
)

### EXECUTION ###

declare -a ALL_TARGETS=()
declare -A seen_targets=()
for target in "${TARGETS_BY_ALIAS[@]}"; do
  if [[ -z ${seen_targets[$target]+X} ]]; then
    ALL_TARGETS+=("$target")
    seen_targets[$target]=1
  fi
done

test_commands realpath tmux

main "$@"
