> 2026-10-29：本旧系列素材已按负责人确认清理；以下仅为删除前历史记录，图像和重建入口不再保证存在。

# 山野猎户：像素射箭攻击候选 v1

> **2026-10-26 复审纠正。** 当前状态：视角基线不符，待返工；本包误用旧造型／动作参考，旧局部通过结论不适用于现斜向棋盘。 方向依据与返工门槛见[系列说明](../README.md)。下文保留原制作与检查历史，图片尚未返工。

## 历史制作记录（当前用途通过结论已撤回）

更新时间：2026-10-26。职责：05｜美术 / 角色 / UI。

历史局部状态（当前用途通过已撤回）：**原独立reviewer已复看修稿并关闭尾/箭/前脚三项，本批6姿势限定通过，素材冻结**。结论由root于2026-10-26转达并授权登记，证据见`validation.json`；不代表真人连续观看或运行采用。本轮只做攻击，不做受击、走路或其他角色，不改游戏、公共引擎或Git。

## 交付入口

- `preview.gif`：正常时序1760ms（动作1460ms＋展示待机300ms）。
- `preview_slow.gif`：半速3220ms（动作2倍时长，额外待机仍300ms）。
- `continuity_review.png`：最终6张真实身体姿势的完整448px接触表。
- `contact_sheet.png`：全部12时刻，含四飞箭位置及重复ready；不能把这些时刻算成12张新身体。
- `review_bow_hands.png`：当前准备持箭、搭箭、满弓、释放、抽箭局部3倍检查。
- `frames/`、`atlas.png`：6张真实姿势，448²、RGBA二值透明、全组96色。原`06_lower_arrow`已不采用、未留在frames中。
- `spec.json`、`manifest.json`、`structural_report.json`：最终明确来源/锚点/轨道/哈希与结构结果。
- `source/provenance.json`：身份参考、完整实发提示词、原PNG hash与逐RGBA验证的无损WebP原件。未采用整张只记hash/原因，不重复囤PNG。

## 身份与当前动作

唯一造型参考是已认可 `art/concepts/wild_hunter/nine_sols_archer_v1/wild-hunter-archer-candidate.png`：棕白兽脸、斗笠、苔绿衣、环纹尾、木反曲弓和背后箭袋。棍僧细节像素图只作风格参考，不带入其脸、赭黄服或长棍。左/前手持弓，右/后手管箭及拉弦，禁用旧猎刀。

最终6姿势：

`ready → 低位搭箭 → 抬弓持满 → 释放随动 → 伸手至箭袋 → 显露整箭抽出 → 复用同ready完成下放/回稳`

放箭后不会凭空补箭：先伸手、再见一支整箭、再带箭回腰。原反向短箭回稳帧06被排除，ready承担回腰终点，真实身体数如实由7降为6；不另生一个相似ready。原sheet右上箭长不稳的半拉姿势也不采用。

## 三项独立必修的处理

1. **尾根**：只局部采用imagegen无箭手/左侧尾部底稿修ready，六个采用姿势的尾均从屏左后髋伸出，不再整条换胯侧。新工具原件右panel丢尾，未采用；不以生成成功放行该panel。
2. **整箭**：准备/回腰复用同一180px生成箭素材，在衣服前、握箭手后合成，箭尖始终向右略向下12°；抽箭仍向右。原近180°翻向和半长箭不再进入轨道。独立飞箭也统一180px，与身体满弓/抽箭的约175～180px可见完整箭同量级，580ms发出、660ms后无箭层。
3. **前脚**：只在348～407px低腿区作最近邻局部注册、渐变连接脚踝，不做整个人平移或单帧高度拟合。最终按独立同口径区域`x>=180,y390..404`，六帧鞋底x均值范围229.78～230.60，最大差0.82px，脚底最大y均400；见`author_continuity_metrics.json`。下弓梢与脚踝原本重叠，低区重叠画面一同注册避免切出透明缝；握弓手、弦点和上弓在该脚部区之外。数值对齐不替代独立自然度判断。

## 来源与重建

原身体都由同一0.66源尺度提取。局部修正后保存为固定448px格的无损注册strip，最终公共引擎以**统一1.0**作原像素包装；这不是给各身体重新拟合高度。源图完整bbox/seed及上游.66记录保留在`source/spec_before_continuity.json`；最终spec仍逐身体明确bbox/seed。

当前重建（有Pillow、NumPy的Python）：

```sh
python3 /absolute/path/to/pixel_attack_series_v1/wild_hunter/prepare_continuity.py
python3 /absolute/path/to/pixel_attack_series_v1/tools/build_attack.py --spec /absolute/path/to/pixel_attack_series_v1/wild_hunter/spec.json
```

`prepare_sources.py`保存最初作者版上游局部箭部准备流程，**不是当前最终spec入口**。最终流程从保存的无损baseline、imagegen无箭手/尾底稿和生成箭素材重建，不需重新调用模型。所有生成原件存WebP `lossless=True, exact=True`且逐RGBA相等；原PNG文件hash和解码RGBA hash见provenance。

## 验证边界

作者重新查看全部6张单帧、最终姿势表和必要细节，未再见原三项跳变、断弓、断腕或局部透明缝。两实际GIF全解码为11编码帧（12请求时刻中相同ready相邻合并），时长1760/3220ms，首尾同ready；结构结果6个不同身体、96色、二值alpha，叠加不改身体像素。`playback_review.json`明确这是实际文件解码与顺序选帧检查，**不是真人实时连续观看**。

完整逐姿势、失败修正及限定独立结论见`REVIEW.md`/`validation.json`。本轮独立门槛通过后冻结；最终画风认可、真人体验、游戏箭矢命中/运行接地/镜头以及其他方向均未验。包受父目录`.gdignore`隔离，不进入当前游戏导入/导出。
