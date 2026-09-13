# 六角色棋盘试战斗

更新时间：2026-09-13；职责：05｜美术试接入。

## 打开与操作

Windows 双击本目录 **`launch.cmd`**。它查找 `GODOT_BIN`、PATH 中的 Godot，或本机 `C:/software/Godot*` 下的 Godot，然后启动 `battle.tscn`。本机使用 Godot 4.7.2；换机器找不到时，可在 Godot 编辑器中打开该场景并按 F6。

- 开始/重开：恢复五名初始英雄与熊山君，立即进行单场试战斗。
- 暂停/继续：暂停角色姿势、移动、待命攻击和飞行投射物；空格同效。
- 1×/2×：整个测试时钟一起变速。
- 退场检查：六名角色同时播放保持和淡出，用于检查通常不会阵亡的后排。
- 显示落脚点：开关青色十字，重开保留开关状态。
- R：重开。
- 补帧开关 / M：对比新增肢体帧与上一轮原姿势版本；重开保留当前选择。
- 角色名称：默认关闭，保留血条；需要辨认角色时打开。减少姓名牌遮住相邻角色的动作，重开保留选择。

这是独立美术测试场景。原主场景、商店、四波流程和正式数据没有替换；测试从真实 Godot 棋盘走格与战斗开始，不是浏览器摆图。

## 2026-09-13 山雀展翼施法过渡

同日山雀续轮：新增 8 张展翼/释放/收翼姿势并默认接入 motion_v1，改善旧准备、腾空出手和站立之间的跳变。既有单枚风刃从新标注的羽尖发射；身体不含重复风刃，也不添加火焰。六角色现合计 60 张新增姿势，三近战有收势、三施法角色有短序列；不是完整双步或全方向动画。详情见 `../../production/sparrow_spirit/motion_v1/README.md`。

新增 `frame-comparison-sparrow.gif` 与采样图，半速左旧右新；更新正常速度实战 GIF、三张棋盘截图、验证 JSON。八帧覆盖、左右羽尖发射、抵达仅伤害一次、末收势/待机/起手同帧通过；六角色专项及原冒烟/四波回归通过，30/60/120 FPS 仍均 20.70 秒且事件计数与上一版相同。深浅底、实机对比与战斗采样完成复核；羽片/头冠细节和旧移动/受击/退场衔接仍待精修。

## 2026-09-13 药灵童子施法过渡

药灵新增 8 张连续施法姿势并接入试玩：抬手、聚力、伸掌释放、收手回待机。施法期间药杖持续立稳，结束与下一次起手共用准备图；逐帧掌心坐标驱动既有治疗光团，原事件时序、治疗量及飞行时间保持。五名角色累计有 52 张新增姿势，山雀仍待补帧。候选来源、加工和限制见 `../../production/herbal_spirit_child/motion_v1/README.md`。

新增 `frame-comparison-herbal.gif` 与采样图，0.5× 左旧单姿势/右新序列；正常速度实战 GIF、三张棋盘截图和验证 JSON 已更新。8 帧覆盖、两朝向掌心发射、抵达仅治疗一次、末收势/待机/起手同图通过；30/60/120 FPS 均 20.70 秒、事件计数与上一版相同，原冒烟/四波回归通过。深浅底、半速及实战采样已复核。新旧衣纹和旧移动/受击/退场衔接仍需精修，候选不代表正式造型验收。

## 2026-09-12 熊山君收棒续轮

熊山君新增 4 张收棒/站稳姿势，默认 motion_v2 共 12 格。命中后双手持续握棒并收至腰前低持，末收势/待机/起手共用第 11 格，改善旧版本突然扛棒上肩的问题；原 8 格像素及原素材包保持。四名角色累计新增 44 张姿势，三名近战均有连续收势。详见 `../../production/bear_lord/motion_v2/README.md`。

新增 `frame-comparison-bear-recovery.gif` 与采样图，0.5× 左 motion_v1 / 右 v2；针对熊山君较长的攻击只捕获一次完整出手，避免第二次起手截断收势。专项播放覆盖、两朝向收势边界与命中同步通过；六角色 30/60/120 FPS 仍均 20.70 秒且事件计数一致，原冒烟/四波回归通过。深浅底、半速实际渲染及更新后的正常速度实战采样已复核，握点/棒长和新旧受击衔接仍待精修。

## 2026-09-12 猎户收刀续轮

猎户新增 4 张收刀/站稳姿势并默认载入 motion_v2，共 12 格，前 8 格像素不变。修正候选首格换持刀手的问题；命中后接连续回收，最后收势、待机与下一次起手同图，改善原待机切入时脸、刀和尾巴的朝向突变。详情见 `../../production/wild_hunter/motion_v2/README.md`。

新增 `frame-comparison-hunter-recovery.gif` 与采样图，0.5× 左 motion_v1 / 右 v2；正常速度实战 GIF 与三张棋盘截图已更新。两朝向收势边界、播放覆盖和命中同步通过，六角色专项无失败，30/60/120 FPS 均 20.70 秒且事件计数一致；原冒烟/四波回归通过。公共打包函数在临时目录重建棍僧，验证其输出像素与清单未改变。当前四名角色累计新增 40 张姿势，仍为待验收候选。

