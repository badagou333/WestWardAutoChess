# D-20261102-002 熊山君正面v3作者接入验证

2026-11-02。输入为05的e7d7b4d选定24源像素FX右缘渐隐版；00以77ee508完成汇总后释放本轮Local/06工作流/Git/专用GUI窗口。仅接入既有单熊展示的正面两向，不启动C3实现、改主战斗或继续调素材。

## 变更及来源

从`godot-demo/art/candidates/bear_lord_front_attack_v3/`显式复制全部84PNG、manifest及原WAV到现有运行路径。与v2运行相比实际PNG差异仅38～51，共14张；其余70张及WAV逐字节相同。manifest为v3原字节，SHA-256 `53f2cd27b2678282ae8e8fa905b4ce8e46cded2623a7b9384e1c870c3b3e2237`，schema=`board-bear-front-trail-trial-v1`。来源相对路径只供追溯，生成时status未重写。

showcase.gd、clips.json、项目/场景/启动器无需改动。保持全部原PTS、84个源时刻／原10～93映射、末帧2.95～3秒／0.05秒、3秒视频／0额外间隔、400×320／脚锚(177,213)／0.75倍率／世界脚点(720,441)及镜像；单播放器stop→play、同向no-op、跨多轮按当前phase定位及声音尾禁补播均保持。背面340时刻、原声、棋盘和四向控制保持。v2构建依赖及旧作者/07失败证据保留。

## 结果与证据

| 文件 | 实际结果 |
| --- | --- |
| `assets-source.json` | 1469项／0失败；候选→运行全84PNG/manifest/WAV逐字节一致，完整时序/PCM/受保护资源散列通过。 |
| `assets-cold.json` | 1380项／0失败；无候选副本，权威pin与全运行资源检查保持。少89项仅为候选跨目录对照，不放宽断言。 |
| `test-source.json`、`test-cold.json` | 各3717项／0失败；原完整帧/边界/镜像/声音重启/实际四向引擎输入保护检查保持，新增v3 schema/时基/编号门禁。 |
| `cold-start.json` | 独立副本441文件；无候选，无.godot/.import/.uid，第一次图形启动前再次核为零缓存。 |
| `render/capture.json` | 真实1440×810 macOS/Apple M1 OpenGL4.1 Metal Compatibility窗口，38组／76PNG，success=true、errors=[]。 |
| `realtime.json` | 正常自动图形播放4向、0失败；右前3轮，其他各1轮，全部84/84/340/340源索引被观察到，循环更换旧声音实例。 |
| `baseline.json`、`scope-check.json` | 77ee508开始的保护快照及收尾范围核对，保背面/棋盘/生产播放器、主游戏与旧证据。 |

引擎实测4.7.2。源码和独立副本headless日志均有macOS系统证书错误，退出分别有2/5个ObjectDB实例告警；未计为脚本/资源失败，也不声称日志零警告。图形采样与实时日志无脚本/资源报错，两个本轮专用进程均退出0。未操作用户原Godot/Spine、系统鼠标、设备音频或录音。

原始Dummy音频游标与动画相位最大差各约0.27536/0.20358/0.14767/0.16433秒，如实保留于realtime.json；含异步混音/预取，不作为设备可听同步通过。精确请求相位仍沿用原测试内短暂AudioServer锁下的独立native WAV参考，12次切换/整轮/多轮相位在原2采样容差通过，没有放宽断言或改生产逻辑。

## 实际画面观察与未验

正面两向各采新1/7/41/42～51/83/84；背面各4旧时刻。每组保完整Viewport和由同一Image.get_region取得的原像素局部裁片，完整400画布及窄带收边包含于裁片，未离线叠底。报告逐项记录实际采样时间/源PTS/源编号、manifest与PNG实测散列、镜像及世界脚点。

作者已查看右前1全景、43/44/45/48/51局部、左前44/48局部及右后188抽查。左右两向主要挥棍灰弧均存在、方向对应；48到51的灰弧衰减可辨，右窄带随镜像换边；未见运行引入新的画布裁切或腿脚缺损。足前灰弧覆盖仍可见，不能由字节一致和静帧认定贴身遮挡真实性通过。采样覆盖肩甲所需帧，母版→选定候选→实际运行的完整视觉判断仍交05。BFV2-01由07针对新运行正式复验后判定，作者不关闭该项。

源x959以外无信息、右窄带渐隐消减已有信号、FX灰145/贴身过渡及前后遮挡近似、43/44同源棍头修补、灰脚/肩甲/首尾及真人连续观感和设备听感均保持原边界。负责人已选版，不继续试参或要求重复许可。本轮未重做MOV冷复建、全帧媒体生成、PCK或Windows；没有新Skill使用/修改。

## 复现与交接

在仓库根执行：

```sh
python3 bear-forehand-showcase/verify_front_v3.py --output=/tmp/bear-v3-assets.json
bear-forehand-showcase/launch.command --headless --audio-driver Dummy --script res://test.gd -- --output=/tmp/bear-v3-engine.json
bear-forehand-showcase/launch.command --rendering-method gl_compatibility --audio-driver Dummy --script res://capture.gd -- --output=/tmp/bear-v3-render
bear-forehand-showcase/launch.command --rendering-method gl_compatibility --audio-driver Dummy --script res://realtime_probe.gd -- --output=/tmp/bear-v3-realtime.json
```

本轮独立副本在`/tmp/bear-front-v3-author.Ewrlwf/bear-forehand-showcase`；从项目复制时排除validation/.git/.godot/.import/.uid/__pycache__，同一脚本原字节执行，报告写至本目录。无需候选即可核固定运行基准，缺候选的少89项在报告中明确区分；运行不依赖本机导入缓存。

提交前更新06工作流，仅提交本职责明确文件。按授权正常push一次后只读核实Gitee；实际结果由06主动交00，不因本机HEAD领先或push文本尾句推定同步。待00串行安排07定向技术/BFV2-01复验，再05真实视觉及负责人连续/听感。全部本轮CLI/GUI资源已释放，automation-3保持暂停。
