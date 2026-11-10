# 翠鸟单向攻击展示：隔离代码准备候选

2026-11-02，D-20261101-002，06程序开发。此目录只完成代码、文字和资源清单准备，**尚未运行Godot、脚本解析、测试或GUI，不能称作者运行/验收通过**。未写共享仓库/06工作流、操作Git或工作树注册。等待00释放串行共享入库和作者实测窗口；熊v3的07窗口优先。

## 入口与范围

拟以`launch.command`独立启动，默认显示第0帧及中文“播放／重播”按钮；不自动播放。点击播放后单次播放，结束后静态查看末帧，可重播。仅当前单角色、单方向、单攻击动作，无镜像、自动循环、主战斗、伤害、射程、冷却或新特效；原视频不作为播放资源。

`project.godot/main.tscn/showcase.gd/showcase.json`组成独立Godot 4.7工程，原始PNG/WAV直接加载，设计上不依赖本机导入缓存，是否真正支持冷启动仍须运行核实。`launch.command`已设置可执行位，但本轮未执行；未来如需启动，须处于00放行的作者窗口。

## 来源与固定构图

输入为素材提交`a36cd562ee4f8876635b57c9136c4416357afe22`，来源根`godot-demo/art/candidates/c03_kingfisher_attack_v1/`。复制全部98张`frames/`PNG、当前映射manifest、选定`audio/feather-selected.wav`到`art/c03/`；林间棋盘从`bear-forehand-showcase/art/forest-board.png`原字节复制。共101个文件，复制字节一致；逐文件源路径/大小/散列见[resource-list.json](provenance/resource-list.json)。没有复制或混播源MP4声音，没有重新生成/解码媒体或改音频。

- 映射manifest SHA-256：`fd1ae8323bae9bbc24cef60a68fa715ed5228474bb7e9d11dfd4b13617f98b98`。
- 原冻结manifest SHA-256：`4d49afdbc42d29eb2bea3a6c071e8dc1a63ac11702c384d86ff102275b9f5d2b`，只作溯源，不与映射清单混用。
- WAV SHA-256：`d1310bdaa9ea6017c2bef9e9b159c73f9fa39e15f3d6e337b37250f65ca77cfb`。
- 棋盘 SHA-256：`7b568eb54ad25d18efa7dab24adcce833a4528940fdd615ca053196cd6ad1ed6`。

保持960×960完整画布，足参考(475,760)，世界脚点(720,441)，1440×810画面及144×72菱格约定。`showcase.json`的`presentation.display_scale=0.21`仅为待校准的试接倍率，全动作统一；`audio.start_seconds=0.405`仅为波形起播建议，非听感/命中确认。配置与来源事实分离，不向玩家展示实现字段。

固定变换`世界脚点+(源点-足参考)×倍率`，保原动作位移和烘焙飞羽，不逐帧裁切/锁脚/改变比例、不另叠飞羽或阴影。足参考是首帧构图参考，不等于逐帧足底或占格已验证。manifest只按`file/sha256/index/pts_ticks/source_duration_ticks`加载；`source_frozen_file/source_video`及历史status不当运行路径或验收结论。

## 时间与声音契约

原98项0基索引全部保留，以非均匀PTS而非均匀帧率播放。时基1/90000，精确终点`T=260250/90000=347/120秒`。`0≤t<T`按半开区间选帧；`t≥T`时钟停在T，进入明确Ended末态，静态显示index97。index97的源duration仍为0；末态是播放器查看状态，不补源视频时长、不沿用2.985秒、不暗丢末项。没有自动循环。

所选WAV为44.1kHz双声道16位、44100采样帧，1秒；候选声音区间`[0.405,1.405)`。单个AudioStreamPlayer/max_polyphony=1：

1. 早于起点不发声；跨起点后只处理一次，从当前`phase=t-0.405`位置播放，phase在`[0,1)`内才启动。
2. 先比较绝对声音终点`t≥0.405+1`，避免恰尾减法误差导致补播；已过尾或Ended只标记已处理，不迟补旧声音。
3. 重播先stop旧声，重置elapsed/事件标志，再从0开始；同一次播放的后续更新不重复启动。
4. `inspect_frame(index)`仅供后续真实运行采样/审帧，停声并进入Inspection，不触发声音；退出停止播放器。

这些为代码准备中的明确实现选择，行为尚未运行验证；不改选定WAV、不倒放/换声道，也不把偏移当实际战斗事件。

## 必须后续执行的最小检查

先由00释放共享入库/作者运行窗口，再将本目录必要文件纳入独立`c03-attack-showcase/`，更新06工作流、必要检查后提交推送。正式运行前须复核候选未被改动、输入版本/文件清单及本轮静态审阅问题。

建议先在无缓存独立副本运行已准备的入口（以下命令本轮均未执行）：

```sh
./launch.command --headless --audio-driver Dummy --script res://tests/test.gd -- --output=/tmp/c03-author-engine.json
./launch.command --rendering-method gl_compatibility --audio-driver Dummy
```

前者应核全98条PTS/持续时间、T前后和末样本0、WAV/PCM、声音前/恰点/跨点当前相位/恰尾/过尾/Ended不补播、重播清理/一次触发、静帧禁声及固定脚点；测试准备范围见`tests/TEST_PLAN.md`。不得因静态审阅或命令存在而认为测试通过。后者需真实专用窗口冷启动并保存Godot实际时间/索引及原像素画面，重点0基31→32灰晕/飞羽突现、尺度/足点、首尾和末态，不能用离线叠底代替。

06作者运行后交07独立技术，再05真实视觉与真人听感；保留原工具QA fail和灰残留/足参考边界。单向必要技术/05实际视觉通过后，才按已有授权实现水平镜像，复用相同纹理/PTS/WAV与同足点，允许持械侧翻转；本轮未提前实现。未扩新动作/角色/费用/平台发行，automation-3保持暂停。