## 2026-09-11 实际肢体补帧

收势续轮：棍僧新增 4 张回收/站稳图，默认载入 `motion_v2`（共 12 格，前 8 格保留）。命中直接衔接新回收序列，末收势、待机和下次起手共用站稳图；旧收势导致的“先缩回再伸出”已在慢速复核后移除。站起过程保持脚底支点。两朝向结束边界和下一次起手检查通过，时长/计数仍与此前相同。新增 `frame-comparison-monk-recovery.gif`，0.5× 左 motion_v1 / 右 v2；不是与最初单姿势包对比。详情见 `../../production/guard_monk/motion_v2/README.md`。

续轮：狐火新增 8 帧准备/蓄力/释放/收手序列，当前共 4 名角色、32 张新增姿势。新待机到施法的尾巴保持在同一侧，逐帧手部坐标控制蓄力火焰与释放位置，左右朝向均通过检查；药灵和山雀仍沿用旧姿势。新图与旧移动/受击/退场的细节衔接仍待进一步精修。详见 `../../production/foxfire_imp/motion_v1/README.md`。

新增 `frame-comparison-foxfire.gif` 及采样图；实战动图与三张棋盘截图已更新。验证后发现姓名牌遮挡动作，已增加“角色名称”开关并默认隐藏姓名、保留血条。专项播放覆盖现在包括狐火全部 8 帧；战斗仍为 20.70 秒，帧率一致性与原两项回归通过。

首轮：棍僧、猎户、熊山君各增加 4 张移动和 4 张攻击姿势，共 24 张新绘制帧，位于各自 `production/<角色>/motion_v1/`。已清理生成图的棋盘底、统一脚底对齐，并接入试玩。新帧默认为开，M 可即时对比。

移动依次播放四帧并减少额外弹跳；普攻依次经过蓄力、加速、命中、收势，最伸展的命中帧与伤害释放同步。待机、受击、退场继续用原包。新帧不混叠旧图集的武器轨迹。素材来源、重建和限制见 `../../production/melee-motion-v1.md`。

验证：三角色 24 帧均进入实际播放，命中图不会提前，释放时刻一致，开关恢复原图集且重开保留选择；六角色专项无失败，30/60/120 FPS 时长/事件计数仍一致，原冒烟/四波回归通过。深浅底与实际连续画面采样已复核。此为动作候选，用户最终观感尚待确认。

新增 `frame-comparison.gif`（4 秒，左旧右新），更新 `motion-preview.gif`（8 秒实战），均为真实 Godot 渲染、24 帧/秒。比较两列只改变补帧开关，动作时序一致。新增对比渲染与打包工具，并更新三张棋盘截图。

## 2026-09-10 动作优化（上一轮）

- 增加每角色独立的蓄力、出手、收势和步伐配置（`motion.gd`）。猎户快、熊山君慢，棍僧较稳；远程施法先准备再发射。
- 在脚底支点上增加待机呼吸、步伐起伏/落地缓冲、近战前探/回位；阴影随前探移动、随离地高度缩小。角色不再全部同步呼吸/出手。
- 普通受击仍扣血，攻击和移动时改用短促震动/闪光，不重置当前动作；待机时保留受击姿势，重复受击不延长锁定。死亡始终进入退场。此规则仅作用于美术试验场景。
- 出手和伤害事件共用角色动作时钟，发射点通过当前绘制变换计算；近战命中带 35 毫秒短暂停顿，死亡目标仍安全取消。内部计算步长不超过 1/120 秒，避免倍速跳过发射时刻。
- 新增 `motion-preview.gif`：8 秒真实 Godot 连续渲染，压缩为 12 帧/秒供快速复核；实际试玩按显示帧率绘制。`render_motion.gd` 与 `pack_motion_preview.py` 可复现。

当轮未重绘原画、未增加肢体中间帧。2026-09-11 已补入三名近战角色的短序列；完整双步循环与方向衔接仍待精修。

## 本批接入

- 继承现有 `scripts/game.gd`，复用 5×7 棋盘坐标、阻挡、有限追击与寻敌函数。
- 五名初始英雄对战熊山君 Boss。药灵童子优先治疗受伤队友或唐僧，无受伤目标时待机。
- 载入六角色现有 manifest、身体图集和独立效果；兼容棍僧早期清单格式。保留 256 帧格与 `(128,218)` 原锚点，身体落在格中心下方 35 像素，逻辑缩放为 1。
- 姿势覆盖待机、移动、普攻、受击、退场。按实际插值中的落脚点纵坐标排序，唐僧加入同一排序体系。
- 朝向翻转围绕脚底锚点；同帧效果和发射位置随身体翻转，飞行效果朝向目标。独立飞弹发射时关闭同帧飞弹。
- 普攻准备后生成伤害事件；远程飞行抵达目标才结算，目标死亡后清理投射物。治疗同样在抵达时生效。命中用通用圆环占位。
- 普通受击不中断攻击、命中短暂停顿、固定 0.25 秒飞行和各角色属性都仅是本测试场景的提案。未实现或确认正式技能、正式战斗平衡、方向动画和目标追踪规则。

