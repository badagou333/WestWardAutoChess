# 熊山君右前正手：独立试验

双击 `launch-bear-forehand-trial.command` 打开专用棋盘，点击“开始战斗”。默认站位让熊向画面右侧的目标攻击；只在右前向攻击中使用新帧，其他方向与动作仍使用原画。普通游戏入口未替换。素材缺失时会显示提示并回退原动作。

这是有限试验，尚未通过视觉验收。源视频第 52、53 帧的棍头出画，因此已跳过，挥击有跳帧；试验第 10–12 帧有白边与灰脚；原来的大挥击弧已移除；新攻击与旧待机的熊在皮毛、护甲和姿态上有明显差异。固定脚锚和显示尺寸仅供试验，需结合连续播放评估。

程序沿用原伤害、冷却和攻击声音；原命中时钟为 0.389 秒，对应新动作第 12 帧（索引 11），这不等于已确认视觉打击点。暂停、倍速和重试可用于检查节奏。已验证独立 PCK；这是资源包，不是可独立运行的安装包或 Windows 发行版。

需要重新采集真实画面时，在项目根目录运行：

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path godot-demo --rendering-method gl_compatibility --script res://tests/board_bear_forehand_capture.gd
```

采集会打开专用 Godot 窗口，完成后自动退出；四张画面与 `capture.json` 默认写入 `/tmp/board-bear-forehand-render/`。这是单帧记录，不代替连续观感或真实声音试听。

构建独立资源包可使用 `Godot --headless --path godot-demo --export-pack 'Bear Forehand Trial PCK' /tmp/bear-forehand-trial.pck`。新预设只为此包指定试验入口，原工程和旧预设的默认入口保持不变。包内复核应以空目录为当前目录和 `--path`，使用 `--main-pack` 与此项目测试脚本的绝对路径，显式传 `--expect-packed` 和源码生成的 `--compare` 证据；不可从源码目录加载资源后冒充包内通过。

在项目根目录，以下命令可生成源码证据并从独立空目录检查资源包：

```sh
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
"$GODOT_BIN" --headless --path godot-demo --script res://tests/board_bear_forehand_trial_test.gd -- --evidence=/tmp/bear-source.json
"$GODOT_BIN" --headless --path godot-demo --export-pack 'Bear Forehand Trial PCK' /tmp/bear-forehand-trial.pck
python3 scripts/inspect_godot_pck.py /tmp/bear-forehand-trial.pck --release-policy --usage noncommercial
trial_test="$PWD/godot-demo/tests/board_bear_forehand_trial_test.gd"
trial_empty="$(mktemp -d /tmp/bear-forehand-empty.XXXXXX)"
cd "$trial_empty"
"$GODOT_BIN" --headless --path "$trial_empty" --main-pack /tmp/bear-forehand-trial.pck --script "$trial_test" -- --expect-packed --compare=/tmp/bear-source.json
```
