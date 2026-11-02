# 熊山君四方向攻击展示

双击 `launch.command` 启动。棋盘上只有一只熊，右上角四个按钮或数字键 `1–4` 分别切换右前、左前、右后、左后；默认右前。选择新方向会从该组动作开头重新播放对应视频原声，先停止旧音，避免叠声。再次选择当前方向不会重新触发。没有战斗、敌人、伤害或游戏菜单，原游戏保持。

## 动作与镜像

- 正面使用2026-11-02交付的84张完整源帧，右前为原方向，左前以脚锚为中心水平镜像。保留全部非等间隔时刻，画面3秒、额外间隔0秒；末帧从2.95秒显示到3秒，不按28fps均匀重排。
- 背面原方向使用负责人确认的背面修复视频，右后为原方向、左后为水平镜像。保留340条源时刻和340张PNG（326种不同图像），视频画面3.541667秒，末帧间隔0.35秒，没有套用正面的20帧数量或战斗时长。
- 两组分别读取 `clips.json` 的视频时长、间隔、显示倍率、原始左右方向和音轨；各组manifest提供画布、脚锚及逐帧时间。镜像只改变图像的水平朝向和手持侧，不倒放动作，不改变音频声道。
- 所有方向都围绕同一个棋盘脚点 `(720,441)` 绘制，显示倍率0.75，匹配已确认的棋盘角色尺度。阴影固定于格心；动态脚底是否始终自然贴地仍需结合动作观看。

## 素材来源和限制

正面 `art/attack/` 现为负责人选定的 `godot-demo/art/candidates/bear_lord_front_attack_v3/` 的84张PNG及manifest原样复制件，对应裁剪母版新1～84／原10～93。v3恢复源挥棍灰弧，并仅在FX源右侧24像素窄带渐隐；没有补回源画外内容，也没有新增光效。角色层沿用v2，新43/44＝原52/53的同源棍头修补保留。画布400×320、脚锚(177,213)、显示倍率0.75、世界脚点(720,441)和全动作时序均保持，不逐帧重定位。源混色/贴身FX过渡及腿脚遮挡有近似，灰软脚边、棍头轨迹、肩甲与首尾连续观感仍待05实际视觉复核。v2候选作为构建依赖保留，旧证据和07失败报告不覆盖；BFV2-01待07针对新运行复验，作者不直接宣布关闭。

入库及运行manifest SHA-256均为 `53f2cd27b2678282ae8e8fa905b4ce8e46cded2623a7b9384e1c870c3b3e2237`，schema为`board-bear-front-trail-trial-v1`。其中`status`是生成时快照；`source_video/source_candidate`相对于候选根，仅供追溯，不由播放器解析。运行只读平铺PNG及clips.json指定的原WAV，无需修改生产加载逻辑。

背面交接目录为 `godot-demo/art/candidates/bear_lord_back_attack_v1/`。运行目录将该包 `frames/` 的PNG平铺到 `art/back/`，保持manifest中的文件名引用；340张PNG、manifest和WAV均与05最终候选逐字节一致。原视频为负责人确认的 `bear-back-short-repaired-v1.mp4`，图像时间轴按视频轨而非音频尾部定义。画布384×320、脚锚(177,213)；脚边残余灰软边属于源画面覆盖限制，本轮未重绘。

棋盘 `art/forest-board.png` 保持已确认林间版本，SHA-256为 `7b568eb54ad25d18efa7dab24adcce833a4528940fdd615ca053196cd6ad1ed6`；格子144×72。镜像方向和原方向使用同一纹理，不另行生成画面。

原声均按各自视频0秒开始播放，不叠加专门制作的音效。新正面 `audio/source-track.wav` 是44.1kHz双声道16位PCM、132280采样帧、约2.999546秒，与本批候选WAV逐字节相同；新0点对齐，不使用旧79采样静音垫片、旧正面或背面音轨。背面 `audio/back-source-track.wav` 仍为32kHz双声道16位PCM、115968采样、3.624秒，从0秒起，不补静音。背面尾部768个AAC填充采样已按视频编辑表移除，未剪掉有效音轨。两段音轨都在各自下一轮开始前结束。视频音轨商用授权未在本展示核实，当前仅供项目内试验；技术同步不代替实际听感。

## 检查和画面采样

使用Godot 4.7可运行 `./launch.command --headless --audio-driver Dummy --script res://test.gd`。测试包含实际两组资源、每帧时间边界、镜像脚锚、源音重启、循环、四个按钮的Control输入和数字键。输入测试在引擎视口中注入事件，不是操作系统原生鼠标验收。

当前以[2026-11-02正面v3作者证据](validation/20261102-front-v3/README.md)为准：源码与无缓存独立副本各3717项／0失败，素材source1469/cold1380项通过；验证84帧完整散列/实际纹理、原非均匀PTS、3秒零间隔／0.05秒末帧、前后原PCM和单播放器重启、镜像脚点与四向引擎输入。`verify_front_v3.py`仅用标准库，无候选的副本仍核固定权威manifest、每张PNG、WAV/PCM及背面/棋盘/播放器保护散列。可选`--ffmpeg`仅额外冷解MOV音频；本轮未使用、不重做素材作者的冷复建。

无缓存副本专用OpenGL窗口实采38组／76PNG，含正面两向各新1/7/41/42～51/83/84及背面两向各4旧时刻。正常图形自动播放右前3轮，其余方向各1轮，通过循环/重启检查；本机观测全部源索引，不将屏幕刷新率等同源时刻采样率。上述属于作者检查，不代07定向、05实际视觉及真人连续/听感。旧v2作者证据位于`validation/20261102-front-v2/`；其计数通过曾漏掉大面积残影缺失，详见`docs/release/QA_BEAR_FRONT_V2_20261102.md`。`verify_front_v2.py`保留用于历史v2基线，不能用来核当前v3运行。

```sh
python3 bear-forehand-showcase/verify_front_v3.py --output=/tmp/bear-front-assets.json
bear-forehand-showcase/launch.command --headless --audio-driver Dummy --script res://test.gd -- --output=/tmp/bear-front-engine.json
```

图形采样：`./launch.command --rendering-method gl_compatibility --audio-driver Dummy --script res://capture.gd -- --output=/tmp/bear-front-v3-render`。默认38组完整Viewport及同图原像素局部裁片，覆盖完整变换画布、残影收边/肩甲/腿脚；`capture.json`保源编号/PTS/manifest及PNG散列/镜像/脚点。追加`--all-frames`可采全部源时刻，本轮未扩全段采集。脚本拒绝headless、不完整输出及错误v3 manifest，只操作专用窗口内引擎事件，不占系统鼠标；实际画面不是离线棋盘合成。`realtime_probe.gd`另做静音/Dummy的正常自动循环观测，原始混音位置测量不等于设备输出延迟或真人听感。肩甲须由05对照母版→候选→真实运行，静态或时钟通过不替其通过。

播放器直接读取PNG/WAV，支持没有本机导入缓存的源码启动。若要导出安装包，仍需单独配置并验证原始资源的收录；本轮没有提供安装包。
