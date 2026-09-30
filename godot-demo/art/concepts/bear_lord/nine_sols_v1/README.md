# 熊山君：二维手绘换风格候选 v1

日期：2026-09-30。状态：批量生成候选，待负责人审核。

负责人认可远程猎户后要求剩余人物一次生成，覆盖前一轮逐个确认门槛。本批范围为当前六角色中剩余的药灵童子、山雀精、熊山君，不包含唐僧或其他敌人，也不补动作、不接入主Demo。

## 文件和来源

- 图片：`bear-lord-nine-sols-candidate.png`；内置imagegen生成。完整提示词：`PROMPT.txt`。
- 身份/配色参考：`../../../production/bear_lord/color_v1/iron-red-idle-candidate.png`。
- 画风参考：`../../foxfire_imp/nine_sols_v1/foxfire-nine-sols-sample.png` 与 `../../guard_monk/nine_sols_v1/guard-monk-nine-sols-candidate.png`，只参考绘制方法，不复制角色特征。
- 生成原文件：`/Users/leqiong/.codex/generated_images/01a06044-bbe6-7b31-946a-f682ea53611a/exec-0873eca5-2ea8-4d22-b32c-c261eb14d2ca.png`。本目录保存原样副本。

## 验证与限制

1208×1302 RGBA，alpha 0～255，alpha≥8边界(88,14,1123,1279)，主体不触边。一次视觉复核：厚重熊体、圆耳、木质钉头棍、铁灰护甲、暗红腰布保留，纹理明显简化。毛束/护甲与金属装饰仍较多，棍顶及脚底留白明显不足8%目标；未视为可直接裁切的生产规格，待用户判断造型。

未改现有素材和代码；真实透明单张不等于完整动画或引擎验收。下一步统一收集负责人对三张造型的意见，不擅自进入技能、全动作、其他角色或地图重绘。

