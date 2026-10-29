# 熊山君背面普通攻击 · 完整时序透明候选 v1

更新时间：2026-10-29。05素材候选；06负责四方向播放器。素材来源为**用户认可的现有视频**，本批没有生成、重绘、补帧、改衣服颜色或购买素材。

## 认可输入与既有修复历史

- 认可文件：[source/bear-back-short-repaired-v1.mp4](source/bear-back-short-repaired-v1.mp4)。用户在当前会话看到此版本后确认“对，是这个”。它是背面视角，不是正面反手 `backhand.mp4`。
- SHA-256：`30ef7c2cf59580e9b257300cd884fda4fa10359490389f98553889cbe97c1682`。
- 原保存位置：`/Users/leqiong/.codex/visualizations/2026/10/28/01a1836a-01de-7063-b18b-4df8bcd9f3b6/bear-back-short-repaired-v1.mp4`，与 `/private/tmp/bear-back-20261029-edit/back-short-repaired-v1.mp4` 相同。
- 来源会话：`01a1836a-01de-7063-b18b-4df8bcd9f3b6`，标题“05｜美术 / 角色 / UI（续7）”。原片来自此前LibTV工作；前一轮已整体缩小约23%、压缩蓄力并同步原声。约1.6秒棍头出画曾按用户要求用同源邻帧棍头裁片旋转、合成修复，当前认可输入已经包含该修复。本批保留它，不再重新修棍。
- [source/prior-manual-repair.js](source/prior-manual-repair.js) 是**既有修复的历史记录**，仍包含当时临时路径，不是本批的入口。本批可复建入口直接使用已归档、散列固定的认可MP4；不依赖临时源或其他会话。
- 用户此前已注意到双白底；它来自旧缩放后的内外背景。灰挥击弧还与下摆、腿脚重叠。本批针对这些问题分离背景并做有限去污染。

## 输出与06接口

| 项目 | 本批结果 |
| --- | --- |
| 输入视频 | 960×960，完整解码340帧，时间基1/12288 |
| 帧时刻 | 所有340个原始PTS均保留；步长128 ticks，第一帧0秒，最后一帧3.53125秒 |
| 视频轨结束 | 43520/12288 = **3.5416666667秒** |
| 输出 | `frames/attack_0001.png` … `attack_0340.png`，直通道RGBA，384×320 |
| 脚锚 | 输出 `(177,213)`；源固定锚 `(471,711)` |
| 全动作变换 | 源统一缩放0.35，统一平移 `(12.15,-35.85)`；无逐帧裁切、伸缩或锁脚 |
| 展示倍率 | 建议0.75；首帧可见高158×0.75 = **118.5px**，与现正面约118px对应 |
| 原方向 | `source_sign:1`，`source_back:true`；静止朝屏幕右上 |
| 镜像 | 运行程序围绕脚锚水平镜像；不倒放时间、不复制一套新动作帧 |
| 循环间隔 | 建议0.35秒；一次总周期3.8916666667秒 |
| 音轨 | `audio/source-track.wav`，32kHz双声道16-bit PCM，从视频0秒对齐 |
| 有效音轨长度 | 115968采样，**3.624秒**；声音尾部落在上述循环间隔内 |

[manifest.json](manifest.json) 为素材权威元数据：`canvas`、`foot`、方向标记、源变换、全部帧源编号/PTS/时间/持续时间/PNG散列、原声信息。`frames[*].file` 是PNG文件名，候选中位于 `frames/`；06可以将PNG与manifest平铺复制到运行 `art/back/`，不更改文件名或帧时刻。运行的 `clips.json` 负责具体视频时长、循环间隔、显示倍率和音轨路径。

所有原帧均交付；编码中许多相邻画面是旧视频的重复姿势或仅有压缩差别，**340解码帧不意味着340个独立运动姿势**。本批没有用重复图冒充补帧，也没有抽掉快速挥击帧。

## 时间与音频证据

- [source/video-showinfo.log](source/video-showinfo.log) 保存FFmpeg完整逐帧PTS与duration；没有使用FFprobe。
- [source/mp4-track-times.json](source/mp4-track-times.json) 保存源MP4的mvhd、mdhd和edit list解析结果。容器呈现长度3.624秒；视频mdhd为3.5416666667秒。AAC媒体含priming，不能把其原始mdhd长度直接当播放时长。
- [source/audio-ashowinfo.log](source/audio-ashowinfo.log) 保存AAC解码信息。首个输出PTS=0；解码116736采样=3.648秒，其中末尾768采样（24ms、最大仅1LSB）是AAC编码尾垫。
- 按MP4有效编辑长度保留115968采样，去掉这段尾垫。没有删改可听攻击声，没有增加鼓点或音乐，也没有用旧正面音轨。
- 最终WAV SHA-256：`f22f557d3a4eac26ea8055b4cfe363374361d602e7eaf0d49c9f0718fc3bd2d3`。

