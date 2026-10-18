# D-20261018-002 原始提示词

工具：Codex内置imagegen。每角色首图一次、定向修订一次；未再生成。

## 棍僧首图

Use case: stylized-concept
Asset type: production-candidate transparent sprite sheet for a tiny tactical-game demo, NOT a scene illustration.
Output ONE wide 5:2 PNG canvas, ideally 2500×1000, genuinely transparent RGBA background. Exact layout: FIVE COLUMNS × TWO ROWS of equal-size square cells. Ten isolated full-body sprites, no visible cell lines, no labels, no letters, no captions, no floor, no diamond tile, no ground shadow, no checkerboard painted into the background. Generous transparent gap on all four sides of each sprite, including every foot and weapon/tail. Nothing may overlap adjacent cells or touch canvas boundaries.

Use the attached reference ONLY for identity/design/colors. Reconstruct every pose under a NEW COMMON CAMERA: orthographic, moderate oblique top view, roughly 30 degrees looking down from horizontal, suitable for a 2:1 diamond floor tile. Show head-top/shoulder/back planes; do not use old eye-level views, flatten or flip pasted reference art. Strong clean outlines and simple readable painted color shapes, restrained highlights; preserve identity consistently across all ten sprites.

Direction layout:
TOP ROW, all five sprites: three-quarter FRONT, facing screen LOWER-RIGHT / SOUTHEAST.
BOTTOM ROW, all five sprites: three-quarter BACK, facing screen UPPER-RIGHT / NORTHEAST.
Both rows represent the SAME character and same camera elevation. No character turns left, and no pose is directly front-on or directly side-on. Left directions will later be mirrored by the game.

Column order in BOTH rows:
1 = idle, calm grounded ready stance.
2 = short walking contact pose A.
3 = short walking contact pose B, opposite leg phase to A.
4 = attack preparation, grounded weight shift.
5 = attack contact/release, concise readable attack, still grounded rather than flying.
Same character body size and vertical scale across ALL cells, matching ground-plane foot-anchor baseline within each row. Use compact feet placement and short steps; all supporting soles must fit one small diamond footprint when scaled to game size. Do not make giant wide-stance action posters. This is five discrete key poses, no motion blur, no duplicate arms/legs, no trails.

Character identity: stocky black-and-white anthropomorphic BADGER temple staff monk. Rounded badger ears and muzzle, distinctive black/white head stripes, ochre-yellow worn monk robe, cream chest wraps and wrist/ankle wraps, dark trousers, red-brown sash, brown prayer beads and small subdued brass bell. ONE straight brown wooden staff with small brass ends held naturally in two hands. Never a human monk, panda, raccoon, new armor or new weapon.
Compact short-legged anatomy, readable simple robe folds. Two distinct visible feet in every pose; do not let the robe hide both ankles. Show each paw's full sole/toe silhouette; natural modest separation rather than a broad kung-fu lunge.
Idle: staff held at a calm low diagonal. Walk A/B: short alternating steps with one foot lightly lifting, upper body balanced, staff retained naturally; the two poses must have visibly opposite leg phase without changing character size. Attack preparation: draw the staff back slightly with both hands while keeping compact planted feet. Attack contact: a short controlled forward staff thrust toward the row's facing direction; no spin, leap, giant lunge or crouch. The long staff may extend beyond the body footprint but must remain entirely inside each sprite cell.
Keep body silhouette about 60–65% of each cell's height, with feet baseline around 80% of cell height, consistently aligned. Staff may use up to 85% of cell width; no staff goes into another cell. All ten full bodies and both staff ends visible. Transparent background only.

## 山狼首图

Use case: stylized-concept
Asset type: production-candidate transparent sprite sheet for a tiny tactical-game demo, NOT a scene illustration.
Output ONE wide 5:2 PNG canvas, ideally 2500×1000, genuinely transparent RGBA background. Exact layout: FIVE COLUMNS × TWO ROWS of equal-size square cells. Ten isolated full-body sprites, no visible cell lines, no labels, no letters, no captions, no floor, no diamond tile, no ground shadow, no checkerboard painted into the background. Generous transparent gap on all four sides of each sprite, including every foot and weapon/tail. Nothing may overlap adjacent cells or touch canvas boundaries.

