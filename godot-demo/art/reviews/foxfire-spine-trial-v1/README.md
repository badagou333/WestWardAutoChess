# 狐火小妖：Spine 试用评估候选 v1

更新时间：2026-10-07。任务依据：D-20261004-005。

**已交付拆层与三动作输入，并已在 Spine 4.3.26 Trial 中实际导入和播放。仍为独立候选，未保存正式工程或完成运行素材验收。**

2026-10-05最新状态：桌面接入成功，固定入口为 `/Users/leqiong/Applications/SpineTrial-Codex.app`。独立副本仅补应用标识，其余程序与资源内容和原安装一致；原安装保持不变。已实际验证狐火导入、idle/basic_attack/move 播放、release事件与移动循环。方法、证据和限制统一见[原生接入记录](NATIVE_ACCESS_20261005.md)，交接见[09工作流](../../../../docs/workstreams/09-spine.md)。此前[兼容性诊断](NATIVE_DIAGNOSTIC_20261004.md)为历史记录。

## 最新修正：原生导入后头身错位

2026-10-07已修正12个附件的尺寸表达：原图width/height加显式scaleX/scaleY，避免Spine读取PNG原尺寸后衣身膨大、头部偏小。已在原生编辑器重新导入并复验Setup及三个动作，窗口中的修正版为 `foxfire-aligned-20261007`，旧骨架保留但隐藏。当前JSON路径不变，205项检查及贴耳回归通过。详情见[尺寸修正与原生复验](NATIVE_ALIGNMENT_20261007.md)。10月5日仅验证接入和播放，漏检了这项尺寸问题。

## 最新定向修正：蓄力火舌与耳侧分离

05对e4e0d6d只读复核回传：身份/近游戏尺寸可辨，所查头颈/腕口/尾根无明确露洞，释放/离掌/收势可辨；但0.28～0.30秒火舌贴耳，列本批优先修正。此处记录回传结论，不替代05对本次修稿复核。

只新增 basic_attack 的 flame 旋转轨道：0秒0°、0.30秒+24°、0.48秒回0°、1.4秒0°，抵消蓄力时躯干/袖/手合计倾斜，火舌保持向上。未生图或改变其他输入、图片、骨架、时长和现有释放事件。起始/结束及0.48秒所有骨骼世界变换与修前完全一致，原有释放连续性断言保留。

- [0.28/0.30秒修前修后与近游戏尺寸对照](qa-charge-fix/before-after-028-030.png)；统一标记外部预览。
- [轮廓间隙证据](qa-charge-fix/clearance.json)：按alpha≥8轮廓最近像素中心的欧氏距离衡量；不是整条空白带宽度。原尺寸0.28/0.30秒从重叠改为55.15/53.04像素；0.085缩放下从6/7个重叠像素改为0，最近距离5.10/5.39像素。0.20～0.46秒每0.02秒采样均无重叠，最小距离5.10显示像素。
- 外部基础检查现为179项通过（旧177项全部保留，新增旋转轨道两项检查）；定向脚本另核对仅预期轨道改变、释放与端点不变、指定时刻及蓄力段间隙。
- qa-charge-fix/before-input.json仅为e4e0d6d审计快照，不是当前推荐导入入口。当前JSON和GIF已在原路径更新。
- 05已在6cf1edf限定复核关闭贴耳问题；2026-10-05已完成当前输入的原生导入与播放，详见上方接入记录。

**仍未解决**：走路0.24→0.28/0.48/0.72秒整腿平移、膝部刚性；idle0与move0脚位变宽，接入前需验证过渡混合。本批不扩展这些问题，不称正式步态或动画通过。

## 看什么

- 打开 [review.html](review.html)：三段 GIF 与来源/复组对照。所有动画标注为外部输入预览，不是 Spine 录屏。
- [qa-reassembly.png](qa-reassembly.png)：左侧当前 Demo 来源，右侧生成拆层后的复组。
- [qa-motion-contact.png](qa-motion-contact.png)：三动作关键时刻。原始坐标系下由外部检查器重组，非编辑器截图。
- [qa-game-scale.png](qa-game-scale.png)：待机/普攻释放/移动起始姿势，沿用运行 manifest 的 0.085 源图缩放；每槽 256×256。这是尺寸近似检查，不是实机截图。
- [foxfire-external-4.3.json](foxfire-external-4.3.json)：独立编写的 Spine 4.3 数据输入，保留相对 images 路径；不是 Trial 保存或导出的文件。

## 制作与来源

唯一人物基准为[当前Demo来源](../../production/foxfire_imp/nine_sols_v1/source-clean.png)，1199×1312，朝左。
原件保存为 source/original.png，SHA-256：
`873e97b812f7363449efc7981323a7046f5d75ee40dca3d58376ec79b12ff6ae`。

本次使用内置 imagegen 两次：

1. source/parts-sheet.png：以原件生成分离部件及遮挡端补画；完整提示词 [source/PROMPT.txt](source/PROMPT.txt)。生成文件标识 exec-087b6164-e74a-4f41-a5f2-4ca70b80eaa4.png。
2. source/torso-corrected.png：初版衣身带入裤形，专门修正为衣身/裙摆附件；完整提示词 [source/PROMPT-torso.txt](source/PROMPT-torso.txt)。生成文件标识 exec-e656878c-947d-4dde-969b-ed4c36c75b5c.png。

生成不是逐像素抠图，细节与比例仍有漂移。保留白狐、赤围巾、暗袍、金边、橙白大尾和橙火的来源身份；不能据此宣称与原稿完全相同。未引用旧版狐火或其他角色。

