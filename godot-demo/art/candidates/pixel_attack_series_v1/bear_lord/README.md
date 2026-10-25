# 熊山君｜像素双手重棍攻击候选

更新时间：2026-10-26。职责：05｜美术 / 角色 / UI。状态：**作者逐姿势复核完成，独立视觉与技术复建限定通过**。未接入游戏。

## 查看

- [正常预览](preview.gif)：1.25秒动作＋0.40秒肩侧停顿，合计1.65秒。
- [半速预览](preview_slow.gif)：动作放慢至2.50秒，停顿仍0.40秒，合计2.90秒。
- [完整阶段接触表](contact_sheet.png)；[六姿势图集](atlas.png)。
- 作者逐帧、相邻姿势和修正记录见 [REVIEW.md](REVIEW.md)。技术检查见 [validation.json](validation.json) 与公共工具 [structural_report.json](structural_report.json)，两者不代替视觉验收。

## 动作与帧

448×448统一画布；后脚承重点统一到`(90,400)`，全部完整源图只用一次`0.7`共同缩放，不按每帧身高拟合。身体为96色统一色板、二值透明；没有用残影掩盖握法或支撑问题。

| 阶段 | 身体文件 | 时间 | 实际内容 |
| --- | --- | --- | --- |
| 肩侧准备 | `frames/00_ready.png` | 0ms | 双手握同一根钉头木棍，宽站姿 |
| 沉身转髋蓄力 | `frames/01_load.png` | 180ms | 木棍抬高，肘部收拢，前脚保持准备位 |
| 抬前脚内送 | `frames/02_step.png` | 270ms | 蓄力上身保持，真实新绘弯腿／抬爪覆盖，腾空后再落脚 |
| 下挥加速 | `frames/03_accelerate.png` | 360ms | 转髋前送，棍头仍在高位，落脚支撑 |
| 低位重击 | `frames/04_impact.png` | 440ms | 双手向下驱动，棍头到前方低位，胸腹前倾承重 |
| 回收返步 | `frames/05_recover.png` | 650ms | 双手靠近、将重棍带回腰胸前，前脚抬起返步 |
| 肩侧回位 | 重用`00_ready` | 1000ms | 恢复准备姿势；首尾RGBA完全相同 |

合计**6个实际身体姿势、7个显示阶段**；其中`02_step`在已生成的蓄力上身上使用新绘腿部覆盖，不称新增一张完整整身重画。低位重击是本角色的沉重下挥，不套用棍僧的右上出棍。440ms仅为候选预览接触标记，没有绑定游戏伤害或攻速。

## 来源与修正

认可身份来自[`nine_sols_v1`角色图](../../../concepts/bear_lord/nine_sols_v1/bear-lord-nine-sols-candidate.png)；动作方向仅参照[`four-action-keyposes.png`](../../../concepts/bear_lord/nine_sols_actions_v1/four-action-keyposes.png)右上攻击姿势。铁灰甲、暗红腰布、重熊体量、单根木钉棍保留。

内置`image_gen`生成完整姿势组并定向修正。首张4×2候选因邻帧棍头与脚相叠未采用；第二张3×2中的加速重复接触且棍端触边，第三张将它改为完整的高位下挥。肩侧准备／蓄力缺第二只可见握手、回收握距过宽、前脚贴地改位等问题均在作者检查中发现，分别用新的局部手臂／手掌／弯腿图处理后复核。

- 完整实发提示词：`source/PROMPT_*.txt`。
- 工具PNG原路径、原PNG SHA-256、所存无损WebP哈希、解码RGBA哈希与逐像素一致验证：[`source/provenance.json`](source/provenance.json)。采用的生成原件按`lossless=True, exact=True`保存，未做有损压缩。
- 蒙版、输入裁图、固定最近邻归一与手脚注册：[`prepare_sources.py`](prepare_sources.py)、[`source/preparation_report.json`](source/preparation_report.json)。蒙版外RGBA逐像素保留；没有整体平移／旋转角色代替动作。
- 每姿势显式取样框、主体连通种子、同一缩放和锚点：[`spec.json`](spec.json)。没有平均切格，也没有把来源图的未用姿势列入动画。
- 只保留必要采用源与编辑输入。未采用的返肩握手实验只留提示词与哈希记录，不进入播放；最终直接重用准备帧闭环。

## 重建与边界

使用带Pillow、NumPy的Python，先运行本目录`prepare_sources.py`，再运行公共工具：

```bash
python3 ../tools/build_attack.py --spec /absolute/path/to/bear_lord/spec.json
python3 audit_assets.py
```

所有路径相对脚本或`spec.json`，不依赖工具默认目录；保存的原件足够确定性重建，不需要再次调用生成模型。公共manifest按引擎职责继续标结构候选；已由root收文的独立结论见`REVIEW.md`，不把引擎结构字段当作视觉结论。

本目录由`.gdignore`隔离。仅攻击候选，不含受击、死亡、完整步行、新方向、运行接入或玩法变动。六姿势仍是有限帧动画，衣甲纹样与投影会有少量重新绘制差异；不称全视角严密解剖、严格恒定三维投影或商业成品。正常／半速帧和时间线已技术核对，负责人真人连续观感、运行命中同步与其他设备未验。
