#!/bin/bash
set -eu
project_dir="$(cd -- "$(dirname -- "$0")" && pwd)"
exec "$project_dir/launch.command" res://scenes/board_trial_legacy.tscn "$@"
