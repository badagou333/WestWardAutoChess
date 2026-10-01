#!/bin/bash
set -eu
project_dir="$(cd -- "$(dirname -- "$0")" && pwd)"
exec "$project_dir/launch.command" res://scenes/free_escort.tscn "$@"
