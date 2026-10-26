# 山野猎户：像素射箭攻击候选 v1

更新时间：2026-10-26。职责：05｜美术 / 角色 / UI。

本轮仅制作山野猎户的独立射箭攻击，不制作受击、走路或其他角色，不改游戏。当前为**独立视觉发现箭/尾/前脚三项必修，正在局部修复，未通过**，不是负责人最终认可或运行接入通过。此前作者结论由REVIEW后续独立反馈覆盖。

## 看什么

- `preview.gif`：正常时序，动作1460ms＋展示待机300ms，总1760ms。
- `preview_slow.gif`：动作时序2倍时长，展示待机仍300ms，总3220ms。
- `contact_sheet.png`：全部12个视觉时刻，包括独立飞箭移动；不把重复身体时刻算作新姿势。
- `review_bow_hands.png`：搭箭、满弓、释放、取箭的局部3倍最近邻检查。
- `frames/` / `atlas.png`：7张真实身体姿势，448×448，RGBA二值透明，共用96色色板。
- `spec.json` / `manifest.json` / `structural_report.json`：显式来源、脚锚、轨道、哈希与实际结构结果。
- `source/provenance.json`、五份完整实发提示词与无损WebP原件：来源及定向修正记录。未采用两轮整张原件不重复保存，保留原PNG/解码RGBA hash及未采用原因。

## 唯一身份与动作

身份依据已认可的 `art/concepts/wild_hunter/nine_sols_archer_v1/wild-hunter-archer-candidate.png`，SHA见provenance；仅以负责人选用的棍僧细节像素稿作绘制风格参考，不带入其脸型/赭黄衣/长棍。

保留棕白兽脸、斗笠、苔绿衣、环纹尾、木反曲弓及背后箭袋。左/前手持同一弓，右/后手管箭和拉弦；禁旧猎刀。7个实际姿势为：

`ready → nock → full_draw → release → reach_quiver → extract_arrow → lower_arrow → 复用ready`

搭箭时箭已在后手，放箭后先伸手到箭袋，再显露抽出的一支整箭，最后放低回准备，不用凭空补箭。原sheet右上半拉弓因箭长不稳定被排除，不进入最终轨道；动作从低位搭箭直接抬到满弓，不冒称已补细密逐帧插值。

## 取样与局部修正

所有**身体源**共用0.66源尺度，不按每帧高度拟合；逐姿势完整bbox＋显式seed提取。共同锚为 `(104,399)`，源支点取后方左靴鞋底，栅格误差≤0.5px。源姿势包含前脚站姿及尾摆变化，不据锚点相等宣称双脚锁定或全身运动已经物理验证。

搭箭阶段还做了一次箭身/箭头的小掩码修正：创作像素仅来自保存的imagegen局部改稿，`prepare_sources.py`只把箭部掩码注册到原源像素平面，未将新整身稿替换角色。源脚锚和0.66尺度不变，掩码外原源RGBA保持，证据见 `source/nock_patch_report.json`。

独立飞箭由另一次仅箭素材定向修稿生成，修掉初稿过大的箭羽，标准化为200×15px再放在448画布中；不是身体单帧变比。四个显式20ms位置放在身体后层，580ms释放、660ms后完全无箭层。后两个位置的箭自行飞出视口造成的截断是投射物出屏，身体/弓/源姿势均未裁残。箭事件只是预览元数据，不发游戏伤害。

## 重建

在有Pillow、NumPy的Python中执行：

```sh
python3 /path/to/pixel_attack_series_v1/wild_hunter/prepare_sources.py
python3 /path/to/pixel_attack_series_v1/tools/build_attack.py --spec /absolute/path/to/pixel_attack_series_v1/wild_hunter/spec.json
```

第一步从保存原件重建局部补丁与飞箭后层，第二步使用公共引擎输出身体帧、图集、预览、接触表与报告。生成源采用WebP `lossless=True, exact=True`，逐RGBA比对通过；保存原PNG文件hash和解码RGBA hash。重建不依赖再次调用生成模型。

## 验证与限制

逐姿势/相邻姿势的作者记录和失败修正见 `REVIEW.md`。公共引擎及两份实际GIF均已完整解码：7身体、12时刻、7个不同身体hash；首尾完整RGBA同一ready；身体叠加后像素保持，帧内不透明颜色96，身体均在画布内。`playback_review.json`记录实际正常/半速解码时长，**这不是真人实时连续观看**。

本轮作者未见需要继续改稿的明确断弓、双弦、多箭、多肢、握持或局部接缝必修；待独立复核，重点仍应看搭箭到满弓的动作跨幅、前脚/尾摆、握弓手与箭的读法。不宣称解剖/力学精确、真人体验或游戏箭矢命中已经通过。

此包处于父系列`.gdignore`隔离范围，仅候选资产；不改运行资源、数值、场景、导出或公共引擎。后续只按独立发现做必要定向修，不直接开启其他角色。
