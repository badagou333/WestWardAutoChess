# 山野猎户：二维手绘换风格候选 v1

日期：2026-09-30。状态：定位修改前的历史近战候选。负责人已确认改为远程弓箭手（D-20260930-009），本图及路径原样保留，不再作为当前武器基准；新候选见 `../nine_sols_archer_v1/README.md`。

- 负责人确认护寺棍僧新版后要求继续下一个。本轮仅生成山野猎户单张待机造型，保持逐角色审核，不补动作、不接入运行时。
- 输出：`wild-hunter-nine-sols-candidate.png`；完整提示词见 `PROMPT.txt`。内置 imagegen 一次生成。
- 身份/配色参考：`../../../production/wild_hunter/color_v1/moss-idle-candidate.png`；保留兽类身份、棕白毛色、环纹尾巴、斗笠、苔绿衣装及单手近战猎刀，不恢复弓箭。
- 画风参考：`../../foxfire_imp/nine_sols_v1/foxfire-nine-sols-sample.png` 和 `../../guard_monk/nine_sols_v1/guard-monk-nine-sols-candidate.png`，只学习线条/色块/阴影，不复制其角色特征。
- 生成源：`/Users/leqiong/.codex/generated_images/01a06044-bbe6-7b31-946a-f682ea53611a/exec-12f1e0ac-1af1-42c3-b29f-c035e3ce3445.png`，已原样保存至仓库。
- 验证：1216×1293 RGBA，alpha 0～255，alpha≥8 边界 (40,34,1183,1276)，主体不触边。一次视觉检查：斗笠、尾纹、短刀、绿衣及两脚完整，污点/细碎饰物明显减少；衣摆破口和毛发色块仍较多，刀形有所变宽，尾巴右侧及脚底留白偏紧，未达到提示词6%余量。仅造型候选，不代表生产资产或小尺寸验收。
- 原素材保留，未改程序，未做动画或战斗验证。后续审核对象转为弓箭手版本；本目录提示词中的近战限制仅为历史生成记录，已被最新确认覆盖。
