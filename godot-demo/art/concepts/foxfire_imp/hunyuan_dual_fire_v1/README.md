# 狐火小妖 · 双手独立控火候选

更新时间：2026-10-13。独立试场候选，未替换正式游戏资产；不是攻击动画。

## 设计与范围

- 左手较高、较前；右手较低、较后，两手在身体左右侧分开。手掌轻微内翻，肩部不耸起，肘部自然弯曲。
- 每手各一团独立火焰。Blender 预览中的橙球只标示挂点和体积，**不是最终火焰**；真正火焰由引擎特效制作。
- 沿用 `../hunyuan_board_actor_v1/foxfire-board-actor.blend` 的原网格、权重、25 骨架、材质和贴图。只替换两侧 upper_arm、forearm、hand 共 6 根骨的动作。
- 原腿部、root、躯干和尾巴曲线逐项保持。原有站立和奔跑不改为漂浮。双臂加入克制的不同相位微动，不焊死在躯干上。
- 不复制大型模型或 Blender 工程，不修改旧的双手共托球草稿。

## 接入约定

`dual-fire-animations.json` 是官方 Blender glTF 导出器输出的骨骼父节点局部 TRS 曲线，不是 rest-relative 四元数。四元数顺序为 **xyzw**，模型单位约 1 米高，glTF / Godot **Y 向上、+Z 为角色正前方**。

1. 复制原 `Idle` / `Run`，将原动画时间从 1/30 秒开始归一到 0，再替换 JSON 指定的 6 根臂骨轨道。
2. 保留全部非臂骨轨道，不能只播放这里的 6 根骨。`source_time_offset=1/30` 是原 Blender/glTF 动画的帧 1 偏移。
3. 新动作 `DualFireIdle` 为 3 秒；`DualFireRun` 为 2/3 秒，均含首尾闭合关键帧。试场原有 Run 播放速度 0.65 由程序继续控制。
4. `palm_offsets.L/R.position` 是各自 `hand.L/R` 骨局部位置，不是模型轴方向。先由对应骨 pose 变换到模型空间，再加 `orbs.L/R.up_offset` 沿模型上方向的偏移；最后由 actor 变换到世界。只应用一次 actor 缩放。
5. `orbs` 的距离和半径都是**模型单位**。两团火中心分别来自各自的手，不得重新取双手中点。现演员缩放 1.65 时，左右核心半径约为 0.078 / 0.069 世界单位。引擎火焰外层可稍大，但须保持手爪与脸部可见。

## 复现与检验

用 Blender 5.2 的独立后台进程运行 `build_dual_fire.py -- --preview` 可复现正面、侧面姿势门审；`-- --build --render` 会重新导出轻量 JSON 并渲染 Idle/Run 的关键姿势。脚本不会保存或覆盖源 `.blend`。

中间官方 glTF 仅含骨架和动作，暂存 `/private/tmp/foxfire-dual-fire-actions.glb`；没有模型和贴图副本。保留的 JSON 足以让现有模型播放，不依赖该临时文件。

`build-report.json` 记录逐帧计算后的循环闭合、非臂骨曲线一致性、双手距离、高低差、掌心法线和手腕转折范围。视觉审查仍须结合棋盘相机下的真正火焰，数值报告不代替美术验收。

仓库只保留 `pose-front.jpg` / `pose-side.jpg` 两张轻量姿势参考。完整 PNG 关键帧是可重建的本地中间产物，由本目录 `.gitignore` 排除；不要将它们全部加入远端仓库。

原 Idle/Run 来源及许可证沿用 `hunyuan_board_actor_v1`、`hunyuan_run_v2` 的记录；本次只有原创手臂姿势修订。游戏参考只用于理解上身姿势，不包含参考游戏模型或动画数据。
