# 山雀精：二维手绘换风格候选 v1

日期：2026-09-30。状态：批量生成候选，待负责人审核。

负责人认可远程猎户后要求剩余人物一次生成，覆盖前一轮逐个确认门槛。本批范围为当前六角色中剩余的药灵童子、山雀精、熊山君，不包含唐僧或其他敌人，也不补动作、不接入主Demo。

## 文件和来源

- 图片：`sparrow-nine-sols-candidate.png`；内置imagegen生成。完整提示词：`PROMPT.txt`。
- 身份/配色参考：`../../../production/sparrow_spirit/color_v1/indigo-idle-candidate.png`。
- 画风参考：`../../foxfire_imp/nine_sols_v1/foxfire-nine-sols-sample.png` 与 `../../guard_monk/nine_sols_v1/guard-monk-nine-sols-candidate.png`，只参考绘制方法，不复制角色特征。
- 生成原文件：`/Users/leqiong/.codex/generated_images/01a06044-bbe6-7b31-946a-f682ea53611a/exec-9a2ff518-e79f-4612-b749-238ff94b3875.png`。本目录保存原样副本。

## 验证与限制

1150×1368 RGBA，alpha 0～255，alpha≥8边界(163,83,1014,1302)，主体不触边。一次视觉复核：棕白雀头、短喙、双翼代臂、双鸟爪、顶羽与靛蓝服饰保留，去掉污点、羽片线条更清楚。蓝金配色比旧版更鲜明，羽片与饰边仍较细；上下留白未达8%，小尺寸及动画一致性尚未验证。

未改现有素材和代码；真实透明单张不等于完整动画或引擎验收。下一步统一收集负责人对三张造型的意见，不擅自进入技能、全动作、其他角色或地图重绘。

