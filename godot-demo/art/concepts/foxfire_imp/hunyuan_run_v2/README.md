# 狐火小妖：奔跑返工 v2

日期：2026-10-13。v1 的观感被负责人否定，已撤回采用建议。本版在独立目录返工，不覆盖原模型、旧绑定或游戏资源。

## 当前结论

通过本轮“可展示的原地奔跑小样”内部视觉复审，不是正式游戏动画验收。主审检查前、侧关键姿势，另一审阅者按顺序补齐两视角全部 20 个姿势：支撑脚有落地承重，前摆、回收、腾空可辨；不再举掌招手，未见明显翻腕、反折膝、裤裆拉丝或手尾纠缠。数值检查与视觉意见分别记录，不能相互替代。

这是顺序逐帧视觉审查和文件检查，不冒充真人连续播放或游戏内验收。正常速度、半速 GIF 均由同一最终工程实际蒙皮渲染编码，已逐帧解码校验；GIF 时间精度造成正常一轮 660ms、半速 1330ms，而工程/GLB 精确一轮为 2/3 秒。

仍保留的限制：手爪为静态张开造型；尾巴和袍摆略硬，未做布料模拟、独立手指或表情；未验证全身所有自碰、游戏位移与足底速度匹配、状态混合或性能。没有擅自扩展到其他动作、其他角色或全员 3D 迁移。

## 查看

- `foxfire-run.blend`：Blender 使用「文件 → 打开」。先保存自己当前工程；本轮没有覆盖用户已打开的场景。选中的 `Foxfire_Rig` 在姿态模式，骨架“在前面显示”。时间轴 1～20，空格播放/停止，临时关闭叠加层可看纯模型。
- `foxfire-run.glb`：包含人物、25 根骨骼（含五尾骨）和 `Foxfire_Run_Kenney_Retarget_v2` 动作；不含预览地面、灯光或相机。
- `run-front.gif` / `run-side.gif`：正常速度前侧、侧面预览；`run-front-slow.gif` / `run-side-slow.gif` 为半速。
- `front-poses.jpg` / `side-poses.jpg`：八个时刻便于静态对照，不替代连续动作。

原地循环由程序另行控制场景内移动；站在固定位置跑不是丢失移动轨迹。30 FPS、20 个唯一帧，导出第 21 帧复制第 1 帧，播放范围不重复端点。

## 本次改了什么

放弃 v1 的公式摆臂/腿部主轨迹，采用有明确许可的 Kenney 跑步动作，重定向到狐火现有骨架，再按短腿比例、落地高度和尾巴做适配。不是原创动作捕捉，也不是单张图片变形。

- 全旋转重定向保留肩、肘、腕扭转和身体反向摆动；针对源参考姿势弯膝而狐火直腿的差异校正腿部参考旋转。
- 根据源动作脚尖离地量校正整个人物的周期高度，解决直接换比例后支撑帧悬空的问题。保留真实腾空区段，不把所有帧钉在地上。
- 继承 Run v1 副本的局部裤腿权重改良，但不继承失败的 v1 动作；原始模型、`hunyuan_rig_v1/` 及其权重不改。尾链增加轻量跟随，不新增衣料物理。

## 来源与许可

动作来自 [Kenney — Animated Characters Protagonists](https://kenney.nl/assets/animated-characters-protagonists)，包内版本 1.1，`Animations/run.fbx`。该动画原文件与原始 `License.txt` 一并保存在 `motion_source/`，许可 **CC0**。狐火模型仍是项目已有的用户模型，不是 Kenney 的角色模型。

官方包下载地址：<https://kenney.nl/media/pages/assets/animated-characters-protagonists/608191acc4-1774773108/kenney_animated-characters-protagonists.zip>。

- 原 ZIP SHA-256：`ec3787de70fa2200256848d74201b10f6b6c3126594e9857bf989753312c2b84`，未将整个角色包纳入项目。
- 原 FBX SHA-256：`e635461fc8dace85ec67a7f7941e949a7c3f108b51ae4d2da1557e6e01749df8`。
- 最终 GLB SHA-256：`d467e950dc0559f9e382ed3460a5cdcdf782ee46aca0310d9900eaaebe024462`。

## 验证证据

`build-report.json` 为制作参数；`roundtrip-report.json` 为全新 Blender 场景重导入最终 GLB；`preview-report.json` 绑定预览和同一 GLB 哈希。独立审阅报告为 `independent-audit.json`、`independent-contact.json`、`independent-velocity.json`、`independent-source-motion.json`。

- Blender 5.2.2 实际 GLB 重导成功：25 骨、40,310 加权顶点、1 动作；各中间姿势确实变形，首末网格位置误差为 0。
- 独立 41 个关键/半帧采样，脚底均在地面之上，左最低 0.000614、右最低 0.000427；两脚分别有连续支撑区段。采样检查不代表数学上任意时刻的零穿插保证。
- 同一采样对高权重手部与躯干/尾部做三角相交检查，无命中；未覆盖袖部或全身自碰。
- 几何、UV、3 张嵌入 PNG 与原件保持；尾部原权重只存在约 5.96e-8 浮点误差。导出器的纹理采样器提示经文件核对未导致贴图改变。
- 首末位置闭合不等于速度严格连续：接缝最高顶点速度差约 1.519，主要来自源动作腿足旋转；内部其他节点最高变化更大，不能单独把该数值当成坏接缝，也不宣称严格 C1 连续。

## 复现与同步

保持与 `../hunyuan_run_v1/foxfire-run.blend` 的相对关系（仅复用骨架/蒙皮，脚本清除旧动作）。需要 Blender 与带 Pillow 的 Python，不依赖付费绑定服务：

```sh
blender --background --factory-startup --disable-autoexec --python-exit-code 1 --python build_run.py -- --render-full
blender --background --factory-startup --disable-autoexec --python-exit-code 1 --python check_export.py
python3 review_previews.py
```

`--preview-only` 只渲染已保存工程；`--render` 是内部八姿势检查。`drafts/` 与 `preview_frames/` 为可再生中间文件，不入 Git。`.gdignore` 隔离游戏导入。

本版与 v1 不采用标记、05 工作流统一提交至项目 Gitee，属于已授权的本角色绑定/奔跑成果同步；实际同步结果以 Git 远端记录为准。后续先保留此版供现有原型使用决策，不自动扩动作或改游戏。
