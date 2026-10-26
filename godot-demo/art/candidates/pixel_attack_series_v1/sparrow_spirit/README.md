# 山雀精｜驻足挥翼与单枚风刃候选

更新时间：2026-10-26。职责：05｜美术 / 角色 / UI。状态：**全部姿势及相邻检查、独立视觉与技术复建关卡通过，无明确必修**。未接入游戏；独立范围见REVIEW.md与validation_independent.json，不代表真人连续体验。

## 查看

- [正常预览](preview.gif)：动作1050ms＋展示停顿300ms，合计1350ms。
- [半速预览](preview_slow.gif)：动作2100ms＋停顿300ms，合计2400ms。
- [全部11时刻接触表](contact_sheet.png)；[六身体图集](atlas.png)；[单枚风刃原尺寸层](fx/blade.png)。
- 逐姿势／相邻复核与失败修正见 [REVIEW.md](REVIEW.md)，实际解码和图集检查见 [validation.json](validation.json)。

## 身份与范围

造型来自[`sparrow-nine-sols-candidate.png`](../../../concepts/sparrow_spirit/nine_sols_v1/sparrow-nine-sols-candidate.png)，仅以同角色[`four-action-keyposes.png`](../../../concepts/sparrow_spirit/nine_sols_actions_v1/four-action-keyposes.png)右上攻击格作动作来源。保留褐白雀头、短喙、蓝／褐两根长头羽、靛蓝金边衣、双翼代双臂、两鸟爪；没有人手、额外手臂、弓或箭。

本轮只做驻足挥翼攻击。单枚风刃沿当前Demo的占位表现语义，不据本候选新增玩法、技能或伤害规则；未制作受击、退场、走路或新方向。

## 实际姿势和分层

| 身体 | 时间 | 内容 |
| --- | --- | --- |
| `00_ready` | 0ms | 两翼下垂、稳定双爪支撑 |
| `01_wing_load` | 160ms | 屏左翼抬起蓄势，另一翼平衡 |
| `02_cross_body_accelerate` | 280ms | 横翼过胸、展开羽扇形成加速 |
| `03_wing_release` | 370ms | 双翼外张形成释放读点，分层风刃离翼 |
| 同一释放身体 | 390／410／430／450ms | 同一风刃移向右侧并退出，450ms完全无风刃层 |
| `04_follow_through` | 490ms | 前翼下扫、收住肩胸动势 |
| `05_fold_recover` | 650ms | 两翼回落、羽扇折回 |
| 重用`00_ready` | 850ms | 回准备，首尾完整RGBA相同 |

合计**6个真实身体姿势、11个显示时刻**，不把风刃位置或重复身体算新增肢体帧。身体448×448，全部源姿势统一`0.65`缩放、96身体色、二值alpha，后爪接地点为`(145,399)`。采用显式bbox／连通seed，不平均切格、不按每帧身高拟合。

风刃是另一次内置imagegen生成的**一枚连通新月气刃**，源透明度保留；技术整理为84×70，再分别放在四张448审阅层中。每个时刻至多一层、始终在不透明身体之后，不遮改身体像素。后段裁到屏边表示同一投射物出屏，身体和翼尖本身没有裁残。370ms只是预览释放标记，不绑定游戏命中。

## 制作来源与脚点修正

完整实发提示词在`source/PROMPT_*.txt`。采用图以WebP `lossless=True, exact=True`保存，并逐RGBA验证；原PNG路径／原PNG SHA-256、保存文件哈希、RGBA哈希和被否定候选原因见 [source/provenance.json](source/provenance.json)。不重复存放两轮未采用整图。

首稿的接地爪距变化过大，收势翼下还出现可误读为手指的小片；定向修正清掉小片并收窄站姿后，又修复释放帧左翼触画布的问题。最终源图仍有小幅爪位差，准备工具只把原绘前爪／踝像素注册到共同128源像素的前后接地点间距；身体、翼与上衣区域保持源RGBA，脚爪不在动画中贴地改位。具体ROI、原接地点和位移见 [source/foot_registration.json](source/foot_registration.json)。作者已看完整单帧确认膝踝仍连接，两爪完整，没有旧脚残留。

最终实际低位爪点：后爪约`(144～145,399)`，前爪约`(227～228,398～400)`；源点与采样存在至多1px级像素差，不把这些数字当运行接地或三维力学证明。

## 重建与验证边界

使用带Pillow、NumPy的Python，在本目录运行：

```bash
python3 prepare_sources.py
python3 ../tools/build_attack.py --spec /absolute/path/to/sparrow_spirit/spec.json
python3 audit_assets.py
```

路径相对脚本和spec；保存的采用源足够确定性重建，不依赖工具默认目录或再次生成。`audit_assets.py`独立读取全部PNG、图集和正常／半速实际GIF：6张不同身体、11时刻、首尾相同、图集逐像素一致、身体与底色RGB完全保持；风刃在GIF中的近似混色最大单通道差17，RGBA分层原件保留真实透明度。

本目录由`.gdignore`隔离，未改运行资源、公共程序、伤害／攻速、场景或导出。作者结论只到可交独立检查门槛；独立复核、负责人真人实时连续观感、游戏翼尖发射点与命中同步、其他方向和设备仍须分别确认。羽片分组和衣缘纹样有有限重新绘制差异，不称逐羽一致或商业成品。
