# 护寺棍僧八帧迈步候选

更新时间：2026-09-15。仅用于独立六角色美术试玩，不替换正式概念图、demo_v1 或主 Demo。

## 本批内容

在 motion_v2 的 12 帧之后追加 8 张迈步图，图集共 20 格、5120×256。旧 12 格像素、普攻时序及待机第 11 格保持不变。移动播放 `11 → 12…19 → 11`，起步与到达沿用同一准备姿势；移动时长、走格路径、受击处理与战斗结算未变。六角色累计新增姿势由 60 张增至 68 张。

`walk_contact_a` 至 `walk_up_b` 是目标步态阶段的工作命名，不代表每张已准确达到标准步态。两侧抬脚已能区分，但摆腿前后距离不均、脚底仍有滑移，衣纹和准备姿势之间存在跳变；不能标为完整物理步态或正式方向动画。左右朝向仍是镜像，不是两套独立绘制。

## 来源与加工

本批由内置图像生成工具绘制，参考 motion_v2 的站稳/收势角色。原始候选为 RGB 棋盘底，并非真实透明。`source-two-leg-repair.png` 保留双侧抬脚修正，`source-pass-repair.png` 保留经过身体下方的摆腿修正。最后一次整图编辑同时改坏了后一格，因此只选其中上排第三格，其余七格来自前一版；选区、缩放和脚点保存在 `../../tools/build_monk_walk.py`。

`generated-walk-sheet.png` 是可重建的拼选源图；八张单帧 PNG 和 `body-atlas.png` 是清底后的 RGBA 输出。所有格共用 256×256 画布与 `(128,218)` 脚底锚点、统一比例；不逐帧缩放角色。`manifest.json` 保存源哈希、旧图集哈希、选框和脚点。`walk-contact.png` 用深浅底检查边缘。

提示词目标与修改经过见 `PROMPT.md`。旧版资产原位保留；当前默认试接 motion_v3，M 开关回到早期单姿势包，而专用步态对比才是 v2 与 v3 的比较。

## 验证

- 静态：20 格与单帧一致、旧 12 格逐像素保持、源图及成品边界未裁断、脚点位于实体脚掌、两侧抬脚标注检查通过。标注检查不等于无滑步。
- 动态：八张新图均实际播放；两朝向连续三次走格、移动中受击不中断、精确到达、到达与下一次攻击的准备帧一致，通过专项测试。
- 战斗：六角色专项零失败；30/60/120 FPS 均为 20.70 秒，事件计数与上一版相同。原冒烟及四波回归通过（47.7 秒，唐僧 300/300，战利品 20）。
- 实机：已导出并检查半速新旧对比采样，两侧抬脚更明确；不以测试通过代替视觉验收。仍需精修脚底锁定、摆腿幅度与新旧姿势衔接。

对比：`../../../reviews/six-role-battle/frame-comparison-monk-walk.gif`，左 v2 四帧、右 v3 八帧，半速，两次向右、一次向左。该动图为 Godot 实际渲染，不是静态棋盘拼图。

## 重建

在仓库根运行（Python 需 Pillow、NumPy）：

```text
python3 godot-demo/art/production/tools/build_monk_walk.py
python3 godot-demo/art/production/tools/verify_monk_walk.py
godot --headless --path godot-demo --script res://art/reviews/six-role-battle/verify.gd
godot --path godot-demo --rendering-method gl_compatibility --resolution 960x320 --script res://art/reviews/six-role-battle/render_frame_comparison.gd -- --monk-walk
python3 godot-demo/art/reviews/six-role-battle/pack_frame_comparison.py --monk-walk
```
