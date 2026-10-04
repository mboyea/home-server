#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

### DOCUMENTATION ###

# CHANGELOG
# 1.0.0 published on 2026-10-03 by Matthew Boyea
# - User can run one or more targets with zero or more options
# - The special help target is only viable as the first target; otherwise it will be interpreted as an option
# - The special all target will pass its options to every other possible target (excluding the help target)
# - Options passed with the all target are inherited softly; they're placed first in the arg list regardless of position of the all target:
#   > run dev vw --debug all --slim
#   will pass '--slim' to all targets; vw will execute with '--slim --debug'; if these args conflict, '--debug' should take precedence
# - Targets which aren't deemed 'special' are run in a tmux window
# - If a session is already running, this script will skip it

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

# get a safe identifier from a target's filename
get_safe_name_from_file_name() {
  local safe_name="${1##*/}"
  safe_name="${safe_name%.*}"
  safe_name="${safe_name^^}"
  safe_name="${safe_name//[^A-Z0-9_]/_}"
  printf '%s\n' "$safe_name"
}

# get the name of arg array for a target
get_target_arg_array_name() {
  printf 'TARGET_ARGS_%s\n' "$(get_safe_name_from_file_name "$1")"
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

# get the name of the tmux window for a target
get_target_tmux_window_name() {
  get_safe_name_from_file_name "$1"
}

# get whether a tmux window exists
get_does_tmux_window_exist() {
  local session_name="$1"
  local window_name="$2"
  tmux list-windows \
    -t "$session_name" \
    -F '#{window_name}' \
    2>/dev/null \
  | grep -Fxq -- "$window_name"
}

# show user the state of the tmux session ($1) for all valid targets
echo_tmux_session_status() {
  local tmux_session_name="$1"
  # check that the tmux session exists
  if ! tmux has-session -t "$tmux_session_name" 2>/dev/null; then
    echo_error "The tmux session \"$tmux_session_name\" does not exist"
    return
  fi
  # show the status of possible tmux windows
  local target_script
  local target_window_name
  local pane_info
  local pane_dead
  local pane_status
  printf '%-20s %s\n' 'NAME' 'STATUS'
  for target_script in "${ALL_TARGET_SCRIPT_NAMES[@]}"; do
    target_window_name="$(
      get_target_tmux_window_name "$target_script"
    )"
    # handle missing tmux window
    if ! get_does_tmux_window_exist "$tmux_session_name" "$target_window_name"; then
      printf '%-20s %s\n' "$target_window_name" 'not present'
      continue
    fi
    # get tmux window info
    pane_info="$(
      tmux list-panes \
        -t "$tmux_session_name:$target_window_name" \
        -F '#{pane_dead} #{pane_dead_status}'
    )"
    read -r pane_dead pane_status <<< "$pane_info"
    # handle running tmux window
    if [[ "$pane_dead" == '0' ]]; then
      printf '%-20s %s\n' "$target_window_name" 'running'
      continue
    fi
    # handle failed tmux window
    if [[ "$pane_status" != '0' ]]; then
      printf '%-20s %s\n' "$target_window_name" "error $pane_status"
      continue
    fi
    # handle finished tmux window
    printf '%-20s %s\n' "$target_window_name" 'finished'
    continue
  done
}