## 验证与发现

`validation.json`：默认阵型 20.70 秒结束，唐僧存活，六角色均有实际攻击/治疗动作。记录 109 次攻击请求、54 次投射物发射、88 次伤害命中、18 次治疗、2 次取消；具体事件见 JSON。

- 2026-09-10 新增检查通过：30/60/120 FPS 的战斗时长和事件计数一致，移动准确落回目标点，完整攻击后回到脚底支点，普通受击不重置攻击，重复受击不锁死姿势，绘制发射点与飞弹初始位置一致，每次攻击只结算一次。
- 自动测试通过：六角色加载、单场胜利、脚底排序、暂停冻结、施法时不立即扣血、单枚飞弹与抵达伤害、死亡目标清理、六角色五状态及完整淡出。
- 主 Demo 回归：`SMOKE_TEST_OK`，`FULL_BATTLE_TEST_OK`；旧默认阵容 47.7 秒完成四波，唐僧 300/300，战利品 20。
- 已通过实际 OpenGL 渲染导出开场、6.2 秒交战和退场截图，并逐张复核。截图不是浏览器模拟画布。
- 六角色尺寸可放入当前格子，棍僧/狐火已清理的白底未再出现；近战接触和前后排序可观察。
- **仍待改善**：暗色手绘角色与明亮棋盘/唐僧占位图差异明显；猎户、药灵的小尺寸细节偏密；姓名默认隐藏已改善遮挡，但相邻血条与角色本身仍可能重叠。
- **未验收**：三名近战已加连续收势，狐火、药灵和山雀各有八帧施法序列。新旧图细节衔接、左右腿交替幅度、方向动画和武器端点仍需精修。测试通过不等于已完成正式动画或全部阵型遮挡验收。
- 受限运行环境有系统证书/着色器缓存告警，未影响本地 PNG 读取、测试或 OpenGL 截图。本轮没有浏览器自动访问。

## 复现

在仓库根运行，使用本机 Godot 可执行文件代替 `godot`：

```text
godot --path godot-demo res://art/reviews/six-role-battle/battle.tscn
godot --headless --path godot-demo --script res://art/reviews/six-role-battle/verify.gd
godot --path godot-demo --rendering-method gl_compatibility --script res://art/reviews/six-role-battle/render.gd
godot --path godot-demo --rendering-method gl_compatibility --resolution 1440x810 --script res://art/reviews/six-role-battle/render_motion.gd
python godot-demo/art/reviews/six-role-battle/pack_motion_preview.py
godot --path godot-demo --rendering-method gl_compatibility --resolution 960x800 --script res://art/reviews/six-role-battle/render_frame_comparison.gd
python godot-demo/art/reviews/six-role-battle/pack_frame_comparison.py
godot --path godot-demo --rendering-method gl_compatibility --resolution 960x320 --script res://art/reviews/six-role-battle/render_frame_comparison.gd -- --foxfire
python godot-demo/art/reviews/six-role-battle/pack_frame_comparison.py --foxfire
godot --path godot-demo --rendering-method gl_compatibility --resolution 960x320 --script res://art/reviews/six-role-battle/render_frame_comparison.gd -- --monk-recovery
python godot-demo/art/reviews/six-role-battle/pack_frame_comparison.py --monk-recovery
godot --path godot-demo --rendering-method gl_compatibility --resolution 960x320 --script res://art/reviews/six-role-battle/render_frame_comparison.gd -- --hunter-recovery
python godot-demo/art/reviews/six-role-battle/pack_frame_comparison.py --hunter-recovery
godot --path godot-demo --rendering-method gl_compatibility --resolution 960x320 --script res://art/reviews/six-role-battle/render_frame_comparison.gd -- --bear-recovery
python godot-demo/art/reviews/six-role-battle/pack_frame_comparison.py --bear-recovery
godot --path godot-demo --rendering-method gl_compatibility --resolution 960x320 --script res://art/reviews/six-role-battle/render_frame_comparison.gd -- --herbal
python godot-demo/art/reviews/six-role-battle/pack_frame_comparison.py --herbal
python godot-demo/art/production/tools/verify_herbal_motion.py
godot --path godot-demo --rendering-method gl_compatibility --resolution 960x320 --script res://art/reviews/six-role-battle/render_frame_comparison.gd -- --sparrow
python godot-demo/art/reviews/six-role-battle/pack_frame_comparison.py --sparrow
python godot-demo/art/production/tools/verify_sparrow_motion.py
```

截图：`board-start.png`、`board-combat.png`、`board-retreat.png`；对比采样：`frame-comparison-contact.png` 及各角色专项采样图。原概念图和 `demo_v1` 保留，新资产单独放在 `motion_v1` / `motion_v2`。下一步完善完整双步循环与新旧动作衔接，由 06 评估正式整合。
