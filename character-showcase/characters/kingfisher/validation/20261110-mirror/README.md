# D-20261110-004｜C3 翠鸟水平镜像 作者自测

2026-11-10，06｜程序开发。基线 `origin/main` 3b7a9ad。环境：Windows 11、Godot 4.7.2 stable（console 版）、OpenGL3 Compatibility、AMD Radeon RX 7700 XT，专用 1440×810 窗口，Dummy 音频＋主总线静音。**作者自测，不代替 07 独立验收、05 实际视觉或真人听感。**

## 实现

- `showcase.gd` 新增 `facing`（1＝原向，-1＝镜像），绘制改为围同一世界脚点 (720,441) 的 `Vector2(±0.21, 0.21)` 变换；`source_to_world` 同步。复用同一组 98 张纹理对象、PTS、1 秒 WAV，不新建或复制任何素材。持械侧随镜像换侧。
- 新增“原向 (1)／镜像 (2)”切换按钮与数字键 1/2。切向**只改显示**：不改 elapsed、状态、声音事件或正在播放的 WAV（沿用 2026-11-02 已定“切向保持时间/音频/状态”）；同向再选为空操作。标题显示当前朝向。
- `review_plain_background` 仅供对称取证隐藏棋盘与格线，默认 false，玩家界面无入口。
- 新增 `launch.bat`（由 `bear-forehand-showcase/launch.bat` 改写，保留 GBK 编码）。
- 新增项目级 `.gitattributes`：`*.json -text`。本机 `core.autocrlf=true` 会把冻结 JSON 检出为 CRLF，导致运行时 manifest SHA 校验失败、展示无法启动（原单向版本在本机同样受影响）。仓库内容未变，只让检出保持 LF 原字节。
- `capture.gd`／`realtime_probe.gd` 增加可选 `--facing=mirrored`，默认行为不变；新增 `mirror_symmetry.gd`。
- 101 个素材文件、manifest SHA `fd1ae832…`、`showcase.json` 均未改。

## 结果

| 检查 | 结果 |
|---|---|
| 引擎边界 `tests/test.gd`（源码） | 1182 项 / 0 失败（原 1032 项＋镜像 150 项，含镜像方向重跑整套播放/声音边界） |
| 同上，无 .godot/.import/.uid 冷副本 | 1182 / 0 |
| 同上，经 `launch.bat` 启动 | 1182 / 0 |
| 资源 `verify_assets.py`（源码，候选取自 `git archive` 原字节） | 1210 / 0 |
| 资源（冷副本，无候选对照） | 1108 / 0 |
| 实际图形采样 原向 / 镜像 | 各 9 组 0 错误；脚点均 (720,441)，镜像画布角为原向关于 x=720 的反射 |
| 正常播放 原向 / 镜像 `realtime_probe.gd` | 各 4 段 34 项 0 错误：两次完整播放达 T 停 index97 静音、Ended 不循环、重播清旧声、活跃声音重播、实际退出移除混音 |
| 逐像素对称 `mirror_symmetry.gd`，98 个源索引 | 79 个索引逐位相同；其余 19 个索引共 49 个像素差 1/255（单索引最多 6 像素）。脚本按“全部逐位相同”的严格标准判定，退出码 1 |

对称比较：纯色背景下原向像素 (x,y) 对镜像像素 (1439−x,y)，区域 x 560–879、y 260–499（关于 x=720 对称，覆盖整张变换画布）。几何上两者采样同一源坐标；49 个 ±1/255 像素是 GPU 双线性插值的浮点舍入，不是位置或帧选择错误。每个索引中镜像图与未反射的原图都有 ≥6408 个像素不同，说明确实发生了翻转。门限没有为了通过而放宽，原始数据见 `symmetry/mirror-symmetry.json`。

## 首次失败（保留）

- `logs/test-source.log` 的首次运行（已被覆盖，结论如下）：manifest SHA 校验失败，原因是 CRLF 检出；加 `.gitattributes` 并按 HEAD 原字节恢复 JSON 后通过。
- `assets-source-first-crlf-candidate.json`：`godot-demo/` 下候选 manifest 被检出为 CRLF，因此“候选与运行字节一致”这一项失败（git blob 均为 `e0d60ab1…`，一致）。godot-demo 不在本批范围内，未改动；改为用 `git -c core.autocrlf=false archive` 导出的原字节候选对照，1210/0。

## 文件

- `test-*.json`、`assets-*.json`、`realtime-*.json`、`logs/`。
- `render-original/`：原向回归采样，只保留 capture.json 与角色裁片（与 20261102 已入库的整屏重复，因此删去整屏 PNG，散列保留在 capture.json 中）。
- `render-mirrored/`：镜像 9 组整屏＋裁片。
- `symmetry/`：对称报告；index 0/31/97 两个朝向的棋盘整屏和纯底区域图。

## 未验证

07 独立复验、05 对镜像的实际视觉（持械侧、烘焙飞羽方向、光影方向在镜像下是否可接受）、真人连续观感、设备听感、OS 鼠标点击（按钮由信号触发）、macOS 上重跑。0.21 倍率与 0.405 秒偏移仍是试接参数。
