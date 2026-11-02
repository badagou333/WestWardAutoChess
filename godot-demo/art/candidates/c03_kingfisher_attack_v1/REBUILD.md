# 冷复建和冻结清单核对

本目录 `manifest.json` 是新的仓库相对路径映射：`frames/` 中 98 帧以原 0 基索引排序，其中 30、31、32 采用此前局部试验，其他帧与原候选一致。它明确记录每帧的冻结散列、原候选散列、原冻结路径、PTS 和样本时长。`evidence/frozen-manifest.json` 按原字节保留，SHA-256 `4d49afdbc42d29eb2bea3a6c071e8dc1a63ac11702c384d86ff102275b9f5d2b`；其中路径是原独立包位置，不是本仓库可用路径，应通过本目录 `manifest.json` 映射。路径改写后新 manifest 不再声称有同一整体散列。

```sh
C3_PYTHON=/path/to/python C3_FFMPEG=/path/to/ffmpeg \
C3_VIDEO2D_SCRIPT=/path/to/video2dsprite.py \
./rebuild.zsh /absolute/path/to/new-temporary-output
```

目标必须不存在且位于本候选目录之外。脚本检查源视频、WAV、QA 报告及所有候选帧散列；FFmpeg 解码到临时目录并按 showinfo 对照每帧源 PTS/时长，再使用原自定义浅色背景处理和 video2dsprite `clean --key-mode none` 透明帧传递，还原原始 98 帧并逐帧检查原散列；随后只对第 30–32 帧应用已冻结的局部透明度步骤，逐帧校验全部冻结散列，复制 WAV 并校验。不会生成额外预览或修改候选。若依赖版本或解码结果不同造成散列不一致，脚本报错停止，不能当作通过。

2026-11-02 冷复建实测：98 张原候选帧及冻结帧字节、逐帧 PTS 和样本时长、所选 WAV 散列全部一致。环境为 Python 3.12.13、Pillow 13.0.0、NumPy 2.5.4、SciPy 1.18.1、FFmpeg 7.1；本机 video2dsprite.py 的 SHA-256 是 `bb2390cd17d9940428fb6ca589cb4163f24e76c55c234b30f7e2d75ab60447ba`，该 skill 是独立安装的外部依赖，未随候选分发。其他机器必须自行提供兼容依赖；无法保证跨版本 PNG 字节一致。原 skill 提取步骤当时因缺 ffprobe 失败，当前解码使用 FFmpeg showinfo 回退，不声称 ffprobe 提取成功。原 QA fail 报告在 `logs/` 原样保存；冷复建产生自己的报告到临时输出，不覆盖历史证据。

`source/audio-acceptance.md`、`source/audio-processing-record.md` 是前期音频来源历史记录，其中路径和其他对照文件名称指当时独立工作区，未包含在本候选内；当前仅选定的 WAV 随包保留。`evidence/FROZEN-HANDOFF.md` 与 `evidence/HANDOFF.md` 同样原样保留当时路径和历史状态；以本目录的现时交接和 `manifest.json` 为准。
