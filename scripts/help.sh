#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

echo 'This is the MTCBPC Home Server Command Line Interface.'
echo
echo 'Usage:'
echo '  nix develop'
echo '  └ Start a subshell with the project dependencies installed; Not needed with direnv enabled'
echo '  run [script] [args...]'
echo '  └ Run a script; This is an alias for "nix run .#[script] [args...]" but with a cache of the derivation output'
echo
echo 'Scripts:'
echo '  help | Print usage information for this software'
echo
