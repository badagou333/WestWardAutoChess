# 松庭 · 狐火三维棋盘样板

2026-10-13 · 05 美术职责的独立视觉试场。**不是原 Demo 已完成三维改造，也不是完整战斗版本。**

## 做了什么

- 当前版本为**一手一火、左高右低的双火待机／双腿奔跑样板**。只参考火女上身控火的姿态关系，不复制她的漂浮移动；不采用旧的双手合托一球草稿。
- 同一个真实三维场景承载石台、山门、松树、狐火、相机和灯光。人物与环境共用透视、深度遮挡及实时阴影，不是往原棋盘上贴一张三维角色截图。
- 保留 12×7 平面格子思路：角色仅沿 XZ 地面移动，Y 是视觉高度。点击落格、路径、转身、Idle/Run、起停混合、暂停和自动巡视可实际操作。
- 加入有厚度的地基、石台阶、低噪声石材、层叠松枝、石灯与克制 UI；不占用 84 个可行走格。
- 比较 Compatibility 和 Forward+、透视和正交视角。主展示采用 Forward+；兼容渲染只作为功能降级，不宣称同等光影。
- 《将熄之焰》仅是“固定俯视、立体单位、统一空间与灯光”的目标参考，没有使用其模型、贴图、界面或关卡。这里仍是原创建筑/环境的单角色试验，不承诺已达到商业成品完成度。

## 打开与操作

Mac 安装 Godot 4.7 后，双击本目录 `launch.command`。也可以在 Godot 项目管理器导入**本目录**的 `project.godot` 后运行。不要打开上层主游戏后寻找这个场景；本目录用 `.gdignore` 与上层隔离。

启动器会先做本地资源导入，再打开试玩。首开会稍慢：三张4K贴图由GLB内嵌数据自动提取，无需重复提交33MB解包PNG；两份全新临时副本已实测再生文件哈希一致。

| 操作 | 效果 |
|---|---|
| 左键点击石台 | 狐火沿格子前往，停下后恢复待机 |
| 1 / 2 / 3 | 沉浸透视 / 战术正交 / 俯瞰 |
| 4 | 跟随角色的近景，观察尾巴、脚步与转身 |
| G | 辅助格线开关 |
| 空格 | 暂停/继续，含骨骼动画 |
| R | 归位，并停止自动巡视 |
| 自动漫游按钮 | 按固定路线往返，测试多个朝向与起停 |
| Esc | 停止自动巡视，不退出已有其他游戏窗口 |

其他机器使用 Godot 4.7 打开此独立工程即可；不依赖本机 Blender 路径。Mac 优先 Metal，Windows/Linux 使用 Godot 支持的 Forward+ 驱动。**Windows 尚未实机验证。**

旧硬件功能降级：`./launch.command --rendering-method gl_compatibility`。此模式没有同等 TAA/SSAO；不要将其截图与主展示混为同一画质。

## 模型与动作

`assets/foxfire-board.glb` 是 [双动作制作资产](../../concepts/foxfire_imp/hunyuan_board_actor_v1/README.md)的原样副本：25 骨、50,789 三角形、原 3 张 4K 内嵌贴图。SHA-256：`4257ac78a80ade3bbd328212c9341ecf9f775a7a8452aef7f8a2fc0875cfaa57`。

- GLB 中的原 Idle/Run 保留。当前播放 `dual_fire/DualFireIdle` 与 `dual_fire/DualFireRun`：从原动作复制，仅以小体积 `assets/dual-fire-animations.json` 覆盖六根手臂骨的轨道。左右手高低、前后分开，保留少量非同步微动；腿、躯干、尾巴继续原动画。
- 制作源与完整数据约定见[双火动作候选](../../concepts/foxfire_imp/hunyuan_dual_fire_v1/README.md)。不重复保存完整模型；本地重新制作时从已有 Blender 工程载入再生成轻量补丁。
- 两团火各自跟随本手的掌指挂点，采用有深度遮挡的三维火焰体、微小火星与弱掌光。运行、暂停、动作切换及归位由统一时钟控制，两火保持不同变化相位。不是两个球共同跟随角色原点或双手中点。
- 去除源动画帧1的1/30秒导入前导段；Idle 根骨另有已记录的约0.155毫米世界位移闭环修正，其他非臂曲线按原相位保留。该修正不是重新制作腿部步态。
- 引擎整体缩放 1.65；移动 2.35 单位/秒，Run 0.65 倍播放。基于真实蒙皮脚底位移测量减少滑步，**不是 IK 锁足，也不保证完全零滑步**。
- 未制作攻击、受击、退场、碰撞物理、布料或投射物命中；两手火焰仅是待机／移动展示，不代表战斗技能已接入，目前不具备替换整套战斗角色的动作条件。
- 宽袖、袍摆与尾巴仍有刚性；本轮目标是上棋盘的空间可信度与基础移动展示，不能把网格采样通过说成所有穿插已排除。

## 验证与证据

实际 Godot 版本、渲染设备、逻辑/输入/几何检查和性能采样在 `reports/` 记录。作者静态与逐帧复审、程序注入输入、独立审查、用户真人体验是不同层级；本轮没有冒称用户已认可。

### 当前双火版本

