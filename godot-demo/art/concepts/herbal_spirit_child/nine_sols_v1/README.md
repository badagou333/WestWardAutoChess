# 药灵童子：二维手绘换风格候选 v1

日期：2026-09-30。状态：批量生成候选，待负责人审核。

负责人认可远程猎户后要求剩余人物一次生成，覆盖前一轮逐个确认门槛。本批范围为当前六角色中剩余的药灵童子、山雀精、熊山君，不包含唐僧或其他敌人，也不补动作、不接入主Demo。

## 文件和来源

- 图片：`herbal-child-nine-sols-candidate.png`；内置imagegen生成。完整提示词：`PROMPT.txt`。
- 身份/配色参考：`../../../production/herbal_spirit_child/color_v1/gray-teal-idle-color-only.png`。
- 画风参考：`../../foxfire_imp/nine_sols_v1/foxfire-nine-sols-sample.png` 与 `../../guard_monk/nine_sols_v1/guard-monk-nine-sols-candidate.png`，只参考绘制方法，不复制角色特征。
- 生成原文件：`/Users/leqiong/.codex/generated_images/01a06044-bbe6-7b31-946a-f682ea53611a/exec-f84397c7-b251-4b93-a13e-79f526e9c6cd.png`。本目录保存原样副本。

## 验证与限制

1024×1536 RGBA，alpha 0～254，alpha≥8边界(88,65,968,1472)。首张工具预览呈现光晕，初判清底失败并触发一次重试；后经alpha采样发现这些区域为alpha=0，深浅底真实合成复核无大块残底，纠正初判。保留首张；重试未采用（亮度/细节和构图有漂移，头顶余量更紧），归档于history。alpha-review.png为首张原样alpha深浅底QA合成，不是再生成或游戏素材。角色保留人形童子、草药斗笠、藤环杖及药葫芦；细节仍偏多、体型略显修长，是否采用待负责人确认。上下留白未完全达8%目标。

清底重试源：`/Users/leqiong/.codex/generated_images/01a06044-bbe6-7b31-946a-f682ea53611a/exec-1bb3415e-6562-4f54-8d0a-6c6c4a496fa6.png`，提示词 `history/PROMPT-cleanup.txt`。保留重试仅为过程来源，不采用、不继续重绘。本次纠正只适用于新图，不自动改变旧 color_v1 的历史验收状态。

未改现有素材和代码；真实透明单张不等于完整动画或引擎验收。下一步统一收集负责人对三张造型的意见，不擅自进入技能、全动作、其他角色或地图重绘。

