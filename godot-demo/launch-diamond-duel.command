#!/bin/bash
set -eu
project_dir="$(cd -- "$(dirname -- "$0")" && pwd)"
exec "$project_dir/launch.command" --audio-driver Dummy res://scenes/diamond_duel.tscn "$@"
