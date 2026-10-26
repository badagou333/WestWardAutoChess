# 护寺棍僧：像素攻击 v5

> **2026-10-26 复审纠正。** 当前状态：须核对斜俯视棋盘适配；本包按负责人上传动作图制作，旧局部通过结论不等于现棋盘可用。 方向依据与返工门槛见[系列说明](../pixel_attack_series_v1/README.md)。下文保留原制作与检查历史，图片尚未返工。

## 历史制作记录（当前用途通过结论已撤回）

更新时间：2026-10-26。独立美术候选；本轮主动作完整检查版本。后续角色见[系列目录](../pixel_attack_series_v1/README.md)。

保留负责人认可的细节像素造型、竖棍起手／右上出棍、已下压棍帽、v4左手修正与v2快速残影。完整复核发现回收握距突变和前脚平移，故只重画必要回收手臂／前腿并加入抬脚过渡。6个真实身体姿势、9个显示阶段，448²透明PNG；正常1.15秒、半速1.95秒，230ms接触不变。

查看 [正常动画](preview.gif)、[半速](preview_slow.gif)、[逐阶段图](contact_sheet.png)、[v4/v5同起手对照](comparison.gif)。身体在body/，合成阶段在render_frames/，图集为composite_atlas.png。实际沿用的身体0/2/3/5位于前代清单路径，manifest记录来源与哈希。

制作使用内置imagegen。完整实发提示词见[prompts.json](prompts.json)，原PNG文件哈希／无损源WebP与RGBA证明见[source_provenance.json](source_provenance.json)。只从生成插画取局部，显式掩码注册到原姿势，96色／二值身体alpha。双臂按原握位注册[-20,+36]，前腿补真实离地；未靠整人旋转替代绘制。首轮回收手臂归属不理想及袖边残片已修，不保留为推荐帧。

复建：使用含Pillow/numpy的Python依次运行build_pose_patches.py、build_natural.py；源路径为仓库内相对路径。先保留v1/v2/v4作为明确依赖，不搬移旧包。source中的新WebP均与工具PNG全部RGBA完全相同（包括透明区RGB），省去重复PNG文件，不做有损压缩。

作者逐帧／相邻姿势复核、独立视觉与结构关卡通过，无本轮明确必修；具体每帧及限制见[REVIEW.md](REVIEW.md)、[validation.json](validation.json)。静态序列、时序与透明导出检查不替代负责人连续观感或游戏命中验收；本包未接入游戏，未制作受击。
