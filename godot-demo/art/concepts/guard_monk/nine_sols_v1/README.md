# 护寺棍僧：二维手绘换风格候选 v1

日期：2026-09-30。状态：单张造型待负责人确认；确认前不进行下一个角色。

- 负责人已认可狐火九日方向，并要求既有人物逐个修改、逐个确认。本轮仅先制作棍僧待机造型，不提前重画动作或接入运行时。
- 输出：`guard-monk-nine-sols-candidate.png`；完整提示词见 `PROMPT.txt`。内置 imagegen 一次生成。
- 身份/配色参考：`../../../production/guard_monk/color_v1/ochre-idle-candidate.png`。
- 画风参考：`../../foxfire_imp/nine_sols_v1/foxfire-nine-sols-sample.png`。只转移线条、色块及阴影方法，不借用狐耳、尾巴等身份特征。
- 原始输出：`/Users/leqiong/.codex/generated_images/01a06044-bbe6-7b31-946a-f682ea53611a/exec-1deabafd-1cdc-4bcc-bdba-0a32016eb4e1.png`，仓库保存原样副本。
- 验证：1240×1269 RGBA，alpha 0～255；alpha≥8 边界为 (93,26,1206,1249)，主体不触边。一次视觉检查：獾脸、赭黄僧衣、佛珠、铃铛、双手和完整直棍保留，繁杂污点明显减少。衣色较参考更亮、衣摆破口仍多、棍端与脚边留白较紧，待用户反馈；未做生产级清边或引擎验收。
- 这是静态造型候选，不是动画。旧素材全部保留，不替换程序引用。下一步仅等待本角色确认或修改意见，再按用户逐个确认规则继续。
