# 松风台 2D斜视棋盘

2026-10-15交付。保留现有二维角色、12×7走格及完整战斗，将独立布阵Demo改成固定斜视石台：可见台面厚度、贴脚阴影、按脚点前后遮挡、较清楚的人物尺寸和血条。是可玩显示层改造，不是新生成的概念整图，也不把二维角色说成三维模型。

## 直接体验

Mac双击[棋盘启动器](../../../launch-board-trial.command)。其他已安装Godot 4.7.2 Standard的机器在仓库根目录执行：

```sh
godot --path godot-demo res://scenes/board_trial.tscn
```

项目普通`launch.command`仍启动护送模式，不会自动进入本棋盘。先关掉自己此前开的旧试玩窗口，再启动新入口。无需Blender，不依赖本机临时文件；跨机器拉取提交后由Godot导入资源。Mac已实测，Windows实机未测。

选底栏人物或按1—6，再点左半棋盘布阵；可拖放、交换和R撤下。点“开始战斗”，P暂停、1×/2×、右侧点敌人查看详情；结算后可重试。原A/B/C与敌阵对照选项保留，没有新增技能或经营规则。

- [20秒真实引擎预览](review/preview.mp4)：15FPS、300个原始视口帧，无补帧/合成、无声；展示部署到自然A局结算，不是帧率性能测试。
- [打包版布阵截图](review/formation.png)和[打包版战斗截图](review/battle.png)：直接从最终PCK视口输出。
- [旧矩形棋盘启动器](../../../launch-board-legacy.command)：保留原显示用于对照；源场景为`scenes/board_trial_legacy.tscn`。

## 方案选择与依据

调研后选用第一条路线。这是针对当前素材和尽快交付Demo的判断，不是以下作品都采用相同实现。

