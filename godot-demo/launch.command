#!/bin/bash
set -eu
project_dir="$(cd -- "$(dirname -- "$0")" && pwd)"
godot_bin="${GODOT_BIN:-}"
if [ -z "$godot_bin" ]; then
  godot_bin="$(command -v godot || true)"
fi
if [ -z "$godot_bin" ]; then
  for candidate in /opt/homebrew/bin/godot /usr/local/bin/godot /Applications/Godot.app/Contents/MacOS/Godot; do
    if [ -x "$candidate" ]; then godot_bin="$candidate"; break; fi
  done
fi
if [ -z "$godot_bin" ] || [ ! -x "$godot_bin" ]; then
  echo '请安装 Godot 4 或设置 GODOT_BIN 为引擎路径。'
  exit 1
fi
exec "$godot_bin" --path "$project_dir" "$@"
