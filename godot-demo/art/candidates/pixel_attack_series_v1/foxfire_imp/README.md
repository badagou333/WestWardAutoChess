# 狐火小妖：双掌交替火攻

更新时间：2026-10-26。独立候选，作者逐帧与独立视觉限定通过，无本包明确画面必修。未接运行，不制作受击。

6个真实像素身体姿势、14个显示阶段：[正常1.75秒](preview.gif)、[半速3.15秒](preview_slow.gif)、[逐阶段图](contact_sheet.png)。透明身体在frames/、6份飞火层在layers/、14合成阶段在render_frames/，身体图集atlas.png。300／850ms为预览施放事件，不承诺游戏伤害或攻速。

保持白狐长耳、额纹、赤围巾、暗袍金饰和单尾，两手各一火、双腿站立。第一掌收胸后向右伸出；第二掌从另一侧抬手甩腕，另一持火手原位保持。第二弹先从抬掌上方起飞，再越过耳尖上方右行，后层不盖脸。这两次实际出自不同手，未靠文件名或同臂重复冒充交替。

原窄准备首格不采用，选择原第4格双掌准备闭环。旧第二次宽脚释放与抬步方案已整体弃用；当前蓄火／施放直接共用同一身体，只新绘真正抬起那只手的掌指／腕口并去掉离手火，保留另一掌及衣袖、头脸、躯干、双脚、尾巴。所有脚位只余小幅重采样／形体差，未以贴地大移位表达进步。具体源蒙版与原RGBA保护见source/preparation_report.json。

依据[现有清稿](../../../production/foxfire_imp/nine_sols_v1/source-clean.png)，用内置imagegen制作。实发提示词在source/prompts.json与hand_revision_prompts.json；工具PNG SHA、采用源WebP及解码RGBA哈希／全RGBA无损证明见source/provenance.json。初稿贴耳边、准备转头反向已定向修；整臂重画两次仍未保手臂归属，未采用，最终只修实际远手甩腕，不镜像手。

统一native1.0注册、96色身体、二值alpha；飞火保留RGBA透明度，显式在视口边裁飞出过程，身体不裁。GIF精确保角色色，FX量化允许近似，最终值见structural_report.json；RGBA原层不经过GIF量化。逐姿势／相邻及独立结论见[REVIEW.md](REVIEW.md)。

复建：用含Pillow／numpy的Python运行prepare_sources.py，然后用../tools/build_attack.py --spec本目录spec.json的绝对路径。输入均在仓库，无需默认生图目录或临时附件。负责人最终实时观感、运行显示及施放同步待验；不是商业成品或运行采用确认。
