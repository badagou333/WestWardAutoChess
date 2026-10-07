# 狐火 Spine v3：同向步态与全身跟随

2026-10-07。负责人否定 v2 的走路姿势后制作的独立候选。本版重新制作朝左的腿部图，重绑大腿、小腿、膝部辅助骨与脚，重新编排行走、承重、起停和身体跟随。没有替换 Demo、production 或旧候选。

直接看 [前后对比与动作预览](review.html)。页面中的 GIF 由外部脚本读取同一份骨骼 JSON 渲染，**不是 Spine 录屏或 Trial 导出**。原生检查另见 [验收记录](ACCEPTANCE.md)。

## 在 Spine 里继续

选择左上角 Spine 菜单 → 导入数据 → JSON，缩放保持 `1`、勾选新项目，选择本目录的 [foxfire-v3-qa.json](foxfire-v3-qa.json)。右侧展开「动画」，点击动画行左边的小圆点切换播放；点击名称只是选择属性，双击名称会重命名。

JSON 旁的 `images` 文件夹必须一起保留。标准输入是 [foxfire-v3.json](foxfire-v3.json)；QA 输入另含 `qa_flow` 固定复核序列。两者的基础骨架与五个动作一致。当前 Trial 不支持保存或导出，因此这里仍是合法的外部输入，不是 `.spine` 工程。

| 动作 | 时长 | 用途 |
|---|---:|---|
| idle | 2.40 秒 | 双脚固定、身体呼吸 |
| move | 1.12 秒 | 两脚交替支撑的朝左小步走 |
| basic_attack | 1.40 秒 | 蓄力、0.48 秒离手、回位 |
| move_start / move_stop | 各 0.68 秒 | 按顺序挪动两脚，连接站姿与 move 第 0 帧 |
| qa_flow | 12.60 秒 | 两轮固定起步—行走—停步—普攻，12 次状态变更 |

## 本版约定

行走的参考速度约为 195.85 原图像素/秒，在 `0.085` 缩放下约 16.65 像素/秒，仅为小样匹配步长的参数，不是玩法定值。`move` 本身为原地循环；固定地面预览额外按该速度移动角色，三轮后重置画面位置。

起停是固定的预备/收步动作：起步终点对应 `move` 第 0 帧；停步需在完整循环边界衔接。没有验证任意帧打断、加减速、转向或 Godot 混合器。QA 序列的短待机段保持中性站姿，以隔离检查切换，不代表实际混合策略。

## 重建与证据

依赖 Python 3、Pillow、NumPy，需在完整仓库中运行；构建和渲染复用 v1 的解析函数，前后对比需要 v2 输入。本目录 JSON 和 images 则可单独带走导入。

```sh
python3 build_rig.py
python3 render_preview.py
python3 build_review.py
python3 check_rig.py
python3 check_flow.py
```

- [验收规则与结果](ACCEPTANCE.md)、[独立视觉抽查](VISUAL_REVIEW.md)。
- [骨架与脚掌检查](validation.json)、[固定流程检查](flow-validation.json)。
- [构建参数](rig-notes.json)、[流程定义](flow-sequence.json)。
- [新腿提示词](source/PROMPT-leg.txt)、[图像来源与哈希](source/PROVENANCE.json)。

只将本版作为动画专项候选。正式 05 视觉复核与 06/07 游戏运行验收未完成。
