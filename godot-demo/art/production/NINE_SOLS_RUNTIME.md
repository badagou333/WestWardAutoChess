# 新版手绘运行包 · 2026-09-30

06按D-012/D-013加工接入。原始概念图、旧运行包和历史稿全部保留。此表为本批采用事实，不把技术接入写成最终动画/美术验收。

## 完整采用表

下列源路径相对于`art/concepts/`；运行路径均为`art/production/<运行键>/nine_sols_v1/`。

| 对象／运行键 | 最新采用来源 | 本批运行表现 |
| --- | --- | --- |
| 护寺棍僧 `guard_monk` | `guard_monk/nine_sols_v1/guard-monk-nine-sols-candidate.png` | 新静态造型；呼吸/移动/挥棍位移/受击/退场程序过渡 |
| 山野猎户 `wild_hunter` | `wild_hunter/nine_sols_archer_v1/wild-hunter-archer-candidate.png` | 弓箭造型，短起手/收势＋从弓侧发射箭矢；没有挥刀帧，尚无拉弦逐帧动作 |
| 药灵 `herbal_spirit_child` | `herbal_spirit_child/nine_sols_v1/herbal-child-nine-sols-candidate.png` ＋同角色 `nine_sols_actions_v1/four-action-keyposes.png` | 待机＋新版移动/施放/受击/退场四姿势全部采用；程序治疗弹体 |
| 山雀 `sparrow_spirit` | `sparrow_spirit/nine_sols_v1/sparrow-nine-sols-candidate.png` ＋同角色动作稿 | 五状态全采用；程序风形投射占位，不借此改技能设计 |
| 狐火 `foxfire_imp` | `foxfire_imp/nine_sols_v1/foxfire-nine-sols-sample.png` →05本批透明衍生图 | 新静态造型与身体所带狐火保留；程序火球，未拆出身体火焰层 |
| 熊山君 `bear_lord` | `bear_lord/nine_sols_v1/bear-lord-nine-sols-candidate.png` ＋同角色动作稿 | 五状态全采用；受击姿势后仰较大，未做正式连续补间 |
| 唐僧 `tangseng` | `tangseng/nine_sols_v1/tangseng-nine-sols-candidate.png` | 新静态修长造型，脚点移动/受击闪色，无步态帧 |
| 山狼 `mountain_wolf` | `mountain_wolf/nine_sols_v1/mountain-wolf-nine-sols-candidate.png` | 新四足静态造型＋程序移动/扑击/受击/退场 |
| 灰鼠 `gray_rat` | `gray_rat/nine_sols_v1/gray-rat-nine-sols-candidate.png` | 新投石索/石袋造型＋发射石块；无独立甩索逐帧动作 |
| 山猪 `boar` | `mountain_boar/nine_sols_v1/mountain-boar-nine-sols-candidate.png` | 新双足绿甲持锤造型＋程序过渡，不使用旧painted_v1动作皮肤 |
| 扩容地图 | `escort_map/painted_route_v2/escort-map-expanded-candidate.png` →05本批清洁衍生图 | `art/production/escort_map/painted_route_v2/background.png`；无烘焙路线标号，由程序绘制 |

## 加工与方向

- 可重建工具：仓库根目录 `scripts/build_nine_sols_runtime.py`，需Pillow。只做确定性提取/等比缩放/透明留白/打包，不重绘角色。狐火透明衍生源存于该角色运行包的`source-clean.png`，须保留供重建，但不纳入导出白名单。
- 每角色五帧256²、横向1280×256图集，落脚基准(128,218)。按手工标定的身体地面投影/体量缩放，不按武器或尾巴外接框统一身高。待机与动作源尺度单独记录；三角色12新增姿势全采用，逐姿势独立包围范围而非2×2均分。`manifest.json`保存源路径、裁切范围、脚锚点、比例及待机源SHA256。
- 狐火/山狼/山猪源朝左，灰鼠、其余角色按右向处理；运行时朝向是逻辑方向，源朝向只影响绘制。发射点单独随逻辑方向镜像，左右测试通过。
- 药灵/唐僧/狼/鼠的最大alpha254不是残底，不进行阈值清底。对打包图检查透明边距，另检查三套动作图集和全角色实际窗口截图。
- 主战场脚底锚点为零，替补席保留既有缩放；血条/点选区按新版较小体量缩短。地图未缩放成旧37格，角色与石格的运行体量见实际截图。

## 05本批衍生素材的可追溯记录

- 狐火：工具输出`exec-6d672b22-9e4e-4a8c-a57a-313ca8d08015.png`，原尺寸1199×1312 RGBA。05用图像编辑去背景/地影，保留偏左朝向和身体所带火焰；有少量线条变化、橙红更鲜明，非像素级无损抠图。该源已收编为上述`source-clean.png`，不是运行时依赖用户目录。
- 地图：工具输出`exec-0f105a6f-9f8f-412b-abdd-50b83a962de4.png`，1672×941 RGB。删除金线、A/1/2/3/B与红箭头；局部石缝/峡谷边缘有改变，已针对实际清洁图重新核对标定。不是与概念原图逐像素同几何。
- 两份工具输出来源均为05任务`01a06044-bbe6-7b31-946a-f682ea53611a`，06负责本批统一入库；05未并行修改仓库。

## 地图标定与边界

`scripts/data/escort_map.gd`用源图横/纵石缝坐标和逐行可走区间管理134格，实际显示1920×1080。四营地端点（含B）和25步主路线、出怪入口均落在合法格；下部存在连通绕行。原122格文本仅提案，未照搬。水面、峡谷、建筑/林木边缘的碎石不列入可走区。可走描边/点选/人物落点/寻路共用同一坐标；手绘弯曲石缝与矩形边界仍有少量像素偏差，不能称逐像素遮罩。UI位于左右安全区和底部，不覆盖主路线操作点。

## 未采用项与原因

- 猎户旧近战造型/挥刀动作：被弓箭定位替代。
- 旧demo_v1、motion_v1/v2/v3及山猪painted_v1身体帧：主入口不混皮肤；原包保留供历史审核场景。
- 狐火带背景原图：保留为来源，采用05透明衍生，不在战场贴矩形背景。
- 地图v1与v2带烘焙标记原图：保留为来源；避免路线/营地/入口重复或矛盾，使用清洁衍生。
- QA合成图、配色历史、药灵未采用清底重试：不是游戏资产，不导出。
- 旧猎户/灰鼠近战发射声音：新远程事件静音，等08补弓箭/投石索素材；命中材质及唐僧警示继续使用。
- 未生成缺失姿势、未补猎犬/合围/鹰哨、未扩展新技能，不把静态过渡称完整动画。

## 验证和后续

`nine_sols_assets_test.gd`检查十包尺寸/透明留白/状态/禁用旧身体运动帧、左右发射点，以及箭/石的释放/抵达单次结算和旧近战声音禁用。`route_graphical_input_test.gd`真实窗口分发输入并产生商店、护送、全角色截图。图集静态和正常窗口复核无明显裁切、残底或身体错皮；脚点允许约数像素误差，尚非完整连续动作验收。

本批是快速可玩接入；下一步由07独立验收实际操作和占格边界，再按反馈微调体量、脚点、地图边缘。弓箭拉弦、甩索、静态角色步态与发射音效仍应由05/08专批完善。