## 处理方法与复建

[build.py](build.py) 只需Python 3、Pillow、NumPy和FFmpeg。建议命令：

```sh
python3 build.py --ffmpeg /path/to/ffmpeg
python3 review.py --ffmpeg /path/to/ffmpeg
```

可用 `--decoded-dir` 指定已完整解码的340张 `frame_%06d.png` 缓存，但默认流程自己从入库MP4重新解码，临时缓存不需要归档。执行前确认Python可导入Pillow/NumPy。本机验证使用FFmpeg7.1及Codex依赖Python；不把本机临时工具路径作为交接依赖。

关键处理：

1. 原分辨率建立深色/彩色主体种子，闭合小缝并保留银甲内部。真实手臂负空间另行去除；不是把所有银灰色删除。
2. 仅在轮廓窄带参考邻近可靠主体色，拟合浅底混色并保留软alpha。深层衣服、银甲和毛发原RGB保留；缩放在预乘空间完成，最终导出直通道RGBA。
3. 原第152–172帧的弱对比脚轮廓采用本片新测的局部多边形保护；152–192帧的下摆/脚部做灰弧去雾估计。参数按原时刻插值，按像素亮度和色差限制，保护暗脚与米色绑带。**没有复制旧20帧正面脚部蒙版。**
4. 统一缩放和平移，保持所有源运动；不逐帧调整身高和脚点。

## 预览与验证

- [review/all-frames-dark-light-board.mp4](review/all-frames-dark-light-board.mp4)：全部340时刻的深底、浅底和棋盘对照，带有效原声。
- [review/all-frames-board.mp4](review/all-frames-board.mp4)：1440×810棋盘、单角色、实际展示尺寸、原声；无战斗逻辑。
- `review/all-dark-01..09.jpg`、`all-light-01..09.jpg`、`all-board-01..09.jpg`：所有340帧的检查页。
- `review/critical-source-dark-light-1..3.jpg`：源152、157、161、165、169、173、177、181、185帧与深浅底同尺度对照，覆盖灰弧出现和修补棍头。
- [review/qa.json](review/qa.json)：逐帧文件散列、边界/时刻验证、源主体边界、尺寸和音频信息。
- 棋盘使用当前独立项目 `bear-forehand-showcase/art/forest-board.png`，SHA `7b568eb54ad25d18efa7dab24adcce833a4528940fdd615ca053196cd6ad1ed6`；未选择其他棋盘。

作者检查：340条源帧/PTS逐一匹配；PNG散列匹配；RGBA画布统一、非空、输出四边透明；源主体联合边界 `(197,116)–(931,711)`，最右距960源边29px。手工补过的第157帧棍头在认可源与透明输出中均完整保留，未用增加透明padding掩盖源截断。

05已查看全部深底检查页、关键源/深浅底及棋盘对照，并批准复制到四方向独立展示；实际窗口四向总览及1.625秒背面两向抽检未见新增裁切或白底。07从入库MP4在隔离目录重新生成全部340张PNG、manifest及WAV，与交付字节完全一致，原声与源有效PCM逐采样相同；运行、按钮/快捷键、时序、镜像脚锚与干净首启检查通过，详见[独立验收报告](../../../../docs/release/QA_BEAR_FOUR_DIRECTIONS_20261029.md)。这些是素材/技术与图形抽检结果，完整连续观感和设备听感仍待负责人体验。

限制：源灰弧已经和下摆/腿脚混合，去雾是有限近似，不可能还原被覆盖的全部纹理；挥击段仍保留源运动模糊与少量灰软感。没有生成新纹理来伪造恢复。游戏内约118px高度的连续观感以最终运行复核为准；数值通过不等于无瑕疵。MP4预览用于素材检查，运行时序以manifest与06配置为准。

本目录有 `.gdignore`，不会自动作为Godot运行资源；06已显式复制必要PNG、manifest和WAV至独立 `bear-forehand-showcase/`，只展示单熊四向攻击。原试玩的战斗逻辑不属本批范围；本批由父任务统一提交，另一个会话的旧文件清理独立保留。