# expand staged args from 'all' to the other targets; execute script targets in tmux session ($1)
process_staged_targets_tmux() {
  local tmux_session_name="$1"
  local target_script
  # expand staged args from 'all' to the other targets
  local all_target_arg_array_name="${STAGED_TARGET_ARG_ARRAY_NAMES[all]:-}"
  if [[ -n "$all_target_arg_array_name" ]]; then
    local -n all_args_ref="$all_target_arg_array_name"
    # for all targets
    for target_script in "${ALL_TARGET_SCRIPT_NAMES[@]}"; do
      local target_script_arg_array_name="${STAGED_TARGET_ARG_ARRAY_NAMES[$target_script]:-}"
      # stage target if it was not already staged
      if [[ -z "$target_script_arg_array_name" ]]; then
        stage_target "$target_script"
        target_script_arg_array_name="${STAGED_TARGET_ARG_ARRAY_NAMES[$target_script]}"
      fi
      # insert arguments from 'all' into the args list for the target
      local -n target_script_args_ref="$target_script_arg_array_name"
      target_script_args_ref=(
        "${all_args_ref[@]}"
        "${target_script_args_ref[@]}"
      )
      unset -n target_script_args_ref
    done
    # remove 'all' from the staging list
    local target_index
    for target_index in "${!STAGED_TARGETS[@]}"; do
      [[ "${STAGED_TARGETS[$target_index]}" == 'all' ]] && unset "STAGED_TARGETS[$target_index]"
    done
    STAGED_TARGETS=("${STAGED_TARGETS[@]}")
    unset 'STAGED_TARGET_ARG_ARRAY_NAMES[all]'
  fi
  # execute each staged target
  for target_script in "${STAGED_TARGETS[@]}"; do
    local target_arg_array_name="${STAGED_TARGET_ARG_ARRAY_NAMES[$target_script]}"
    if [[ -z "$target_arg_array_name" ]]; then
      echo_error "Could not start script \"$target_script\": no staged argument array could be found"
      continue
    fi
    local target_window_name
    target_window_name="$(
      get_target_tmux_window_name "$target_script"
    )"
    local target_path="$TARGET_BASE_PATH/$target_script"
    # skip when target tmux window already exists
    if get_does_tmux_window_exist "$tmux_session_name" "$target_window_name"; then
      echo_error "Could not start script \"$target_script\": tmux window \"$target_window_name\" already exists"
      continue
    fi
    local target_pane=""
    # generate target window when session already exists
    if tmux has-session -t "$tmux_session_name" 2>/dev/null; then
      if ! target_pane="$(
        tmux new-window \
          -d \
          -P \
          -F '#{pane_id}' \
          -t "$tmux_session_name:" \
          -n "$target_window_name"
      )"; then
        echo_error "Could not start script \"$target_script\": failed to create tmux window \"$target_window_name\" in session \"$tmux_session_name\""
        continue
      fi
    # generate target window when session doesn't exist
    elif ! target_pane="$(
      tmux new-session \
        -d \
        -P \
        -F '#{pane_id}' \
        -s "$tmux_session_name" \
        -n "$target_window_name"
    )"; then
      echo_error "Could not start script \"$target_script\": failed to create tmux session \"$tmux_session_name\""
      continue
    fi
    # set option to preserve the window after its command exits
    if ! tmux set-window-option -t "$target_pane" remain-on-exit on; then
      echo_error "Could not start script \"$target_script\": failed to enable remain-on-exit for tmux window \"$target_window_name\" in session \"$tmux_session_name\""
      continue
    fi
    local -n target_args_ref="$target_arg_array_name"
    # start the script in the target window
    if ! tmux respawn-pane -k -t "$target_pane" -- bash "$target_path" "${target_args_ref[@]}"; then
      unset -n target_args_ref
      echo_error "Could not start script \"$target_script\": failed to run in tmux window \"$target_window_name\" in session \"$tmux_session_name\""
      continue
    fi
    unset -n target_args_ref
    printf 'Target "%s" dispatched in tmux window "%s:%s"\n' \
      "$target_script" \
      "$tmux_session_name" \
      "$target_window_name"
  done
}

# interpret args, distribute args across targets
stage-targets-from-args() {
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
        potential_target_script="${TARGET_SCRIPTS_BY_ALIAS[$1]:-}"
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
  stage-targets-from-args "$@"
  # if no staged targets, skip trying to create tmux session
  [[ "${#STAGED_TARGETS[@]}" -eq 0 ]] && return 0
  process_staged_targets_tmux "$TMUX_SESSION_NAME"
  echo_tmux_session_status "$TMUX_SESSION_NAME"
  return 0
}

### CONFIG ###

TMUX_SESSION_NAME='dev'

TARGET_BASE_PATH='scripts/dev'

declare -A TARGET_SCRIPTS_BY_ALIAS=(
  [vaultwarden]='vaultwarden.sh'
  [vw]='vaultwarden.sh'
)

### EXECUTION ###

declare -a ALL_TARGET_SCRIPT_NAMES=()
declare -A seen_targets=()
for target in "${TARGET_SCRIPTS_BY_ALIAS[@]}"; do
  if [[ -z ${seen_targets[$target]+X} ]]; then
    ALL_TARGET_SCRIPT_NAMES+=("$target")
    seen_targets[$target]=1
  fi
done

test_commands realpath tmux grep

main "$@"
