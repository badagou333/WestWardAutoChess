# 狐火小妖 Demo 五基础动作与 VFX 分层样板 v1

## 用途

本目录把已审核的 `foxfire_imp_action_keypose_sheet_v1.png` 整理为角色身体层与狐火/VFX 层分离的 Demo 样板，用于验证待机狐火、普通攻击投射物和退场残火能否独立开关与移动。

这是由当前平面动作稿机械裁切和拆层得到的关键姿势样板，没有重新生成或改画角色，不是完整逐帧动画。

## 身体层

- `foxfire_imp_idle_body_v1.png`
- `foxfire_imp_move_body_v1.png`
- `foxfire_imp_attack_prepare_body_v1.png`
- `foxfire_imp_attack_impact_body_v1.png`
- `foxfire_imp_hit_body_v1.png`
- `foxfire_imp_retreat_body_v1.png`
- `foxfire_imp_demo_body_atlas_v1.png`：以上六帧横向排列，单帧 256×256。

## VFX 与投射物层

- `foxfire_imp_idle_vfx_v1.png`：与身体层同帧对齐的待机狐火。
- `foxfire_imp_attack_impact_vfx_v1.png`：与身体层同帧对齐的普攻飞弹。
- `foxfire_imp_retreat_vfx_v1.png`：与身体层同帧对齐的退场残火。
- `foxfire_imp_demo_vfx_atlas_v1.png`：与身体图集完全同序的六帧 VFX 图集；没有效果的格位保持透明。
- `foxfire_imp_idle_flame_v1.png`：64×64 紧凑待机狐火，可独立控制显隐。
- `foxfire_imp_basic_projectile_v1.png`：64×64 紧凑普攻投射物，可从施法点独立飞向目标。
- `foxfire_imp_retreat_flame_v1.png`：64×64 紧凑退场残火，可独立淡出。

## 预览与规格

- `foxfire_imp_demo_layer_contact_v1.png`：三列依次为待机、普攻命中、退场；三行依次为身体层、VFX 层、合成结果。
- `foxfire_imp_demo_action_board_contact_v1.png`：六帧深浅底双排预览；每排顺序为待机、移动、普攻蓄力、普攻命中、受击、退场。
- `foxfire_imp_cleanup_comparison.png`：蓄力缝隙与受击地线修复前后对照。
- `manifest.json`：身体/VFX 图集、帧序、源图哈希、裁切/身体落地点标注、投射物素材对齐位置及播放建议。

统一帧格为 256×256，脚底锚点为 `(128, 218)`，待机角色外接框高度约 124 像素。身体与同帧 VFX 使用完全相同的锚点和缩放，可直接叠加；紧凑投射物以自身中心 `(32, 32)` 为移动锚点。

## 验证结论与限制

### 2026-09-08 清底修复

六帧身体、三张同帧火焰和三个紧凑效果已从确认版原稿重新提取。蓄力/发射/受击的衣尾封闭残底、受击地面笔触及退场火焰底部地线已清除，白毛和火焰亮芯保留。六帧深浅底与分层静态复核通过；原图不变，不代表用户最终验收或 Godot 实战验收。

身体与同帧火焰使用共同缩放及手工标注的身体落地点，移动使用腾空躯干投影；动态落脚点仍待程序验证。原 2026-09-08“美术加工未通过”针对旧 PNG，本次修复替代其中清底/地线的待办结论。蓄力火焰、朝向切换和过渡帧限制继续保留。

验证：Godot 14 张 PNG / 12 个图集格检查无失败；非空格逐字节一致。六格身体/独立 VFX 在 alpha 大于 10% 时无重叠，三个紧凑效果按素材对齐位置还原后与同帧 VFX 逐字节相同。四个原残底/地线采样点透明，亮芯源像素保留；目视检查负责整体轮廓，不能仅用采样点替代。

详见 [复核记录](../../../reviews/foxfire-layer-review/README.md) 和 [六角色预览](../../../reviews/four-role-demo/index.html)。

- 待机狐火、普攻飞弹和退场残火均已从角色主体中分离；关闭 VFX 层后，角色轮廓仍完整。
- 普攻飞弹可使用紧凑 64×64 文件独立移动，不需要平移整张角色帧。
- 六张身体帧、三张同帧 VFX 和三个紧凑效果均未碰触图片边界。
- 普攻蓄力的小狐火与双手像素在原平面稿中已经粘连，无法在不补画手掌的情况下无损分离；本 Demo 暂时保留在 `attack_prepare_body` 中。正式资产必须补一张无火焰的手部底图，再把蓄力火焰独立出来。
- 本样板不包含投射物飞行逐帧、命中特效、背 3/4 朝向、完整中间帧、骨骼绑定或技能 VFX。

## 建议接入节奏

- 待机：身体第 0 帧与 VFX 第 0 帧叠加；狐火可做轻微上下浮动。
- 移动：身体第 1 帧，VFX 关闭；位移和约 2 像素起伏由运行时处理。
- 普攻：身体第 2 帧蓄力 0.12 秒；切换身体第 3 帧时，从施法点生成 `foxfire_imp_basic_projectile_v1.png`，飞行时间约 0.20 秒。
- 普攻使用独立投射物时，关闭第 3 格同帧飞弹层，避免重复显示；manifest 的 `aligned_center_trial` 保存素材对齐试验位置，两个审核页共用；正式施法点仍须在程序试接入时校准。
- 受击：身体第 4 帧保持 0.18 秒后回待机，所有狐火 VFX 暂时关闭。
- 退场：身体第 5 帧与 VFX 第 5 帧叠加，保持 0.45 秒后共同淡出 0.25 秒。

## 复现

运行 `python godot-demo/art/production/tools/build_foxfire_demo.py`（需 Pillow 和 NumPy），重建六身体帧、分层效果、两图集、静态预览及统一页面配置。文件名保留，刷新既有预览即可使用修复版。
