# 山狼：斜向像素攻击

2026-10-27。SE斜前、NE斜后各6个真实头颈／近前腿姿势；SW/NW仅为镜像。作者及独立逐帧/棋盘复核通过，待负责人真人观感确认；状态以[整包状态](../STATUS.json)为准。

方向依据[rect_iso_duel_v1](../../rect_iso_duel_v1/README.md)同方向待机及必要的准备/接触图，保留该基准已披露的遮挡与几何限制，没有沿用已撤回的旧横向像素角色。两方向均使用448×448画布、(224,344)锚点；所有生成六姿源统一0.50最近邻采样，菱格固定再以0.5显示，没有逐帧拟合体量。

| 交付 | SE斜前 | NE斜后 |
|---|---|---|
| 正常速度 | [动画](se/preview.gif) | [动画](ne/preview.gif) |
| 动作半速 | [动画](se/preview_slow.gif) | [动画](ne/preview_slow.gif) |
| 全阶段 | [逐帧图](se/contact_sheet.png) | [逐帧图](ne/contact_sheet.png) |
| 分帧与时序 | [清单](se/manifest.json) | [清单](ne/manifest.json) |
| 逐帧检查 | [记录](se/REVIEW.md) | [记录](ne/REVIEW.md) |

原地紧凑咬击顺序为准备→蓄身→张口探身→合咬接触→收头→落爪→同准备。820ms动作加350ms预览间隔，正常1170ms、动作半速1990ms；第300ms接触仅是预览标记，不绑定游戏伤害。每方向7个显示阶段，准备帧复用一次，不能称为7张新身体。

生成稿三支撑脚有漂移，定向足部修图仍未达到要求，未把失败稿当通过。最终以ready为受保护目标，支撑下肢、臀尾留在原坐标，仅采用真实生成的头颈／胸部／近前腿；近前腿在2/3/4抬起，其他姿势落地。精确区域见[assembly_spec.json](assembly_spec.json)，没有局部搬动或扭曲腿爪。

最后修复包括：SE尾根缺口及截断背峰通过扩大ready臀背保护关闭；SE4足外黑弧恢复为对应ready区域；NE3/4旧腿残片定界排除；NE2肩背硬台阶由imagegen新绘小块外轮廓，完整原件归档，仅采用指定区域的轮廓带，内部身体/头耳/支撑足保留。源图实际用途和失败说明见[SE来源](se/source/provenance.json)／[NE来源](ne/source/provenance.json)，完整实发提示词同目录；原生PNG以完整RGBA无损WebP保存。

[SE足部参考](se/feet.json)和[NE足部参考](ne/feet.json)是手工标注的二维检查范围与参考点，部分遮挡或腾空不虚构落地点；它们不是三维足底、物理测量或运行命中依据。最终视觉与技术结论分开记录。

复建使用安装Pillow、NumPy的Python运行：

```sh
python3 godot-demo/art/candidates/diagonal_pixel_attack_v1/wolf/rebuild.py
```

仓库内原件、准备脚本、显式区域和包装模板足够重建，工具缓存非依赖。公共编码使用同仓库pixel_attack_series_v1/tools/build_attack.py，未借用其旧方向图片。透明身体PNG与图集是角色文件，GIF为深底检查预览；公共四向菱格/正常/半速见[审阅页](../review.html)。

仅攻击候选，没有受击或运行接入。离线逐帧与技术检查不代替负责人真人连续观感、Godot攻击距离/伤害同步/遮挡/状态切换；约30°俯角是基准意图，不作精密三维标定声明。
