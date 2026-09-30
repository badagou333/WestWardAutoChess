# 西游护送 · 四波试玩

主入口现已接通五名初始英雄的商店、候选区、布阵、自动合成和四波战斗，末波是熊山君。主 Demo 与独立六角色美术试玩共用动作播放器和攻击结算模块。

当前为可逐波经营的四波挑战：手绘棋盘、五英雄、山狼及野猪已接入，灰鼠和唐僧仍保留旧素材。数值为测试值；章节进度、自动存档和完整技能尚未完成。

## 启动

需要 Godot 4.7.2 Standard（Compatibility 渲染）。

- Mac：双击本目录 `launch.command`，或运行 `bash godot-demo/launch.command`。
- Windows：双击本目录 `launch.cmd`。可将 `GODOT_BIN` 设为 Godot 可执行文件完整路径。
- 命令行：仓库根目录执行 `godot --path godot-demo`。
- 编辑器：导入本目录 `project.godot` 后运行主场景。

首次运行由 Godot 导入现有资源；启动器需要本机安装引擎，当前不是免安装发布包。

免安装的 Windows x86_64 试玩包使用仓库根目录的发布脚本生成：

```sh
./scripts/build_windows_release.sh 0.1.0-playtest.1
```

构建要求 Godot 4.7.2 与匹配的 Windows Release 导出模板，产物默认写入仓库外发目录 `build/windows/`（已忽略，不提交 Git）。完整发布与 Windows 实机验收步骤见 [`docs/release/WINDOWS_PLAYTEST.md`](../docs/release/WINDOWS_PLAYTEST.md)。

## 首次体验

1. 初始3金币、3人口；空格展开商店，首轮展示五名不同的一费英雄，后续刷新允许重复。
2. 推荐先购买护寺棍僧、山野猎户和药灵童子。
3. 将棍僧放唐僧左侧、猎户放上方、药灵放下方，再开始战斗。
4. 每波胜利进入不限时整备：战利品入账、商店补满、一次免费刷新；购买、合成、出售、升级人口或调整阵容后，手动点击“开始第N波”。英雄满血回到布阵位置，唐僧保留血量。
5. 结算后“重新体验”会重置金币、阵容和商店。当前不保存进度。

可另行尝试山雀精的远程投射、狐火小妖的小范围伤害。前排、近战输出、远程、治疗、范围输出的基础行为已接通；护盾、猎犬、山雀增益、熊山君完整技能和二三星新增技能仍待后续实现。升星当前增加基础属性，技能说明会显示尚未实现的内容。

## 操作与规则

- 点击商店或按数字键1—5购买；拖动角色，或先选角色再点击格子布阵。
- 中央格不可部署；候选区8格，上场人数受人口限制。
- R刷新：每轮整备一次免费（不累积），之后2金币；E升级人口，升4人口4金，后续6/8/10/12/14/16金。
- 三名同身份、同星、未锁定英雄自动合成，最高三星；点击角色可以出售或设置合成锁。
- Space或左下按钮展开/收起招募商店，默认收起；Esc或面板关闭按钮收起。数字购买/R刷新仅在商店展开时生效。底部八格石台替补席常显，拖动队员上阵。
- 开战使用“开始战斗”按钮；P或右上按钮暂停/继续。暂停冻结移动、动作、飞弹、治疗、波次和反馈。展开商店不会自动暂停战斗。
- 普通攻击在动作释放时命中；飞弹和治疗在抵达时结算，每次只结算一次。
- 唐僧死亡失败；每波成功时按当时血量发放80%/90%/100%战利品（向上取整），立即用于下一波。满血各波可得3/4/6/7金；最终只发最后一波，不重复发之前奖励，并按最终血量评星。
- 失败不发当前波战利品，之前已发金币不回扣；本轮终止，重新挑战从3金币与空阵容开始。章节失败回退和存档尚未接入。
- 四波敌人组合不变，生命系数1.0/1.15/1.35/1.60，伤害系数1.0/1.05/1.10/1.20，给波间招募/合成留出成长空间；均为试玩参数。
- 音效使用已采用的角色音效及少量UI占位音，支持关闭和调音量；包含第三方狐火改编素材，署名见CREDITS.md；没有加入震屏。

