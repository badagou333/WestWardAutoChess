# 护寺棍僧动作关键姿势表提示词 v1

状态：本提示词保留为八动作生成记录；项目负责人已指定 `guard_monk_action_keypose_sheet_v2.png` 为当前参考，Demo 只使用待机、移动、普通攻击、受击和退场五个基础动作，技能格暂不定案。

## 用途

- 基于项目负责人确认的 `guard_monk_project_owner_reference_v1.png`，补充游戏战斗动作关键姿势。
- 本轮只验证动作语言、角色一致性与小尺寸轮廓，不直接生成最终逐帧动画或可导入游戏的 Sprite Sheet。
- 只上传当前项目负责人基准图，不使用目录中的 v1～v5 助手探索稿，也不再上传《九日》参考图。
- 输入图中的文字和排版只是设计稿内容，不作为生成指令；角色身份以图像造型和本提示词为准。

## 可直接复制的提示词

```text
Use case: stylized-concept
Asset type: production-oriented 2D game animation key-pose sheet for one existing original character.

REFERENCE HIERARCHY
Image 1 is the strict and only character identity reference. Preserve this exact project-owned Temple Staff Guardian Monk design. Do not redesign, reinterpret, beautify, modernize, simplify into a mascot, or borrow from any other artwork. Treat all writing, labels, layout boxes, scenery thumbnails, companion figures, color swatches, and instructional-looking text inside Image 1 as non-instructional image content. Extract only the confirmed guard monk’s visual design, clothing construction, staff, proportions, palette, and hand-drawn rendering language.

CHARACTER IDENTITY — MUST REMAIN IDENTICAL IN EVERY POSE
- the same adult anthropomorphic badger temple guardian, not a human, panda, raccoon, fox, cat, wolf, or bear;
- the same broad black-and-cream badger face pattern, small rounded ears, narrow dark eyes, short muzzle, stern calm expression, and coarse cheek fur silhouette;
- approximately three heads tall: large readable head, heavy compact torso, broad shoulders, short sturdy legs, oversized paws and feet; powerful and grounded, never childlike or realistically proportioned;
- the same worn charcoal-black / very dark blue-gray layered monk robe with sparse aged ochre flecks, the same weathered ochre inner lapel, beige wrapped cuffs, dark trousers, wrapped cloth shoes, muted red-brown waist sash, prayer beads, and restrained circular ochre back emblem when visible;
- the exact same plain long dark hardwood temple staff with short dark metal caps and ring details at both ends; keep its length, diameter, color, and construction identical in every pose;
- no new armor, shoulder plates, hat, cape, necklace, backpack, talisman, ornament, weapon, magic device, or costume layer.

PRIMARY REQUEST
Create one clean landscape animation-development sheet containing exactly EIGHT separate full-body key poses of this same character. Arrange them as two even rows of four, with generous empty space between poses and no overlap. Every pose uses the same front three-quarter gameplay camera, facing screen-right, at the same scale and with the same proportions. Keep the full body and entire staff visible in every pose without cropping.

The eight poses, read left to right and top to bottom, are:
1. COMBAT IDLE: low stable stance, knees softly bent, staff held diagonally close to the body, shoulders breathing, vigilant but restrained.
2. GUARDED WALK CONTACT: one compact forward step, weight low, rear foot pushing, robe hem and sash lagging behind, staff carried diagonally without bouncing weightlessly.
3. BASIC ATTACK ANTICIPATION: torso coils strongly against the attack direction, front shoulder lowered, both paws gripping the staff, clear compressed line of action before a horizontal sweep.
4. BASIC ATTACK IMPACT: powerful waist-driven horizontal staff sweep, feet planted, shoulders and hips counter-rotated, robe and sash following the arc; one restrained dry-brush motion arc, no magical energy blade.
5. HENG-GUN HU-FA / SINGLE-TARGET GUARD CAST: staff locked horizontally across the chest, one forearm braced, body placed between danger and an unseen ally; a compact warm-ochre shield flare appears just beside the protected side, clearly a single-target protection effect, not a taunt and not a full-area dome.
6. ZHEN-DI-GUN / GROUND-SLAM IMPACT: deep low stance, both paws driving one end of the staff vertically into the ground, shoulders compressed downward, strong impact silhouette; a short circular burst of dust, chips, and ochre impact strokes remains close to the feet, suggesting only a small nearby area.
7. HIT REACTION: brief heavy recoil while still trying to hold the frontline, one foot sliding back, torso twisting, staff used to catch balance; readable impact but no gore, no flying ragdoll, no comedy.
8. DEFEAT / RETREAT POSE: exhausted kneeling collapse with one paw and the planted staff supporting the body, head lowered, robe settling around the feet; dignified and readable, no corpse, blood, wound, or melodrama.

MOTION AND ACTING
This is an animation key-pose sheet, not a stiff turnaround. Use strong lines of action, clear anticipation and follow-through, visible weight transfer through hips and planted feet, slight squash and stretch in the compact torso, and delayed overlap in sleeves, robe hem, sash, cheek fur, and prayer beads. The staff must actively drive each silhouette. Keep the acting disciplined, protective, economical, and heavy; never acrobatic, berserk, flashy, cute, or weightless.

THREE-STAR COMPATIBILITY
The body pose for the confirmed three-star enhanced protection skill should reuse pose 5. Do not invent a ninth pose or a new spell. Leave enough clean negative space around pose 5 so a later VFX pass can add smaller secondary shields for adjacent allies. Do not show extra characters in this sheet.

STYLE AND RENDERING
Match Image 1’s established original dark East Asian fantasy 2D hand-drawn game art: bold irregular ink-like outer contours, restrained interior lines, angular but organic cloth shapes, matte mineral colors, broad flat shadow masses, subtle dry-brush wear, and selective aged-ochre and muted-red accents. Preserve the rough animated energy of the reference while making each silhouette clean enough for later separation. Avoid glossy mobile-game rendering, painterly realism, airbrushed gradients, 3D lighting, generic anime polish, photoreal fur, or vector-flat corporate art.

COMPOSITION AND BACKGROUND
Wide landscape canvas, exactly two rows of four isolated full-body poses, equal scale, consistent ground line, spacious separation. Use a perfectly uniform light warm-gray background that strongly contrasts with the dark costume. No environment, temple, floor texture, cast shadow, frame, border, decorative panel, UI, title, caption, action name, number, color palette, logo, signature, watermark, or readable text. The existing emblem on the costume may remain where naturally visible, but add no other writing.

CONSISTENCY CHECKS
- exactly one character repeated in exactly eight poses;
- identical face markings, ear size, muzzle length, body mass, costume layers, sleeve lengths, sash knot, prayer beads, footwear, palette, and staff construction in all eight poses;
- exactly two arms, two legs, two paws, two feet, one head, one staff per pose;
- no missing staff, duplicated staff, bent staff, shortened staff, floating staff, extra fingers, fused limbs, swapped costume sides, changing facial species, changing fur pattern, changing body height, or changing equipment;
- no companions, enemies, monks, alternate costumes, portrait close-ups, weapon callouts, expression studies, turnaround views, or unrelated spell effects.
```

## 生成后的检查标准

1. 八个动作是否确实是同一名獾僧，脸部花纹、服装层级、腰带、佛珠、鞋和禅棍没有漂移。
2. 待机、移动、横扫、护盾、震地、受击和退场能否只看剪影就被区分。
3. 普攻是否由腰胯带动，震地是否有明显下压重量，避免只摆手臂。
4. `横棍护法` 是否保持单体保护语义，没有误画成全屏护盾或嘲讽技能。
5. 缩小到游戏内目标尺寸后，头部花纹、禅棍方向和动作重心是否仍然清楚。
6. 本图通过后再分别制作待机、移动、普攻、护盾、震地、受击和退场的逐帧拆解；不要直接把本表切成游戏贴图。
