# 山寺石院棋盘：Demo 接入候选

2026-10-31。负责人从三款中选择最上方山寺石院，要求制作可供 Demo 使用的完整棋盘。候选由内置 image_gen 基于 `../../concepts/board_character_style_20261031/three-board-concepts.png` 上方方案，以及角色库 O01、O06 的手绘风格生成；未经运行接入或实机验收。

- `board.png`：推荐底图，1672×941 RGB；不含人物和主动绘制的逻辑格线；地面仍有细微石纹，边缘石块和建筑有自然接缝。
- `board-first-pass.png`：第一稿，地砖缝与逻辑格线叠加，保留过程，不推荐接入。
- `offline-grid-bear-preview.png`：离线叠加熊展示的当前待机帧与近似格线，仅为尺度和视觉评估；当前熊展示资产并非负责人提供的新角色库原图。`make_preview.py` 可重新生成，需 Pillow。

## 06 接口建议

以 `bear-forehand-showcase` 为具体适配目标。原展示把 1672×941 图片拉伸到 1440×810；当前脚点(720,441)，菱格 144×72，格线合法边界 Rect(216,225,1008,432)，展示缩放0.75。上述只是现有单熊展示坐标，不定义其他 Demo 的逻辑地图。建议复制推荐图进入独立资源位置、保留旧图用于切换，沿用程序网格，切勿把图中石纹当逻辑边界；核对 UI 遮挡、边角、角色脚点和显示对比度，尤其左上台阶与最边缘格线接近。原网格颜色/选中颜色偏绿，浅地面上的对比与风格需程序与05实机共同检查。无新增可走范围或障碍物规则。

## 检查和限制

已完整解码并检查尺寸；离线模拟叠格与现有熊待机显示，格线位于中央，人物可辨。未实际运行 Godot、未核对高 DPI/鼠标/音频、未检查新角色库透明素材或动态脚点，未检验多个单位或实际战斗；不声称生产接入、游戏验收或正式画风通过。首图左上建筑及左右边缘接近格区，尤其角色与显示内容的边缘遮挡仍需06以实际渲染确认，必要时调整绘制范围或定向修改底图。

生成提示1：Create ONE complete 16:9 environment background for an actual game prototype, expanding and adapting ONLY THE TOP PANEL (stone mountain monastery courtyard) in reference 1. Reference 2 and 3 show the desired Chinese fantasy illustration character style; do not include characters. Match the top concept's aged grey flagstone, dark rugged ink-like silhouettes, red autumn leaves and faded red cloth accents, muted warm greys and ochre, hand-painted angular brushwork. Gameplay integration constraints: fixed isometric camera, horizontal rectangular board area covering most of the 16:9 image, only subtle small-scale stone surface variations; extremely flat uninterrupted open central playing surface, no objects or markings whatsoever on it, no large emblem or central graphic, NO GRID and NO STRAIGHT GRIDLINES or regular stone tile boundaries, because grid will be drawn dynamically in engine. Stone columns and temple stairs and lanterns only at far extreme edges, never encroach on central 80% of width or central 65% of height. Keep borders visually understated, leaves sparse, no raised curbs inside field. Clear quiet space top left and top right for UI. No characters, shadows cast by characters, text, UI, symbols, logo, graphic frames, or multi-panel layout. Provide a complete view with no cropping, smooth hand-painted illustration, no pixel art; consistent lighting and terrain in one single image.

修订提示2：Edit this exact game board background to make it directly compatible with an independently drawn isometric grid. Preserve its overall composition and artwork and aged Chinese fantasy monastery style. Replace ONLY the large central courtyard surface with a continuous, broad, even, gently mottled warm grey stone or rammed mineral ground with subtle soft irregular material texture. ELIMINATE every straight line, diamond, rectangular tile joint, crack resembling a grid or repeating pattern from the full central field. No baked-in grid, symbols, patterns or emblems. Move the upper-left staircase, buildings and any foreground obstacles entirely to the extreme outer 12% edges, so the big central rectangular gameplay region from 15% to 85% width and 27% to 81% height is flat, clear floor with NO physical obstruction. Preserve perimeter red banners and stone architecture, autumn accents, and hand-painted finish. No characters, text, interface or logos. Full 16:9 single scene.