## 自动检查

在仓库根目录执行：

```sh
godot --headless --path godot-demo --script res://tests/smoke_test.gd
godot --headless --path godot-demo --script res://tests/full_battle_test.gd
godot --headless --path godot-demo --script res://tests/presentation_integration_test.gd
godot --headless --path godot-demo --script res://tests/demo_integration_test.gd
godot --headless --path godot-demo --script res://tests/wave_preparation_test.gd
```

整合测试覆盖30/60/120 FPS与1×/2×的一致性、波间购物/合成/布阵/人口、逐波结算去重、血量继承与复原、四波胜败、暂停及重开。推荐初始三人、不额外购买的回归约72.05战斗秒完成、唐僧300/300、累计20金（不含玩家整备时间），不是最终难度标准。另有跨波合成及四人口扩编通关测试。独立美术试玩verify.gd仍有既有猎户未攻击断言失败，不属于主Demo通过项。

`tests/render_preview.gd` 可在图形模式生成截图，默认写入 `user://demo-preview.png`，可用 `DEMO_PREVIEW_PATH` 指定输出。现有独立美术试玩入口继续保留。

## 扩展边界

- `scripts/data/`：英雄与单场波次配置；临时数值与正式设计分开。
- `scripts/presentation/`：共享动作、素材加载、发射点、占位音效。
- `scripts/combat/attack_events.gd`：动作序号、投射物与单次命中队列。
- `unit.gd`、`enemy.gd`：单位状态；`game.gd`组合商店、布阵与战斗。
- 后续章节状态与存档从此处扩展；不要求重做动作播放器。

设计基线见 [确认版设计](../docs/CONFIRMED_GAME_DESIGN.md)，开发范围与待办见 [06工作流](../docs/workstreams/06-development.md)。
# 2026-09-27 山狼接入

## 2026-09-29 音效试接

狐火攻击已改用负责人选定的DWOBoyle《Fire Ball》改编A版（0.57秒），保持弹体释放触发。采用路径独立保存在 `audio/runtime_overrides.json`，不受v1合成工具重建覆盖。其余角色不变、英雄退场仍静音。该音频为CC BY 4.0第三方改编，随游戏交付须携带 [CREDITS.md](CREDITS.md) 及原素材包ATTRIBUTION.md，不能称全部音效自制。

本日主棋盘也已切换手绘背景，野猪选择 `production/boar/painted_v1`（旧包保留）。`scripts/presentation/board_geometry.gd` 保存石缝交点标定，点击、拖放、高亮和脚点共享同一透视映射；逻辑仍为5×7，中央唐僧格不变。运行截图见 `tests/painted-board-preview.png`。坐标回归：`godot --headless --path godot-demo --script res://tests/board_geometry_test.gd`。手绘曲线与四边形边界允许少量像素误差，不代表逐像素匹配。

已按 `audio/candidates/v1/adoption.json` 接入17条角色攻击/施法、怪物死亡、共用材质受击及唐僧警示。五名英雄退场保持无声；UI和胜利保留旧音效。近战省略附加材质音以免双重敲击，远程非致命命中使用材质音。右上开关和滑条控制所有试玩音效；暂停冻结声音，2×不变调，重开停止旧声音。

验证命令：`godot --headless --path godot-demo --script res://tests/audio_integration_test.gd` 只验证程序调度；`godot-demo/launch.command --script res://tests/audio_output_test.gd` 在正常窗口播放短音，验证引擎输出和控件。后者不改系统音量/设备，也不等于人工听感验收。请先低音量试听，再比较1×/2×战斗中警示与攻击是否清晰。

第三波山狼已使用新的透明五姿势素材；左右朝向、扑咬、受击及退场已接入共享播放器。移动是单姿势配合程序过渡，并非完整逐帧动画。旧测试战斗数值保持不变。

2026-09-28：野猪也已接入五基础姿势，沿用原Demo双足绿金护甲、钉头锤造型；攻击/受击不再仅靠单图缩放变色。仍为关键姿势配合程序过渡，攻击或移动期间受击以闪色反馈为主，不打断动作。灰鼠仍为旧单图占位。
