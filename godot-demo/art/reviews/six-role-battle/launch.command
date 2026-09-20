#!/bin/bash
set -eu
trial_dir="$(cd -- "$(dirname -- "$0")" && pwd)"
project_dir="$(cd -- "$trial_dir/../../.." && pwd)"
godot_bin="${GODOT_BIN:-}"
if [ -z "$godot_bin" ]; then
  godot_bin="$(command -v godot || true)"
fi
if [ -z "$godot_bin" ]; then
  for candidate in /opt/homebrew/bin/godot /usr/local/bin/godot /Applications/Godot.app/Contents/MacOS/Godot; do
    if [ -x "$candidate" ]; then
      godot_bin="$candidate"
      break
    fi
  done
fi
if [ -z "$godot_bin" ] || [ ! -x "$godot_bin" ]; then
  echo '找不到 Godot。请安装 Godot 4，或将 GODOT_BIN 设为可执行文件的完整路径。'
  read -r -p '按回车关闭。' reply
  exit 1
fi
exec "$godot_bin" --path "$project_dir" res://art/reviews/six-role-battle/battle.tscn "$@"