Use the attached reference ONLY for identity/design/colors. Reconstruct every pose under a NEW COMMON CAMERA: orthographic, moderate oblique top view, roughly 30 degrees looking down from horizontal, suitable for a 2:1 diamond floor tile. Show head-top/shoulder/back planes; do not use old eye-level views, flatten or flip pasted reference art. Strong clean outlines and simple readable painted color shapes, restrained highlights; preserve identity consistently across all ten sprites.

Direction layout:
TOP ROW, all five sprites: three-quarter FRONT, facing screen LOWER-RIGHT / SOUTHEAST.
BOTTOM ROW, all five sprites: three-quarter BACK, facing screen UPPER-RIGHT / NORTHEAST.
Both rows represent the SAME character and same camera elevation. No character turns left, and no pose is directly front-on or directly side-on. Left directions will later be mirrored by the game.

Column order in BOTH rows:
1 = idle, calm grounded ready stance.
2 = short walking contact pose A.
3 = short walking contact pose B, opposite leg phase to A.
4 = attack preparation, grounded weight shift.
5 = attack contact/release, concise readable attack, still grounded rather than flying.
Same character body size and vertical scale across ALL cells, matching ground-plane foot-anchor baseline within each row. Use compact feet placement and short steps; all supporting soles must fit one small diamond footprint when scaled to game size. Do not make giant wide-stance action posters. This is five discrete key poses, no motion blur, no duplicate arms/legs, no trails.

Character identity: ONE ordinary quadruped grey-brown mountain wolf matching the reference: dark charcoal-grey back/mane, cream muzzle/chest/underbelly, pointed ears, long muzzle, ONE bushy grey tail. Natural wolf proportions, not a dog breed, giant direwolf, werewolf, armored beast or humanoid.
CRITICAL FOUR-LEG CLARITY: draw exactly FOUR anatomically connected legs and FOUR distinct visible paws in EVERY cell, including both back-facing poses. Arrange a compact natural slightly staggered stance so each paw silhouette is separated and can be inspected; far paws must not disappear behind the belly or near legs. All four feet must be in the camera's ground-plane perspective, not along a flat horizontal baseline. No extra toes mistaken for separate paws, no merged legs. Show the top plane of skull and the wolf's broad back while preserving normal animal depth.
Idle: compact balanced neutral stance, weight supported on all four feet. Walking A/B: small controlled steps, opposite diagonal leg pairs, with only slight toe lift; every leg/paw still visible. Preparation: lower head and bend forelegs slightly while keeping four feet planted close to their starting positions. Contact: short forward neck extension with a small open-jaw bite, FOUR FEET remain planted; no leap, flying pounce, long lunge, red mouth explosion or effects.
Keep muzzle-to-rump core body compact and consistent across cells, tail may extend naturally but remain inside its cell. Keep all foot placements compact within a projected diamond footprint, no widely splayed spider stance. About 65–75% cell width including tail and 45–55% cell height; common foot-anchor baseline around 75–80% cell height, same camera and scale in every cell. Prioritize all four paws legibility over detailed fur. Transparent background only.

## 棍僧唯一修订

Use case: precise-object-edit
Edit target: this transparent 10-sprite sheet. Preserve the existing character identity, color palette, clothing/anatomy design, drawn style, moderate overhead camera, directions and action meanings. Do NOT invent a new character. Correct only limb visibility/step alternation and safe sprite isolation as below.
Keep ONE sheet with exactly FIVE columns and TWO rows. Each of the ten figures must fit completely in its OWN equal rectangular cell with at least 8% transparent gutter on all sides, INCLUDING all feet, tail and weapon ends. Shrink all ten sprites by one SAME modest amount if needed to create gutters; do not change scale per pose. No sprite, staff tip, nose or tail may cross its cell border or canvas edge. Do not draw the cell borders, guides, ground, shadows, text or numbers. Preserve real transparent RGBA background. No red/yellow fringe, no white halo.
TOP ROW remains all facing LOWER-RIGHT (SE), three-quarter FRONT.
BOTTOM ROW remains all facing UPPER-RIGHT (NE), three-quarter BACK.
Five columns remain IDLE, WALK A, WALK B, ATTACK PREPARE, ATTACK CONTACT. Do not duplicate the same walk phase in columns two and three.

