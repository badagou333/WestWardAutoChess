# 翠鸟灵 C3 单向攻击候选

更新时间：2026-11-02。任务 D-20261101-002。负责人决定先保留当前效果，灰色残留待 Godot 实际显示时观察。本包是前置候选，**不代表视觉、运行或声音验收通过**，尚未接入游戏；`.gdignore` 防止整目录被 Godot 自动导入。

`frames/` 为 98 张 960×960 RGBA 帧；0 基第 30、31、32 帧使用负责人看到的既有局部修复，其余 95 帧与原候选一致。`manifest.json` 为本包相对路径、每帧散列及源时间映射；`evidence/frozen-manifest.json` 按原字节存档，原冻结散列及映射关系见 [REBUILD](REBUILD.md)。`audio/feather-selected.wav` 为负责人选定的第一版羽毛飞行音效，本批字节未变；来源与处理历史见 `source/audio-acceptance.md`、`source/audio-processing-record.md`，有关素材对外授权状态尚待核实。

`source/attack-8490-fast-accepted.mp4` 是认可的加速视频。复建说明与实际环境见 [REBUILD](REBUILD.md)：可从该视频解码重建原候选，再应用已冻结的三帧局部处理，结果与 98 帧及 WAV 散列逐一核对。`evidence/` 保留原冻结记录与最小对照，`logs/` 保留原工具结果；历史材料中的旧绝对路径仅供追溯，当前接口以本包为准。

后续试接要点、时序边界和未验项见 [HANDOFF](HANDOFF.md)。下一步由 06 试接单向，再做必要技术和 05 视觉验收；通过后负责人已授权水平镜像，不必重复询问镜像许可。
