# 护寺棍僧六姿势修正候选 v1

日期：2026-09-07
生成方式：内置 image_gen，图像编辑。
输入：用户本轮上传的第二张六姿势修复图（剪贴板标识 2efba20c）。第一张八动作图只用于此前人工对照，不作为本轮生成输入。
范围：修正上排中间移动姿势的长棍折向，保留六姿势构成；不替换已确认动作参考 v2 或生产包。
状态：助手修正候选，待项目负责人审核与动态验证。

## 输出与验证

- 保存首次编辑结果：`history/guard_monk_six_pose_repair_candidate_v1.png`，1536×1024、RGB PNG。
- 移动格棍身已连续共线，六姿势均保留，棍端与脚部没有越出画布；其他区域存在生成式重绘细节变化，并非像素级保持。
- 首次输出和后续背景清理均未产生 alpha 通道，棋盘格为实色背景；第二次未采用，避免继续累积重绘漂移。不能直接作为透明 Sprite 导入。
- 尚未进行独立裁切、身体锚点校准或动态播放，不解除原生产样板未通过验收的状态。

## 长棍修正提示词

Use case: precise-object-edit. Edit target: the attached six-pose badger monk sheet (3 columns, 2 rows). Make a localized correction ONLY to the staff and gripping hands of the running/moving monk in the TOP CENTER pose. His current weapon appears bent into two incompatible axes between his hands. Replace this broken geometry with ONE single rigid straight wooden staff, with a continuous straight centerline through both gripping hands; both exposed ends must be collinear. Prefer a diagonal from upper left to lower right across his torso, as a natural carried staff during running; adjust only the hand grips locally as necessary. Keep the same dark wooden material and capped ends, no extra staff or dangling broken segment. Preserve the running body's pose, face, proportions, clothing, beads, feet and silhouette as closely as possible. Keep ALL other five poses unchanged, including the existing dramatic hit pose. Preserve the exact 3-by-2 sheet layout, dark hand-painted linework, original color palette and character identity. Keep every staff end and foot fully inside the canvas with a small transparent safety margin; no cropping. Output a true transparent-background PNG, clean edges, no black/gray fill, no checkerboard baked into the image, no ground shadows, no text, no labels, no new effects. This is a targeted repair of the supplied art, not a redesign.

## 背景清理提示词

undefined