images 中有11张独立RGBA：头、衣身、尾巴、施法袖、施法手、下垂袖、下垂手、后腿、前腿、围巾尾、狐火。袖子与腿均为完整刚性部件，尚无肘/膝分段或网格权重。

build_sample.py 只按明确矩形提取生成像素、设置附件大小/位置、编写数据及进行外部仿射复组；没有用 Python 绘制或补画人物。裁框按 alpha≥8 定界并保留3像素边缘，框内原 alpha 不变；未做清底重绘或色彩替换。实际裁框、来源和对齐均在 parts-layout.json，验证逐像素匹配。复组采用独立附件缩放，原始拆层PNG不重采样覆盖。

## 骨骼与三动作

输入包含13根骨骼（root + 11部件 + projectile）、12个槽、default skin。projectile 复用狐火图，不增加美术对象；root位于来源坐标(610,1255)，Spine坐标向上为正。骨骼父节点排在子节点之前。

衣身带动头、肩袖、尾巴、围巾；手跟袖，掌中火跟施法手；双腿独立挂root以避免呼吸抬起脚底；释放火挂root以脱离手的收势。绘制顺序固定在JSON slots，后尾/围巾/双腿在衣身后。

| 动作 | 时长 | 设计与边界 |
| --- | --- | --- |
| idle | 2.0秒循环 | 身体轻呼吸、头/尾/围巾错时小幅变化、掌火伸缩；双脚固定 |
| basic_attack | 1.4秒单次 | 0.30秒蓄力、0.48秒释放、0.95秒前离手火淡出、1.4秒回到起始姿势；release只做视觉标记 |
| move | 1.0秒循环 | 两腿相差半周期，支撑脚贴地，摆动腿抬42源像素；身体/袖/尾有独立变化 |

均为本次独立样例的时序提案，不是游戏攻速、移速、伤害或新技能决定。JSON循环需在编辑器/播放器选择；basic_attack的GIF为方便观察重复展示，不表示游戏中无限循环攻击。

移动为原地循环，参考向左移动速度220源像素/秒（按0.085缩放约18.7显示像素/秒）；输入没有root位移。实际游戏速度和动画相位需06另行对齐，不擅改现有玩法移速。由待机直接跳到走路起始姿势存在脚位差，后续须验证过渡混合，当前未验证动作切换。

## 实际软件能力与导入

- 固定入口已成功连接，编辑器为 **4.3.26 Trial**。原生导入、Setup显示与三动作播放已验证；未在编辑器中重新制作绑定。
- Trial不支持保存、纹理打包或导出；本批未保存 `.spine`，没有原生录屏。现有GIF仍为独立生成的外部预览。
- 再次导入：主菜单 → 导入数据 → 本目录 foxfire-external-4.3.json，比例1、新项目，保留 images 相对路径。
- 动画模式中点击动画行左侧圆点激活，核对 Dopesheet 名称；idle、move开启循环，basic_attack关闭循环。详细操作要点见[原生接入记录](NATIVE_ACCESS_20261005.md)。
- 关节细查、近游戏尺寸视觉验收和动作混合仍需专项推进；编辑器内未记录的修改不能依赖Trial保存恢复。

输入只用区域附件、简单旋转/平移/缩放/alpha和事件，避免4.3新约束差异。已核对4.3官方读取结构：旋转与alpha关键帧使用value，平移/缩放使用x/y，skins为数组。未复制或分发Spine Runtime。

## 验证及待审核

[validation.json](validation.json)：当前205项外部结构/几何/媒体检查通过。包括来源不变、裁图像素与生成原件匹配、alpha留边、父子和附件路径、关键帧时序、三动作端点、释放瞬间掌火/投射火矩阵一致、待机脚不动、参考位移下支撑脚数值稳定、GIF解码及25fps时长一致。

外部检查不替代原生验证；本轮另行完成了当前版本的实际导入和播放，但不代表步态质量验收通过。已看来源/复组对照、三动作选帧及近游戏尺寸：未见大块残底，火从手离开可辨，腿确实分别运动；头身比例、袖口形状、围巾/腰部细节与原稿仍有差异。蓄力贴耳问题已定向修正并由05限定复核关闭；刚性腿与袖的弯曲、脚掌着地观感和移动衔接仍需后续验证，不能称正式动画完成。

## 重建

在有Pillow和NumPy的Python 3环境执行（NumPy用于定向轮廓距离检查）：

```sh
python3 build_sample.py
python3 validate_sample.py
python3 check_charge_fix.py
```

本机使用Codex提供的Python/Pillow，没有安装新依赖。输入与预览可由以上脚本重建；原件及两次生成图不能由脚本重画。修改时先保留基线，校验仍只覆盖外部数据。目录 .gdignore 隔离Godot导入；未改变production、游戏代码、PCK清单或其他工作流。

## 官方参考

- [Trial限制](https://esotericsoftware.com/spine-download)
- [Import Data](https://esotericsoftware.com/spine-import)
- [JSON格式](https://esotericsoftware.com/spine-json-format)
- [4.3官方JSON读取结构](https://github.com/EsotericSoftware/spine-runtimes/blob/4.3/spine-ts/spine-core/src/SkeletonJson.ts)

下一步：沿用固定入口继续动画练习与定向优化，优先处理刚性腿及动作切换，再交05视觉复核。任何接入Demo的动作都需另行安排。
