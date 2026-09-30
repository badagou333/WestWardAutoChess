#!/bin/sh
set -eu

VERSION="${1:-0.2.0-playtest.1}"
case "$VERSION" in
  *[!0-9A-Za-z.-]*|'')
    echo "版本号只能包含字母、数字、点和连字符：$VERSION" >&2
    exit 2
    ;;
esac

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
PROJECT_DIR="$ROOT_DIR/godot-demo"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/build/windows}"
GODOT_BIN="${GODOT_BIN:-godot}"
PRESET="Windows x86_64 Release"
PACKAGE_NAME="西游护送-${VERSION}-windows-x86_64"
ZIP_PATH="$OUTPUT_DIR/${PACKAGE_NAME}.zip"

if ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
  echo "找不到 Godot：$GODOT_BIN" >&2
  exit 1
fi

GODOT_VERSION=$($GODOT_BIN --version | tr -d '\r')
case "$GODOT_VERSION" in
  4.7.2.*) ;;
  *)
    echo "需要 Godot 4.7.2，当前为：$GODOT_VERSION" >&2
    exit 1
    ;;
esac

if [ "${ALLOW_DIRTY:-0}" != "1" ]; then
  if ! git -C "$ROOT_DIR" diff --quiet || ! git -C "$ROOT_DIR" diff --cached --quiet || [ -n "$(git -C "$ROOT_DIR" status --porcelain --untracked-files=normal)" ]; then
    echo "发布构建要求干净工作区；临时验证可显式设置 ALLOW_DIRTY=1。" >&2
    exit 1
  fi
fi

SOURCE_COMMIT=$(git -C "$ROOT_DIR" rev-parse HEAD)
BUILD_UTC=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/journey-escort-win.XXXXXX")
trap 'rm -rf "$TEMP_DIR"' EXIT HUP INT TERM
STAGE_DIR="$TEMP_DIR/$PACKAGE_NAME"
mkdir -p "$STAGE_DIR" "$OUTPUT_DIR"

echo "使用 $GODOT_VERSION 导出 Windows x86_64 Release..."
"$GODOT_BIN" --headless --path "$PROJECT_DIR" --export-release "$PRESET" "$STAGE_DIR/JourneyEscort.exe" --log-file "$TEMP_DIR/export.log"

test -f "$STAGE_DIR/JourneyEscort.exe"
test -f "$STAGE_DIR/JourneyEscort.pck"
file "$STAGE_DIR/JourneyEscort.exe" | grep -q 'PE32+ executable.*x86-64'
python3 "$SCRIPT_DIR/inspect_godot_pck.py" "$STAGE_DIR/JourneyEscort.pck" --release-policy --output "$TEMP_DIR/pck-files.txt"

PCK_SMOKE_OUTPUT="$TEMP_DIR/pck-smoke.stdout"
"$GODOT_BIN" --headless --main-pack "$STAGE_DIR/JourneyEscort.pck" --quit-after 3 --log-file "$TEMP_DIR/pck-smoke.log" >"$PCK_SMOKE_OUTPUT" 2>&1
if grep -E -q 'SCRIPT ERROR:|Parse Error:|Failed to load script|does not exist|Invalid call|Invalid get index' "$PCK_SMOKE_OUTPUT" "$TEMP_DIR/pck-smoke.log"; then
  echo "导出 PCK 启动检查失败：" >&2
  cat "$PCK_SMOKE_OUTPUT" >&2
  exit 1
fi

cp "$PROJECT_DIR/release/windows/试玩说明.txt" "$STAGE_DIR/"
cp "$PROJECT_DIR/release/windows/已知限制.txt" "$STAGE_DIR/"
cp "$PROJECT_DIR/release/windows/反馈模板.txt" "$STAGE_DIR/"
cp "$PROJECT_DIR/release/windows/GODOT_ENGINE_LICENSE.txt" "$STAGE_DIR/"
cp "$PROJECT_DIR/CREDITS.md" "$STAGE_DIR/第三方音频署名.md"
cp "$PROJECT_DIR/audio/candidates/foxfire-dwoboyle-v1/ATTRIBUTION.md" "$STAGE_DIR/第三方音频完整声明.md"

(
  cd "$STAGE_DIR"
  shasum -a 256 JourneyEscort.exe JourneyEscort.pck > SHA256SUMS.txt
)

{
  echo "西游护送 Windows 试玩包"
  echo "版本：$VERSION"
  echo "平台：Windows x86_64"
  echo "构建类型：Godot Release（Compatibility 渲染）"
  echo "Godot：$GODOT_VERSION"
  echo "源提交：$SOURCE_COMMIT"
  echo "构建时间（UTC）：$BUILD_UTC"
  echo "Windows 实机状态：待验证"
  echo
  echo "EXE 与 PCK 校验值见 SHA256SUMS.txt；整个 ZIP 的校验值见 ZIP 同目录的 .sha256 文件。"
} > "$STAGE_DIR/版本信息.txt"

ZIP_TEMP="$TEMP_DIR/${PACKAGE_NAME}.zip"
(
  cd "$TEMP_DIR"
  zip -X -9 -r "$ZIP_TEMP" "$PACKAGE_NAME" >/dev/null
)
unzip -t "$ZIP_TEMP" >/dev/null
mv -f "$ZIP_TEMP" "$ZIP_PATH"
(
  cd "$OUTPUT_DIR"
  shasum -a 256 "$(basename "$ZIP_PATH")" > "$(basename "$ZIP_PATH").sha256"
)

echo "BUILD_OK"
echo "ZIP=$ZIP_PATH"
echo "SHA256=$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')"