Required repairs for the BADGER MONK:
1. Top-row WALK A must clearly show TWO complete feet. Currently one foot is hidden under the trousers/robe. Separate the far foot naturally enough to see its ankle and toe outline, while keeping a compact stance.
2. In BOTH rows, WALK A and WALK B must have genuinely OPPOSITE leg phases. WALK A advances the character's left leg, with right leg back; WALK B advances the right leg, with left leg back. Keep the same torso facing and staff carry. In the back row especially, do not redraw the same raised-right-leg pose twice. Show one modestly lifted foot and one grounded supporting foot; no large jump.
3. In ALL ten cells, two complete distinguishable feet and ankles, no leg swallowed by the robe. Compact step width appropriate for ONE tactical tile. Keep idle and attack poses grounded on both feet; no broad lunges.
4. Preserve the straight two-handed staff and keep BOTH ends completely inside each frame. The current first staff and top-row fourth staff exceed their columns; correct framing rather than truncating the weapon. Do not shorten the staff into a baton.
This is a limited technical repair of the existing sheet, not new clothing or new action choreography.

## 山狼唯一修订

Use case: precise-object-edit
Edit target: this transparent 10-sprite sheet. Preserve the existing character identity, color palette, clothing/anatomy design, drawn style, moderate overhead camera, directions and action meanings. Do NOT invent a new character. Correct only limb visibility/step alternation and safe sprite isolation as below.
Keep ONE sheet with exactly FIVE columns and TWO rows. Each of the ten figures must fit completely in its OWN equal rectangular cell with at least 8% transparent gutter on all sides, INCLUDING all feet, tail and weapon ends. Shrink all ten sprites by one SAME modest amount if needed to create gutters; do not change scale per pose. No sprite, staff tip, nose or tail may cross its cell border or canvas edge. Do not draw the cell borders, guides, ground, shadows, text or numbers. Preserve real transparent RGBA background. No red/yellow fringe, no white halo.
TOP ROW remains all facing LOWER-RIGHT (SE), three-quarter FRONT.
BOTTOM ROW remains all facing UPPER-RIGHT (NE), three-quarter BACK.
Five columns remain IDLE, WALK A, WALK B, ATTACK PREPARE, ATTACK CONTACT. Do not duplicate the same walk phase in columns two and three.

Required repairs for the FOUR-LEGGED WOLF:
1. Exactly FOUR distinct visibly separate paw silhouettes and four anatomically connected legs in EVERY sprite. The hidden far hind paws currently merge with the belly; modestly stagger those far paws sideways/fore-aft so each can be inspected. Do not solve this with extra limbs or a very wide spider stance.
2. WALK A and WALK B must use opposite diagonal leg pairs in BOTH directions: A advances front-left + hind-right, B advances front-right + hind-left. Back-row A and B currently repeat the same lifted foreleg; visibly switch the leg pair, keep the same facing, body size and tail identity.
3. IDLE, PREPARE and BITE CONTACT must clearly have all FOUR feet grounded, placed compactly under the body. Preparation only lowers the head/forequarters slightly. Contact extends the neck into a short bite but does not leap, fly or hide paws. In particular repair the top-row third, fourth and fifth cells so far rear paws can be seen instead of inferred.
4. Keep every tail/nose/paw inside its allocated frame with transparent gutter; the rightmost and bottom edges currently lack safety.
No new wolf breed, no armor, no human traits, no ground shadow. Keep the fur as simple readable color planes at small game size.
