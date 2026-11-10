# 药龄童子正面攻击展示（B4）

2026-11-10，D-20261110-004，06 作者实现。**作者自测，不代替 07 独立验收、05 实际视觉或真人听感。** 作者结果见 [validation/20261110-single](validation/20261110-single/README.md)。

## 使用

Windows 双击 `launch.bat`（可用环境变量 `GODOT_BIN` 指定引擎）；macOS 双击 `launch.command`（未在 macOS 实测）。棋盘上只有一只药龄童子，点“播放”单次播放攻击，结束后停在末帧；“重播”从头开始并停掉旧声音。默认静止在第 0 帧，不自动循环，没有镜像、战斗、治疗或其他角色。

## 素材

来自 05 交付 `180acf2`，目录 `godot-demo/art/candidates/b04_herb_boy_attack_v1/`：84 张 PNG、`manifest.json`、`audio/b04-attack-original.wav` 原字节复制到 `art/b04/`；林间棋盘从 `bear-forehand-showcase/art/forest-board.png` 原字节复制。共 87 个文件，逐文件来源和散列见 [provenance/resource-list.json](provenance/resource-list.json)。没有改帧、调音、渐隐或重新编码。

- manifest SHA-256 `cefc1cec66ffdf3c0df817dd050f191a1dc96bf16b683e062e806e829d5afa84`（运行时校验，不一致则不启动）
- WAV SHA-256 `66ee72af663a0c2eecdd4c7c6817b149cb3b232227ae337e3b85a2333b7d3418`
- 棋盘 SHA-256 `7b568eb54ad25d18efa7dab24adcce833a4528940fdd615ca053196cd6ad1ed6`
- `.gitattributes` 让 JSON 按原字节检出（Windows `core.autocrlf=true` 下不被改成 CRLF）。

## 播放规则

- 帧：按 manifest 的 `pts`（时基 1/15360）查表，半开区间 `[pts, 下一帧pts)`；间隔 768/512 tick（0.05/0.0333 秒）交替，**不按固定 FPS**。末帧 83 从 53248 显示到 T=53760（3.5 秒）；到 T 后进入“播放结束”，静止显示 index 83。
- 声音：原 WAV 3.5 秒，与第 0 帧同时开始（偏移 0），单个播放器。按下播放的那一刻就从 0 开始；如果首帧更新被拖延，按当前进度定位，不会从头补播。到 T 时与画面一起停止。重播先停旧声音再从 0 开始。退出时停声。
- 构图：画布 864×760，脚锚 [303,684] 对准世界脚点 (720,441)，统一缩放，不逐帧锁脚。

## 可调配置（`showcase.json`）

- `presentation.display_scale`：**0.16 为 05 提案，待负责人确认**，直接改这个数即可。
- `presentation.mipmaps`：默认 `true`。0.16 是把 864 像素宽的画布缩到约 138 像素，开 mipmap 可以减少缩小时的闪烁和锯齿；代价是显存多约三分之一（84 张满分辨率纹理约 220 MB，加 mipmap 约 290 MB）。如果 05 认为观感不对，可以改成 `false` 对照。
- `presentation.world_foot`、`audio.start_seconds` 也在这里，后者按交接保持 0。

## 已知素材限制（沿用 05 交接，本批不处理）

第 35～37 帧光球超出原片右边缘，画面中会被竖直切断；绿色辉光在深底上像淡雾；轮廓局部浅边；末帧与首帧不保证无缝。详见候选目录的 HANDOFF.md。

## 复现

```bat
launch.bat --headless --audio-driver Dummy --script res://tests/test.gd -- --output=<绝对路径>\test.json
launch.bat --audio-driver Dummy --script res://capture.gd -- --output=<绝对路径>\render
launch.bat --audio-driver Dummy --script res://realtime_probe.gd -- --output=<绝对路径>\realtime.json
```
