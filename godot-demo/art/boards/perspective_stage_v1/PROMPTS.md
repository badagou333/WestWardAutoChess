# 干净石台底图生成来源

2026-10-17，内置imagegen，仅一次定向编辑，无额外修订。输入为已获空间方向认可的 `../../concepts/board_perspective_v1/board-perspective-candidate.png`。没有重新设计人物或追逐生成12列。

```text
Use case: precise-object-edit
Asset type: clean reusable background for an existing 2D tactical game.
Edit target: the supplied approved forest stone-platform concept. Keep exactly the same camera, canvas aspect, platform silhouette, its trapezoid perspective, framing, forest, mountains, stone lanterns, front wall, central stairs, illumination and restrained hand-painted style. Do not redesign this composition.

Make only these cleanup changes on the TOP playing surface:
1. Completely REMOVE all five demonstration characters: orange-robed monk upper-left, ochre-robed badger staff monk middle-left, small white fox imp lower-left, grey wolf upper-right, armoured boar lower-right. Remove their weapons, tiny held fire, all outlines, and ALL their cast shadows and contact shadows. Restore unobstructed stone texture behind each. No ghost silhouettes, dark oval footprints, character-shaped shadows, or duplicate traces.
2. REMOVE every regular straight GRID seam from the TOP playing surface: all internal vertical/converging column lines and every internal horizontal row line. The top must have NO visible 14-column grid, NO alternative grid and NO square paving-tile division. Retain its muted mossy grey-green NATURAL STONE texture, mottled painting and subtle irregular erosion; do not blur it into flat plastic or change its hue. Do not add fresh straight cracks that resemble grid lines.
3. Preserve the existing thin outer playable-surface boundary inside the decorative rim, with clean legible top-plane corners. Preserve the surrounding rim, the FRONT VERTICAL wall masonry joints and central stair stone joints; those are architectural structure and should NOT be erased. Preserve the natural soft tree/foliage lighting across the stone, while removing all five unit shadows.

Everything outside the TOP playable surface must stay visually unchanged. The center will later receive an exact programmatically drawn 12×7 grid and existing animated units; do NOT render grid lines or units, selection shapes, UI, text or new objects now. No new architecture, obstacles or ornamental symbols. Maintain near-wide/far-narrow centered frontal downward view, no side turn. Match source dimensions 1672×941 if possible, otherwise preserve the complete original composition and near-16:9 landscape ratio without cropping. Deliver one opaque full-scene PNG background.
```
