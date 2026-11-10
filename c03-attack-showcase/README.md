# 翠鸟攻击展示（原向／镜像）

> 2026-11-10 D-20261110-004：已加水平镜像。Windows 双击 `launch.bat`，macOS 双击 `launch.command`。右上“原向 (1)／镜像 (2)”或数字键 1/2 切换朝向；镜像复用同一 98 帧纹理、PTS、WAV，围同一世界脚点 (720,441) 水平翻转，持械侧随之换侧；切向只改显示，不重置时间或声音。作者自测见 [20261110-mirror](validation/20261110-mirror/README.md)，07 独立与 05 视觉待做。下文为单向阶段原说明，其中“没有镜像”等表述已被本条替代。

双击本目录`launch.command`启动。棋盘上只有一只翠鸟，点击“播放”单次播放攻击，结束后显示末帧；“重播”从头开始并清理旧声音。默认静止，不自动循环。没有镜像、战斗或其他角色，原游戏保持。

2026-11-02，D-20261101-002。已按00在c81199d后的放行完成共享入库、作者源码/无缓存副本检查及实际Godot采样，**尚未替代07独立、C3美术视觉和真人听感验收**。权威实际结果见[本批验证](validation/20261102-single/README.md)。

## 入口与范围

`launch.command`独立启动，默认显示第0帧及中文“播放／重播”按钮。仅当前单角色、单方向、单攻击动作，无主战斗、伤害、射程、冷却或新特效；原视频不作为播放资源。

`project.godot/main.tscn/showcase.gd/showcase.json`组成独立Godot工程，实测4.7.2；PNG/WAV直接读取，已在不含仓库候选及.godot/.import/.uid的独立副本执行测试和实际图形首启。运行资源全部位于本目录，不依赖原临时目录。`provenance/preparation-20261102/`保存此前未运行的准备记录，其中/tmp路径及“未执行”状态只反映历史阶段，不作为当前入口、运行依赖或当前验收结论。

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

上述试接实现已由作者边界检查及正常图形观察验证；不是最终听感或战斗规则。选定WAV不改、不倒放/换声道，偏移不当实际战斗事件。

## 作者检查与后续验收

源码/无缓存独立副本各1032项、0失败；资源检查source1209/cold1108项通过，原98PNG/manifest/WAV/棋盘共101件原字节保持。冷副本少101项仅为可选的仓库候选/棋盘跨目录比较，全部固定pin/运行资源核验仍执行。首解析类型推断错误及正常图形探针的首次观测错误均保留，没有通过删原保护或修改素材来通过。

本次无缓存副本真实macOS/Apple M1 OpenGL4.1窗口采9组／18PNG：Ready首帧0、0基29～34及96审帧、经播放达到T的真正Ended97，每组含完整Viewport和同图原像素局部裁片。正常自动图形播放两次达到T，另核活跃声音重播及实际树退出，修正后的33项观察0失败。没有OS鼠标/设备播放或真人持续观看声称。全部记录和限制见本批验证目录。

从本目录复现：

```sh
python3 verify_assets.py --output=/tmp/c03-author-assets.json
./launch.command --headless --audio-driver Dummy --script res://tests/test.gd -- --output=/tmp/c03-author-engine.json
./launch.command --rendering-method gl_compatibility --audio-driver Dummy --script res://capture.gd -- --output=/tmp/c03-author-render
./launch.command --rendering-method gl_compatibility --audio-driver Dummy --script res://realtime_probe.gd -- --output=/tmp/c03-author-realtime.json
```

`tests/TEST_PLAN.md`列出必要边界范围。正常播放的屏幕刷新不是全部98源时刻的呈现保证；精确源帧保留和静态取样不等于真人连续观感。原始混音游标只作诊断，精确起播相位另以短锁内同WAV原生参考比较；两者均不等于设备声音延迟或听感。

06作者运行后交07独立技术，再05真实视觉与真人听感；保留原工具QA fail和灰残留/足参考边界。单向必要技术/05实际视觉通过后，才按已有授权实现水平镜像，复用相同纹理/PTS/WAV与同足点，允许持械侧翻转；本轮未提前实现。未扩新动作/角色/费用/平台发行，automation-3保持暂停。
