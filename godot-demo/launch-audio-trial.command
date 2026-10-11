#!/bin/bash
set -eu
trial_project_dir="$(cd -- "$(dirname -- "$0")" && pwd)"
exec "$trial_project_dir/launch.command" res://scenes/audio_trial.tscn "$@"
