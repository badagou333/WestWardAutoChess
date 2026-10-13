# 狐火小妖：独立三维棋盘双动作资产

日期：2026-10-13。仅供本轮独立三维棋盘试场；不是全项目三维迁移或完整战斗角色交付。未修改原模型、已审 Run v2、其他角色、现有正式棋盘。

## 集成约定

- `foxfire-board-actor.glb`：一网格、一材质、25 根骨骼（含五尾骨），动画 **Idle** 与 **Run**。
- `Idle`：3 秒，30 FPS、90 唯一帧与闭合端点。自然垂臂、轻微呼吸与尾链跟随；不要停在绑定 T 姿代替待机。
- `Run`：2/3 秒，30 FPS、20 唯一帧与闭合端点。与已审 `hunyuan_run_v2` 曲线完全相同，仅统一名称；原地奔跑，场景平移由引擎控制。
- glTF / Godot：Y 向上，角色脸朝 **+Z**。Blender 对应 Z 向上、脸朝 -Y；Godot `look_at` 应按模型 +Z 前向处理，不额外随意旋转骨架。
- 原尺寸约 1 米高，导出缩放保持 1；在角色父节点统一缩放。脚下地平面设为 Y=0，Idle 左脚最低约 0.002、右脚约 0.005～0.006；不要再以包围盒中心作为地面锚点。
- 初始立即播放 Idle；移动播放 Run；0.15～0.22 秒混合作为试场起始建议，须由试场验证，不是已验证状态机参数。
- 本目录带 `.gdignore`，不被正式项目自动导入。集成者把最终 GLB **原样复制**到独立试场的可导入资产目录，核对 SHA 后再导入，不把制作工程、源动画和报告塞进运行包。

## 制作与来源

绑定、网格、材质、UV 和权重全部来自 `../hunyuan_run_v2/foxfire-run.blend`；Run 也直接保留。待机采用同一官方 [Kenney Animated Characters Protagonists](https://kenney.nl/assets/animated-characters-protagonists) 1.1 包内 `Animations/idle.fbx`，按参考姿势重定向全旋转，适配原模型短腿比例和接地，减慢为 3 秒循环，补五尾骨小幅运动。不是从 T 姿直接把双臂压下去，也不是原创动作捕捉。

原 `idle.fbx` 与包内原 `License.txt` 随本目录保存；许可 CC0，模型仍是项目用户提供的狐火模型，其商用许可未因 CC0 动作而得到独立确认。本试场沿用非商业探索边界。

## 已验证及限制

- 作者看过前侧、正侧、斜俯视的关键时刻：双臂放低，双脚接地，尾在身后，待机与原角色识别一致。只属于作者静态关键姿势复审，不代主审、连续真人观感或棋盘效果验收。
- 最终 GLB 在空场景重新导入：Idle / Run 两动作实际蒙皮变形、各自首末网格误差 0；Idle 181 个关键/半帧采样、Run 41 个采样，全网格（含尾尖）及所检查脚底均未穿地。初稿 Idle 尾尖约 4 mm 穿地已通过仅抬尾根 4°修正，不改 Run。
- 40,310 导出顶点、50,789 三角形、25 骨；与 Run v2 的位置、法线、UV、骨骼索引、权重、三角索引均逐项一致；3 张原 4K 内嵌贴图逐字节一致。没有降面、重拓扑、重新烘焙或缩小贴图。
- 此轮没有攻击、受击、死亡、脸部、手指细分或布料模拟；宽袖、袍摆和尾巴仍有已知刚性，未验证所有自碰。自然起停混合、转身角速度、走格位移与奔跑足速匹配，以及真实渲染性能交由独立试场验证。
- GLB 为 35,806,108 字节，SHA-256：`4257ac78a80ade3bbd328212c9341ecf9f775a7a8452aef7f8a2fc0875cfaa57`。

`build-report.json` 保存来源与 Run 曲线原样检查；`roundtrip-report.json` 保存最终文件哈希及真实重导采样。`idle-front.png`、`idle-side.png`、`idle-board-angle.png` 是同一最终工程的静帧，不是游戏截图。

## 复现

保留相邻目录的相对位置，使用 Blender 5.2.2：

```sh
blender --background --factory-startup --disable-autoexec --python-exit-code 1 --python build_actor.py -- --render
blender --background --factory-startup --disable-autoexec --python-exit-code 1 --python check_actor.py
```

`foxfire-board-actor.blend` 为可编辑工程，默认 Idle；可在动作编辑器选择 Run。`drafts/` 中间渲染被忽略，可再生。后台制作没有操作或覆盖用户现有 Blender GUI 工程。
