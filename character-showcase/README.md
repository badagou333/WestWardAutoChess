# 角色攻击展示（character-showcase）

2026-11-10，D-20261110-005。原先三个独立展示 `bear-forehand-showcase/`（熊山君）、`c03-attack-showcase/`（翠鸟）、`b04-attack-showcase/`（药龄童子）合并到这里：一个 Godot 项目，一个启动入口，一套共用播放程序。**本次只做结构整合，没有改素材、参数或玩法。** 合并前后的逐项对比见 [validation/20261110-merge](validation/20261110-merge/README.md)。

## 启动

- Windows：双击 `launch.bat`。可用环境变量 `GODOT_BIN` 指定引擎，设 `GODOT_CONSOLE=1` 改用 console 版看日志。
- macOS：`launch.command`，未在 macOS 实测。
- 启动后先进入角色选择界面，点按钮或按数字键 1–3 进入角色；在角色界面按 Esc 或点“返回选择”回到选择界面。
- 直接进入某个角色：`launch.bat -- --character=bear`，也可以是 `kingfisher` 或 `herb_boy`。

## 各角色的测试控件（与合并前相同）

| 角色 | 模式 | 控件 | 主要参数 |
|---|---|---|---|
| 熊山君 `bear` | 自动循环 | 右前／左前／右后／左后，按钮或 1–4；切方向从头播放并重启该方向原声 | 正面 v3 84 帧 3.0 秒＋0 间隔；背面 v1 340 时刻 3.5417 秒＋0.35 秒间隔；倍率 0.75；左向为镜像 |
| 翠鸟 `kingfisher` | 单次 | 播放／重播；原向 (1)／镜像 (2)，切向只改显示 | 98 帧 PTS（1/90000）；倍率 0.21；0.405 秒起声；末帧 97 |
| 药龄童子 `herb_boy` | 单次 | 播放／重播；单向 | 84 帧可变帧率 PTS（1/15360）；倍率 0.16（提案，待负责人定）；偏移 0；末帧 83；mipmap 开 |

三个角色共用世界脚点 (720,441)。所有参数都在各角色的 `character.json` 里，不写在程序里。

## 目录

```
character-showcase/
  launch.bat  launch.command  project.godot  main.tscn  .gitattributes
  app/app.gd          选择界面：读 characters/index.json，开关角色播放器
  app/player.gd       共用播放程序：按 character.json 加载与播放（loop / one_shot 两种模式）
  shared/forest-board.png   林间棋盘（三份散列相同，只保留这一份）
  characters/index.json     选择界面的角色列表与顺序
  characters/<id>/character.json   角色配置
  characters/<id>/art/…  audio/…   素材（git mv 迁移，字节不变）
  characters/<id>/validation/      该角色合并前的全部历史证据（原样迁移）
  characters/<id>/provenance/      来源记录（翠鸟、药龄童子，原样迁移）
  characters/<id>/legacy/          合并前的 README/HANDOFF 及校验脚本（只作历史，见下）
  tests/   test.gd（引擎检查）capture.gd（实窗截图）realtime_probe.gd（正常播放）baseline.gd（行为指纹）
  tools/   verify_assets.py（素材散列）compare_fingerprints.py（合并前后对比）
  validation/20261110-merge/       本次合并的证据
```

各角色素材目录沿用原有的相对结构：manifest 里的 `frames/…`、`audio/…` 路径不用改。熊山君的 `art/attack`（正面）、`art/back`（背面）、`audio/` 也保留原名，方便与历史证据对照。

## character.json 字段

- 通用字段：`id`、`name`、`title`、`hint`（可选）、`title_shows_direction`（标题后面是否显示当前方向）、`world_foot`、`mipmaps`。
- `mode`：
  - `loop`：自动循环。每轮开始重启原声，切方向从 0 开始。
  - `one_shot`：就绪 → 播放 → 停在末帧。到 `audio_start_seconds` 时起声；如果画面更新被拖延，按当前进度定位声音，不会从头补播。重播会先停掉旧声音。
- `board_style`：
  - `grid`：熊山君的整片淡格线、选中格和投影。
  - `cell`：只画选中格。
- `direction_switch`：`restart` 表示切方向从头播放（熊山君）；`display_only` 表示只改朝向（翠鸟）。
- `clips.<clip>`：
  - `manifest` 与 `manifest_sha256`：运行时校验，不一致就不进入该角色。
  - `audio_sha256`：同样运行时校验；`audio` 只有 loop 模式需要填，one_shot 模式的声音路径取自 manifest。
  - 时间：loop 模式用 manifest 的 `source_time_seconds`，one_shot 模式用 `timing.pts_field` 和 `timing.time_base`。
  - 其余：`media_end_ticks`、`video_duration_seconds`、`loop_interval_seconds`、`display_scale`、`audio_start_seconds`、`canvas_field`、`foot_field`、`source_sign`、`source_back`。
- `directions[]`：`id`、`label`、`button`、`clip`，以及 `sign`（1 为原向，-1 为水平镜像）。

`.gitattributes` 让 `*.json` 按原字节检出（`-text`）。这样 Windows 下 `core.autocrlf=true` 不会改动字节，manifest 散列也就对得上。

## 自测

```bat
launch.bat --headless --audio-driver Dummy --script res://tests/test.gd -- --output=<绝对路径>\test.json
launch.bat --audio-driver Dummy --script res://tests/capture.gd -- --output=<绝对目录>
launch.bat --audio-driver Dummy --script res://tests/realtime_probe.gd -- --output=<绝对路径>\realtime.json
launch.bat --audio-driver Dummy --script res://tests/baseline.gd -- --character=bear --output=<绝对路径>\fp.json
python -I tools\verify_assets.py
```

另外三个参数的含义：

- `test.gd` 可以加 `--character=<id>`，只检查一个角色。
- `capture.gd` 和 `realtime_probe.gd` 需要真实窗口，不能用 headless。
- `baseline.gd` 输出的行为指纹要和 `validation/20261110-merge/baseline/legacy-*.json` 用 `tools/compare_fingerprints.py` 对比。

## 历史与 legacy

合并前各角色的作者与独立验收证据都在 `characters/<id>/validation/`，内容没有改。里面提到的旧路径（如 `bear-forehand-showcase/test.gd`、`art/c03/…`）指的是合并前的结构；要复现当时的命令，请检出 `d19a97f`。

`legacy/` 下的 `verify_front_v2.py`、`verify_front_v3.py`、`verify_assets.py` 绑定旧目录结构，在新结构里不能直接运行。当前的素材校验请用 `tools/verify_assets.py`。

## 已知限制

- 熊山君界面退出时，引擎偶尔提示 “2 ObjectDB instances were leaked at exit”。合并前的熊山君证据也记录过同类退出告警。
- 各角色原有的素材限制与未验项照旧，见各角色的 `legacy/README.md` 和 `validation/`。
