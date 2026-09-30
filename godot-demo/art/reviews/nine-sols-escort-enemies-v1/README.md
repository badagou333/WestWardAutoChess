# 唐僧与三名小怪｜新版造型审核

2026-09-30。内置 imagegen 四次生成四张单体待机候选，沿用已认可的狐火/棍僧二维描线平涂方向。原图直接保存，不改旧资产或运行时。提示词分别保存在各角色目录。

|角色|图片与完整提示词|待审核重点|
|---|---|---|
|唐僧|[图](../../concepts/tangseng/nine_sols_v1/tangseng-nine-sols-candidate.png) · [提示词](../../concepts/tangseng/nine_sols_v1/PROMPT.txt)|比旧Q版修长，成年感增强，未满足提示词约三头身；须负责人确认比例，不把此偏差当既定新设计。|
|山狼|[图](../../concepts/mountain_wolf/nine_sols_v1/mountain-wolf-nine-sols-candidate.png) · [提示词](../../concepts/mountain_wolf/nine_sols_v1/PROMPT.txt)|鬃毛碎形仍偏多，下边留白较紧；棋盘缩小辨识及动作尚未验证。|
|灰鼠|[图](../../concepts/gray_rat/nine_sols_v1/gray-rat-nine-sols-candidate.png) · [提示词](../../concepts/gray_rat/nine_sols_v1/PROMPT.txt)|实际朝右，与提示词朝左不符；动作/投石过程/石块独立分层未制作，不直接镜像后宣称完成生产适配。|
|山猪|[图](../../concepts/mountain_boar/nine_sols_v1/mountain-boar-nine-sols-candidate.png) · [提示词](../../concepts/mountain_boar/nine_sols_v1/PROMPT.txt)|四边留白较紧，顶部仅16像素（alpha≥8）；不能当已统一画布/脚点的生产帧。|

## 验证与交接

- [真实alpha深浅底审核图](alpha-review.png)：按原图等比缩小合成，仅供透明与边缘检查，不代表角色间实机体量。
- 四张均RGBA、有真实透明通道，alpha≥8轮廓未触外边界；深浅底复核无大块残底。唐僧/狼/鼠最高alpha为254，保留生成原值。未据隐藏RGB误判光晕、未重复清底生成。
- 唐僧更修长是生成偏差，尚未确认；灰鼠实际朝右，其他朝向及武器持握详见各角色README。
- 负责人明确确认灰鼠使用“投石索＋石袋”，保留远程定位，旧短刀不再是新版装备参考。仅装备确认，无战斗数值新定案；05已登记待总控同步。
- 本批仅四张静态造型；未生成移动/普攻/受击/退场、投射物与特效，未制作连续动画、统一脚点或替换Demo，不做战斗回归。
- 下一步：负责人审四张造型（尤其唐僧比例）；确认后再按五基础状态补动作。概念交付无阻塞，生产接入仍待加工和验证。
