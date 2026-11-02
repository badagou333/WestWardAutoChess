# 熊山君正面攻击 v3：恢复源残影并柔化右缘

2026-11-02，D-20261102-002。负责人观看 [收边前后棋盘对照](review/board-compare.mp4)（左旧、右新）后明确回复“嗯，没问题，就用这个”，选定右侧24源像素渐隐方案。本目录为已选素材候选，**尚未接入运行，BFV2-01尚未关闭**；06接入后仍须07定向独立和05真实渲染复核及设备听感。

## 内容和输入

- 84张 `frames/attack_0001.png`～`attack_0084.png`，均保留原源第10～93帧的真实PTS/duration，时基1/15360、视频3秒、末帧0.05秒；不插帧、不丢帧。
- 源：[`../bear_lord_tail_trim_20261101/forehand-head-tail-lossless.mov`](../bear_lord_tail_trim_20261101/README.md)，SHA-256 `d37dffe785d83306c0f41f54b12348d0043f189bcf91251659816e291be548c0`。不可用其他版本替代。
- 依赖：[`../bear_lord_front_attack_v2/`](../bear_lord_front_attack_v2/README.md) 的84张PNG、manifest及WAV，保留其43/44帧同源棍头修补；v2不能删除。本批没有重新绘制角色。
- 固定输出400×320、脚锚(177,213)、源锚(500,675)、统一scale 0.337662及translation(8.169,-14.92185)，展示倍率0.75；源视频音轨44.1kHz双声道132280采样，与v2 WAV逐字节相同。
- `manifest.json`的`source_video`及`source_candidate`均相对于**本候选目录**，是来源记录；如06将manifest平铺复制至运行目录，不应将这些记录当运行资源路径解析。旧`status`是素材生成时快照，不覆盖负责人选版事实或表示运行已验。

## 残影与右边缘

原v2以深色/有色像素作为主体种子，将浅灰残影当背景去除；43/44修棍的局部替换也会擦掉先合入主体的FX。本批从同源MOV新38～51帧的亮度差估计软alpha灰弧，独立置于v2角色层之后，保留其原时序与淡出；未绘制新光圈。

源片本身新43～49帧的弧线在源x=959被画面边缘截断，此处映射至输出x约332，距400宽右边界约68像素。为减轻直边，仅FX层源x=936～959按smoothstep渐隐，38～51一致施用以避免开关突变，实际差异帧42～51；经缩放变化仅输出x=324～331。24像素是本次12/24像素对照中最小明显改善，不声称绝对最小；渐隐削弱窄带已有源信号，**没有补回源画外内容**。

作者静态审阅深/浅背景、棋盘和43～49关键帧，主弧保留、直边减轻；隐藏浏览器曾1倍速静音播放并采看，不能替代真人连续观感。原源混色导致灰145为估计，主体附近约12源像素FX过渡有所损失，腿脚前后遮挡不能准确还原、新45孤立点是否完整恢复不确定；灰软脚部、同源补棍近似及肩甲运行链均仍待真实画面复核。源边界/宽度证据见 `review/source-edge-evidence.jpg`、`review/width-compare.jpg` 和 `review/edge-close.jpg`。

## 散列与验证

| 项目 | SHA-256 |
| --- | --- |
| 负责人选定临时manifest | `9249bcdf0d0810aac04654977f761be78445a33815f5177d202904e917f6493b` |
| 入库manifest | `53f2cd27b2678282ae8e8fa905b4ce8e46cded2623a7b9384e1c870c3b3e2237` |
| 负责人观看的棋盘对照视频 | `a9cbd59bedc8d9b11bf2f6edf3d8d679761037a648f2cc624785e02a3ca5a1be` |

两份manifest仅`source_video`和`source_candidate`由本机绝对路径换为本候选相对路径，其余字段一致。84张PNG及WAV与负责人选定候选逐字节一致；从MOV冷重建的84PNG、WAV、入库manifest共86项逐字节一致。对照视频原字节原样入库，未重新生成。收边前对照基线也用`TRAIL_EDGE_WIDTH=0`冷重建，84PNG和WAV与原临时未渐隐试验逐字节一致。核查见 [ingest-verification.json](review/ingest-verification.json)、[selected-checks.json](review/selected-checks.json)。角色层未改变，与v2完全不透明主体比较0像素变化；作用域和记录见selected-checks。

## 复建与预览

依赖Python 3、NumPy、Pillow、SciPy和FFmpeg 7.1；本机验证使用Python 3.12、NumPy 2.5.4、Pillow 13.0.0、SciPy 1.18.1。源与v2按本目录兄弟路径解析，FFmpeg通过`--ffmpeg`指定或从PATH发现。下列命令从仓库根目录执行，输出目录仅作示例，必须自行选择可写的独立位置。

```sh
python3 godot-demo/art/candidates/bear_lord_front_attack_v3/build.py --ffmpeg /path/to/ffmpeg --output /tmp/bear-v3-rebuilt
TRAIL_EDGE_WIDTH=0 python3 godot-demo/art/candidates/bear_lord_front_attack_v3/build.py --ffmpeg /path/to/ffmpeg --output /tmp/bear-v3-no-fade
python3 godot-demo/art/candidates/bear_lord_front_attack_v3/make_preview.py --ffmpeg /path/to/ffmpeg --baseline-dir /tmp/bear-v3-no-fade --output-dir /tmp/bear-v3-preview
```

复建不带`--raw`将从MOV完整解码并断言恰好84帧，视频时间表沿用v2已验证的源PTS，不从等间隔PNG猜测。FFmpeg image2打印部分non-monotonic DTS警告；解帧数量及冷复建内容通过，原PTS/duration按manifest检查。`make_preview.py`的左侧基线可由上述无渐隐命令重建，不依赖旧临时目录；新视频仅用于视觉复现，编码版本不同不保证MP4散列一致。仓库内原选视频没有重新生成。

## 后续

只用于独立单熊展示的正面两向；06显式复制本包84帧、manifest、WAV并保持3秒/0额外间隔、400宽与脚锚，背面/棋盘不变。07定向复验BFV2-01、源与实际运行时序/音画/四向切换，05检查源→候选→实际运行对应帧和残影方向/边缘/腿脚/肩甲，负责人设备实听及连续体验。作者素材审阅、负责人选版和冷复建均不能代替这些步骤。