| 路线 | 依据与适用性 | 本次取舍 |
| --- | --- | --- |
| 纯2D固定镜头，地面投影与角色层分开 | [Bastion官方FAQ](https://www.supergiantgames.com/blog/bastion-faq/)说明其手绘二维美术；[Factorio FFF269](https://www.factorio.com/blog/post/fff-269)展示角色视角与地面投影不一致会破坏空间感。固定镜头可把造型、比例、脚点和遮挡统一处理。 | 采用。保留战斗和素材管线，用低斜视台面、接触影和脚点排序改善接地。没有把Bastion作为“全部动画手绘”的证据。 |
| 三维制作后烘焙多方向二维序列 | [Factorio FFF194](https://www.factorio.com/blog/post/fff-194)公开Blender渲染层、合成与精灵图流程。可统一多个方向的视角与光照，但各角色仍需模型、绑定、动作及序列制作。 | 后续如要补背面/斜侧方向再采用；当前只有狐火模型样板，不能称全员已具备。 |
| 二维角色放入三维场景 | [Klei官方说明](https://support.klei.com/hc/en-us/articles/360029554792-What-is-Don-t-Starve)介绍二维角色和三维世界；[Octopath II开发访谈](https://www.unrealengine.com/developer-interviews/octopath-traveler-ii-builds-a-bigger-bolder-world-in-its-stunning-hd-2d-style?lang=en-US)说明HD-2D角色与环境融合的制作工作。 | 不作为本轮主路线；仅换Sprite3D仍可能像纸片，还需调整镜头、光照、影子和方向素材。原独立狐火3D试场保持。 |

[Godot二维光影文档](https://docs.godotengine.org/en/stable/tutorials/2d/2d_lights_and_shadows.html)说明法线贴图用于改变受光，不会补出缺少的轮廓和背面；本次不把“加法线”当成修正视角的捷径。采用有限长度的二维轮廓投影和接触影，未启用假称共享三维深度的方案。

## 实际实现

- `scripts/presentation/board_depth_projection.gd`统一绘制与点选：`O=(234,406)`、`U=(92,-17)`、`V=(29,54)`，屏幕点为`O + U*x + V*y`；1920×1080逻辑画布。逆映射用于点击和拖放，台侧厚度不是可走格。
- `board_depth_stage.gd`绘制台面、台侧、石缝、台阶、选中/射程格、地影及环境。生成的背景和石材仅提供画面材质，**可走格仍由程序准确构造**。
- `board_depth.gd`为旧控制器的表现子类。角色保持直立、不将身体压扁或斜切；显示比例0.9（旧版0.72），按当前脚点Y排序；死亡当帧也完成最终排序。投射物保持原发射/命中时钟，显示发射点随角色变换。
- `board_depth_hud.gd`按实际透明边界确定血条高度；战斗满血且未选中时隐藏血条。`board_depth_ui.gd`只调整界面皮肤和提示，保留旧控件/交互。
- 共享`board_trial.gd`只增加显示坐标接口及其调用；占格、距离、寻路、0.50秒/格、伤害、治疗、胜败和声音规则保持。默认护送、旧固定棋盘、独立音效与狐火3D试场未被替换。

## 验证记录

作者测试与协作复核分别记录，不代表07正式独立验收或负责人已经认可。原始报告在[reports](reports/)；部分报告里的`/tmp`是当时输出路径，跨机器所需文件已复制到本目录，不依赖这些绝对路径。

| 检查 | 结果与范围 |
| --- | --- |
| 新投影与旧逻辑对照 | `source-parity.json`：938检查、24自然局、0失败；84格/边缘/逆映射、移动/暂停、10个远程朝向发射点，以及三配置×A/B/C/R的完整战报相等。 |
| 图形窗口交互 | `viewport-input.json`：635检查、84格、0失败、0指针超时；窗口事件注入完整按下/移动/松开、交换、模态阻挡、配置选择、缩放、开战/暂停/重试。此轮在最终1.0→0.9视觉微调及死亡排序修复之前完成；坐标和交互逻辑未再改变，不将它声称为最终版重新完整跑过。 |
| 旧入口回归 | `legacy-basic/bear/monk.json`和`audio-regression.json`均0失败；旧矩形几何断言显式迁移到legacy入口，敌阵/选中等新入口测试改用显示坐标，不删除原行为断言。四个旧GUI专项仅完成语法检查，没有冒称全部复跑。 |
| 实际导出包 | 首包漏带两纹理，保留`pack-first-attempt-failed.log`；补精确导出白名单后`pack-boot.log`五入口0失败，`pack-parity.json`24局/12组0失败、完整战报与原基准相等。317项资源通过非商业打包策略，两.import及实际GST2纹理存在。 |
| 打包版实际渲染 | `pack-visual.log`记录图形窗口出图；作者核对两张交付截图确认背景、石台、人物、HUD正常，不用headless载入代替画面验收。 |
| 视频 | `video.json`：20秒、1440×810、300帧全部可解码、正向相关性0.995，无倒置；记录文件旧名对应本目录`review/preview.mp4`，SHA见来源清单。 |
| 视觉复核 | 作者多次实机关键帧及协作代理7张最终静态/时序抽帧复核，未见本轮必修接地或排序问题；未做真人连续观感、Windows、任意DPI或多硬件性能验收。 |

最终验证包SHA256：`6e963435a7d4cf450188d69ec98d8feb62ef29ab50e4aadb16812d69fdce1f78`，18,735,956字节。PCK是可重建临时产物，不重复入库；首次漏资源的失败证据保留。发行脚本尚未自动串联这两项棋盘包测试，未来不能仅凭`BUILD_OK`声称本棋盘已通过。

## 复现与交接

在仓库根目录执行；图形输入和截图命令需要正常桌面，不加`--headless`。视频帧目录约数百MB，不纳入Git。

```sh
godot --headless --path godot-demo --script res://tests/board_depth_test.gd
godot --path godot-demo --script res://tests/board_depth_input_test.gd
godot --path godot-demo --script res://tests/board_depth_capture.gd -- --video --output=/tmp/board-depth-video
swift -module-cache-path /tmp/board-depth-swift-cache godot-demo/art/boards/depth_trial_v1/pack_video.swift /tmp/board-depth-video /tmp/board-depth-preview-new.mp4
godot --headless --path godot-demo --export-pack "Windows x86_64 Release" /tmp/board-depth-new.pck
python3 scripts/inspect_godot_pck.py /tmp/board-depth-new.pck --release-policy --usage noncommercial --output /tmp/board-depth-new-files.txt
godot --headless --main-pack /tmp/board-depth-new.pck --script /absolute/repo/godot-demo/tests/board_trial_pack_boot.gd
godot --headless --main-pack /tmp/board-depth-new.pck --script /absolute/repo/godot-demo/tests/board_trial_profile_pack_test.gd -- /absolute/repo/godot-demo/tests/board-trial-runtime/board-balance-20261009-natural.json
```

两条包测试的`/absolute/repo`需替换为实际仓库目录。Swift编码器仅用于Mac预览制作，游戏运行不需要Swift。Godot无窗口日志可能有本机系统证书提示，最终包无脚本/资源错误。

## 边界与来源

本轮改善的是台面空间、人物接地与遮挡。**现有二维角色仍以原来的正侧素材为主，没有重绘全员斜俯视/背面，也没有新增完整多方向动画**；无法把它描述成《将熄之焰》同级三维角色效果。熊近身时可能遮住唐僧身体，顶部唐僧血量仍可读，后续可补被保护对象的遮挡轮廓。现阶段先供体验，不继续无边界精修或批量重做角色。

两张新环境图由内置图像生成制作，提示词、哈希和用途见[PROMPTS.txt](PROMPTS.txt)与[provenance.json](provenance.json)；未复制参考游戏资产。人物沿用项目已存素材。现有音效的CC BY-NC限制仍然有效，本Demo仅作非商业试玩，完整署名见项目[CREDITS](../../../CREDITS.md)。
