#!/bin/bash
set -eu
trial_dir="$(cd -- "$(dirname -- "$0")" && pwd)"
renderer_args=()
if [ "$(uname -s)" = Darwin ]; then
  renderer_args=(--rendering-driver metal)
  for trial_arg in "$@"; do
    if [ "$trial_arg" = gl_compatibility ]; then
      renderer_args=(--rendering-driver opengl3)
    fi
  done
fi
if [ -n "${GODOT_BIN:-}" ]; then
  trial_godot="$GODOT_BIN"
elif [ -x /Applications/Godot.app/Contents/MacOS/Godot ]; then
  trial_godot=/Applications/Godot.app/Contents/MacOS/Godot
elif command -v godot >/dev/null 2>&1; then
  trial_godot="$(command -v godot)"
else
  printf '未找到 Godot。请安装 Godot 4，或设置 GODOT_BIN。\n'
  exit 1
fi

# Import caches and extracted GLB textures are local rebuildable outputs, not
# repository dependencies. This makes a fresh clone runnable on another Mac.
"$trial_godot" --headless --editor --import --quit --path "$trial_dir"
exec "$trial_godot" --path "$trial_dir" "${renderer_args[@]}" "$@"