- `reports/dual-fire.json` 作者专项10/10；`dual-fire-independent.json` 独立数值复核30/30。覆盖两动作、各自手骨父链挂点、单手扰动负对照、原身体曲线、混合途中暂停、两火及14颗火星/灯光/材质时钟、恢复与归位。不能据这些数值声称动作审美通过。
- `dual-fire-logic.json` 逻辑13/13、`dual-fire-input.json` 真实视口事件注入9/9。正式游戏未修改，本轮没有运行其战斗验收。
- `dual-fire-performance.json`：Apple M1、Metal Forward+、1440×900，8秒预热后约12秒720帧，平均59.92 FPS、帧间隔p95 17.648ms、中位1501 draw calls，仅此单角色。
- 作者与独立视觉审查已看正/侧真实火焰及8秒接触表、前侧跑/背跑/返身/回正关键帧：双手分开、高低清楚，没有发现持续盖住眼口、共托成碗或明显袖口吞手的问题。纯侧面部分角度远手火与头部投影接近，背侧远手会正常被身体遮挡；并非全角度都能同时看见两团火。仍有宽袖/尾巴刚性、细节运动噪点，不宣称所有帧无穿插或完全无滑步，也不冒充真人连续播放验收。
- `preview-dual-fire.png` 是当前正面实机图，`preview-dual-fire.mp4` 是8秒120帧实机片段，`preview-dual-fire-contact.jpg` 为抽样。录像按60Hz推进动作/相机/抗锯齿，仅保存15FPS，不做插帧；全部120帧编码后解码检查见 `dual-fire-video.json`。视频不是无缝循环。

### 无手火的历史基线

以下报告和 `preview-walk.mp4` 属于此前无手火版本，不能当作新增双火的验证结果。

- Godot 4.7.2、Apple M1、Metal Forward+、TAA＋4×MSAA、SSAO Medium＋全分辨率。
- 实际窗口1440×900、逻辑尺寸1600×1000；8秒预热后12.015秒采样713帧，平均59.34 FPS，帧间隔p95 18.38ms。约1477 draw calls，后续多单位/移动端不能照搬这一结果。
- 逻辑13/13、真实视口事件注入9/9、两次冷导入通过。几何检查分别对照外侧方向验证绕序和法线，三种错误负对照均被拒绝；SphereMesh极点14个退化三角单列，未假装为有效面。
- 作者审过最终全景/近景及8秒120帧接触表；独立复核近景、战术静帧与右跑/背面/转身后侧跑/停站4个原始关键帧，没有发现阻止本轮体验的明显漏面、悬空、尾巴断开或长拖影。**不是真人连续播放验收，不排除所有瞬时穿插/滑步。**

`preview-wide.png`、`preview-close.png` 是最终实机截图；`preview-walk.mp4` 是8秒真实视口片段，`preview-walk-contact.jpg` 保存逐帧抽样。视频不是无缝动画循环。

可复验命令（在本目录运行，Mac 图形测试需可用 Metal 会话）：

```sh
godot --headless --path . -- --verify --report=/tmp/fox-logic.json
godot --headless --path . -- --dual-fire-verify --report=/tmp/fox-dual-fire.json
godot --headless --path . --script verify_geometry.gd
godot --path . -- --input-verify --report=/tmp/fox-input.json
godot --path . -- --performance --report=/tmp/fox-performance.json
godot --path . -- --capture=/tmp/fox.png --camera=4
godot --path . -- --sequence=/tmp/fox-frames --camera=4 --auto --duration=8 --fps=15
python3 pack_preview.py /tmp/fox-frames /tmp/fox.gif --fps=15
```

Mac 可用系统 AVFoundation 把120张1440×900的15FPS帧编码成较小的H.264视频：`swift -module-cache-path /tmp/fox-swift-cache pack_video.swift /tmp/fox-frames /tmp/fox.mp4`。脚本会解码全部120帧复验尺寸、8秒时长和首帧方向；目标已存在时拒绝覆盖。最终视频约数MB，不分发较大的工作GIF。

截图/动图仅来自真实引擎视口，未使用生成图充当运行结果。性能必须来自预热后的正常窗口，不把逐帧写 PNG 的速度当实时 FPS；单角色结果不能外推成全员战斗性能。

## 来源、边界与后续

- 场景几何与材质：本批代码生成，未导入商店素材；研究过可用 CC0 环境包，但本包没有使用或重新分发它们。
- 狐火：用户提供的混元模型；其原商业授权未独立核实，沿用非商业试验。动作参考为 Kenney CC0，完整来源、原动画与许可证保存在双动作及 Run v2 制作目录，不把 CC0 动作授权当成模型商用授权。
- 引擎实现依据：[Godot 3D 导入](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html)。目标参考：[The Last Flame 官方商店页](https://store.steampowered.com/app/1830970/The_Last_Flame/)。
- 双火上身姿态参考：[Dota 2 Lina 官方页面](https://www.dota2.com/hero/lina)。实际查看官方角色展示，仅参考双臂自然分离、高低和前后关系；未下载或使用 Valve 模型、贴图、骨架或动画。
- 正式游戏脚本、棋盘、数值、角色二维资产均未覆盖。后续若采用，需要 06 把统一三维显示层接到现有布阵/战斗状态，再做多单位、目标硬件性能与交互验收；不是简单替换一个 PNG 路径。
