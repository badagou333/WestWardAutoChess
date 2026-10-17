# 生成提示词

日期：2026-10-17
方式：内置 imagegen；一次首图生成＋一次局部修订。未用代码、SVG、外部API绘图。

## 首图（保留为讨论候选）

参考：`../../production/directional_v1/review/formation.png`，只用于画风、角色身份与已有场景元素；不复制其矩形投影。

```text
Use case: stylized-concept
Asset type: ONE hand-painted 16:9 landscape game art concept for discussion, requested canvas 1920×1080.
Input image 1 is REFERENCE ONLY for the original Journey to the West forest-stone-platform art language and established character identities. Do not copy its orthographic rectangular board projection or its dense UI. Draw a new coherent painted scene, not a code diagram.

Primary request: show the same tactical forest stone board from a centered, straight-on frontal camera looking downward about 45 degrees. Absolutely no sideways camera yaw, no rolled horizon, no diamond or isometric rotation. Use subtle true perspective: the platform's NEAR / BOTTOM edge is only moderately wider than the FAR / TOP edge (far width roughly 86–90% of near width), symmetrical around the screen center. Long front and back edges are horizontal.

Composition: wide 16:9 clean game concept, board is the clear main subject occupying about 80% of canvas width and the middle 60% of height. Entire board, its front thickness and short central front stairs fully visible, comfortable surrounding forest margin. Keep upper and lower edges quiet for future existing HUD; do not draw complex UI, panels, text, labels, letters, numbers, logos, watermarks or invented gameplay.

Critical grid geometry: EXACTLY TWELVE COLUMNS by SEVEN ROWS, 84 playable tiles. The playable surface has 13 longitudinal boundaries (11 interior lines plus the two side boundaries), and 8 transverse boundaries (6 interior lines plus front/back boundaries). A single centered perspective projection across ALL tiles, not a rectangular grid pasted within a trapezoid. Every longitudinal line subtly converges toward the same distant point above canvas center; transverse row boundaries remain horizontal and become gradually more closely spaced toward the rear. Near tiles slightly wider and taller, rear tiles slightly smaller; continuous unbroken straight grid seams all across the low-contrast stone surface. Thin restrained seams, no checkerboard alternating colors, no extra decorative seams mistaken for cells. Clear countable grid.

Environment and material: continue the reference's restrained hand-painted Chinese fantasy forest clearing, muted mossy grey-green stone slab battlefield, soft teal distant pine woods and rocks, warm small existing corner lantern accents, visible solid front stone sidewall and two modest central steps. Consistent perspective of slab, edge stones, stairs, surrounding ground and foliage. No new architecture or obstacles, no village, roofs or pagodas. Moss and leafy plants stay at perimeter and do not obstruct tiles. Soft ambient daylight with one coherent light direction; readable mid-value low-detail board; elegant brush texture and firm stylized contours rather than photorealism.

Characters: only FIVE familiar units at separated tile centers, leaving most tiles unobstructed: LEFT friendly half contains reference Tang monk in orange-gold robe with staff further back, reference stocky black-and-white badger guard monk in ochre robe carrying long wooden staff near middle, and reference small white single-tailed foxfire imp in orange/dark robes with a small orange flame nearer front. They face toward the RIGHT enemy half. RIGHT half contains one reference grey four-legged mountain wolf further back and one reference upright brown boar warrior in dark green and bronze armour with its familiar mace nearer front, facing LEFT. Preserve recognizable silhouettes and species from reference, no added hero, no duplicates. Maintain individual height differences; people remain modest in size, around 1–1.3 tiles tall on screen with large empty middle area. All characters shown consistently from the same raised frontal camera, farther characters mildly reduced in scale but still clearly readable. Feet contact their own tile planes; compact soft contact shadows follow the same ground perspective and one light source. No floating units, no giant foreground units, no pasted flat front-facing standees. No HP bars, selection rings, spell area circles or action effects beyond the fox's tiny held flame.

Overall finish: attractive polished hand-painted visual proposal, calm sparse readable board, mild depth rather than dramatic perspective. The whole inner grid must share the trapezoidal perspective of the platform.
```

## 唯一局部修订（未采用）

编辑目标：首图。目标只改列数，实际仍为14列，未达到12列要求；不再重绘。

```text
Use case: precise-object-edit
Edit target: the supplied generated forest tactical board concept.
Make ONE localized correction only: replace the grid seams on the playable TOP surface, which currently has TOO MANY columns, with EXACTLY 12 columns by 7 rows (84 cells). Keep the exact canvas, scene composition, board outer quadrilateral, stone texture/color, lighting, trees, mountains, lanterns, wall, stairs and all FIVE existing characters unchanged. Keep their identities, positions, orientations, scale and shadows. Do NOT add characters or UI.

Erase the current longitudinal grid seams completely from the top playing surface, then redraw exactly ELEVEN INTERIOR longitudinal seams between its two side boundaries, creating 12 columns. There must be exactly THIRTEEN total column boundaries, including the left and right edges. Evenly divide the FAR playable edge into 12 intervals and the NEAR playable edge into 12 matching intervals, then connect corresponding division points; all lines share the current centered mild trapezoid perspective. Count the intervals across the unoccluded bottom row to ensure exactly 12, not 13 or 14. Do not accidentally leave any old seam or add extra lines at the left and right ends.

The SEVEN existing depth rows are correct: retain those six interior transverse seams and the far/near surface boundaries, eight total row boundaries. Keep their current gradual rearward compression. Thin low-contrast dark green stone joints, as before. Character occlusion naturally hides portions of seams behind their bodies, but the underlying grid remains continuous. Do not change the angle or strength of perspective; this is only a precise column-count correction, not a new composition. No labels, arrows, text, or watermark.
```
