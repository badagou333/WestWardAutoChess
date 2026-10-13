# 狐火小妖 · 待机与单次火焰普攻候选

更新时间：2026-10-13。仅用于独立三维棋盘样板；不改变正式游戏、伤害数值或既有跑步。

## 动作

- `SpellIdle`：3 秒循环。承接已认可的左高右低双火站姿；两脚固定，胸肩轻呼吸，头部与尾巴克制跟随，左右手不同相位轻微控火。
- `FlameAttack`：1.2 秒，**不循环**。左手约 0.20 秒时后收蓄势，0.40 秒向前送出火焰，随后收势；右手持续在腰侧保留火。双脚不挪，根没有水平位移，不跳起、不悬浮、不双手举过头。
- `FlameAttack` 首尾与 `SpellIdle` 的 0 秒姿势一致。程序从任意待机相位进入时仍建议使用短过渡，不代表任意状态无混合即可硬切。
- 预览橙球仅标示已有的每手挂点、体积与发射时刻，不是最终火焰/弹道效果。真正掌火、左火发射后消失/再凝聚及投射物由引擎制作。

## 接入

`spell-animations.json` 直接保存官方 Blender glTF 导出的 **25 骨完整父节点局部 TRS**，四元数为 xyzw，不是 rest-relative 增量。每个动作完整覆盖 translation / rotation / scale；导出器省略的恒定通道从同一 glTF 的骨节点默认 TRS 显式补齐，程序不必继承原 Idle 动作。

- `clips` 中的 `duration`、`loop` 分别控制长度、循环；`FlameAttack.events` 含 `{name:release,time:0.4,hand:L}`。
- 时间已归一到 0，`source_time_offset=1/30` 只记录源 Blender/glTF 第 1 帧的偏移。新动作播放时**不要再减一次**。
- `base_glb_sha256` 对应既有 `../hunyuan_board_actor_v1/foxfire-board-actor.glb`。骨名及层级不变；不要替换模型。
- 坐标仍为 glTF/Godot Y 向上、角色正前方 +Z。每手 `palm_offsets`、`orbs` 与已认可的双火包完全相同，不能改回双手中点。
- 攻击的事件是表现时序，不定义正式攻击频率/冷却/伤害或目标规则。建议由程序阻止单次释放事件在暂停、恢复或尾帧中重复触发。

## 复现与验证

`build_spell.py` 用 Blender 5.2 后台读取既有原工程，并复用已提交 `../hunyuan_dual_fire_v1/build_dual_fire.py` 的骨骼坐标与双火手势函数；只写本目录和 `/private/tmp/foxfire-spell-actions.glb`。没有复制完整模型、贴图或新增大型 `.blend`。

- `-- --preview`：制作真实网格门审姿势，不导出交付 JSON。
- `-- --build --render`：导出完整动作，并渲染门审关键帧。
- `build-report.json`：逐帧根/下半身固定、实际足部顶点、首尾全网格与待机姿势一致性及源动作保留检查。
- PNG 为可重建本地 QA 中间文件，由 `.gitignore` 排除。实际引擎动画、火球与操作入口预览统一保存在 [独立试场](../../../reviews/foxfire-3d-board-v1/README.md)，不再复制大模型或重复预览。

模型、绑定、权重、材质、原 Idle/Run 与现有双火包保持；源动作来源及许可沿用 `hunyuan_board_actor_v1` 的记录。宽袖、无手指骨与尾巴较整体化的既有模型限制仍在；关键帧检查不等于完整实机动画或正式商业成品验收。
