# 山寺石院棋盘：横向长方形修订

2026-10-31。负责人指出上一版整个棋盘歪斜，撤回上一版的接入推荐；此版以现有单熊Demo实际格区为约束重新生成，仍须06接入和05复核，不宣称正式运行交付。

- `board.png`：1672×941，画面中围栏横竖基本与屏幕边缘平行，棋盘主体近长方形。地面为均匀细碎石纹，没有生成逻辑菱形网格；四周山寺、红幡和秋叶。局部围栏有手绘笔触和不规则石块，非几何矢量边框。
- `layout-guide.png`：生成时用的1440×810屏幕示意，绿色框为现有Demo安全界限、线为示意，不是生成成品或新增地图逻辑。
- `offline-grid-bear-preview.png`：离线按照现有格点、较深示意线和旧单熊帧合成，仅核清场和相对位置；非真实格线样式或运行截图。
- `godot-preview.png`：临时副本替换底图后，现有Godot脚本真实图形窗口采集，显示旧单熊、界面和原格线；为单帧，不是新角色库的透明角色、真实点击/多人运行或负责人验收。

## 实际检查与交接

保持`bear-forehand-showcase`的1440×810显示、场地边界Rect(216,225,1008,432)、144×72菱格与脚点(720,441)。离线检查完整格区均在围栏内部，左上台阶未覆盖格区；中央地面没有大图案或建筑。临时拷贝原展示替换一张图，不改原展示；Godot 4.7.2 headless运行既有测试2969项0失败，图形窗口采集四方向各4帧共16张成功，未操作系统鼠标或用户原窗口。headless 输出日志目录与系统证书告警，加载PNG有Godot导出警告；本次没做导出，不能据此声称PCK可用。

真实窗口原格线透明度很低，在该浅色细纹地面上几乎看不清；现有选中格可辨。应由06结合实际画面调整格线的透明度/颜色或采用可切换的格线样式，并在多人与小屏检查，不改变格子数据或玩法。图为1672×941，展示拉伸至1440×810；非像素精确16:9但与原底图接口相同。真实角色多单位遮挡、实际新角色库图片接入、鼠标、Windows、导出与用户连续体验未验。推荐06在独立入口试接，不覆盖旧图；05再看完整真实显示。

## 来源与提示

内置 image_gen 根据 `layout-guide.png` 几何及旧 `../temple_courtyard_20261031/board.png` 风格生成一次；旧版保留追溯而不推荐。提示原文：Create a complete 16:9 Chinese fantasy game arena background. REFERENCE 1 is a STRICT layout/geometry diagram, not a style: the beige area is the flat playable stone ground; it is a SCREEN-ALIGNED HORIZONTAL RECTANGLE with EXACT horizontal top and bottom edges and vertical left and right edges. These four edges stay parallel to the image edges; four 90-degree corners; no trapezoid, no slanted outer boundary, no perspective convergence, no diamond-shaped platform, no foreshortening. The thin green rectangle marks the safe playable field: all its area must be flat uninterrupted ground, with NO stairs, decorations or obstacles. No green line in final. Do not draw the thin crisscross grid either; game engine draws grid on top separately. All architectural objects, red cloth, incense braziers, stone railings, steps and details on the OUTSIDE of the beige rectangle, around its perimeter, never intruding onto the floor. Reference 2 shows the visual aesthetic and colors, not its skewed geometry: Chinese hand-painted stone monastery courtyard, ink dark grey, warm aged pale stone, deep red accents, subtle autumn leaves, distinctive restrained paper-texture illustration, crisp attractive background. Flat orthographic game view with very subtle subdued ground texture; legibility and precise rectangular board silhouette are paramount. Symmetric aligned composition, fully visible all four sides of the rectangular stage. No characters, no text, no UI, no logos, no tiles or grid drawn onto the ground.
