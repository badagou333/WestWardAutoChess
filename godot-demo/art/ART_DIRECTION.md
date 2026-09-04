# 美术方向状态

状态：整体待确认；第一章初始 5 名英雄与熊山君已有项目负责人视觉基准图

## 已确认部分

- 角色比例不统一限定为三头身；三头身只是可选的画风语言，各角色优先保持项目负责人基准图中已经成立的二、三、四头身或其他比例。
- 无论采用何种比例，都必须通过动画化形体重新设计，不能把写实人物机械缩放或直接压矮；头、胸腔、骨盆、四肢、手脚、动作线和衣片轮廓需要形成统一的动画造型语言。
- 战场和人物必须在实际棋盘尺寸下容易辨认，角色职业、敌我关系和品质差异需要清楚。
- 可以学习《九日》的整体二维手绘视觉语言，包括有力度的轮廓线、克制的平面色块、东方服饰形状、角色体块差异以及暗色场景中的局部亮色。
- 参考对象不是《九日》中的某一个具体角色，也不拼接或改造其现有角色设计；本项目角色必须从自身的剧情身份、战斗定位和技能出发独立设计。
- 不复制《九日》的具体服装、武器、身体特征、符号、构图、角色姿势或可识别造型。
- `concepts/guard_monk/guard_monk_project_owner_reference_v1.png`、`concepts/wild_hunter/wild_hunter_project_owner_reference_v1.png`、`concepts/sparrow_spirit/sparrow_spirit_project_owner_reference_v1.png`、`concepts/herbal_spirit_child/herbal_spirit_child_project_owner_reference_v1.png` 与 `concepts/foxfire_imp/foxfire_imp_project_owner_reference_v2.png` 是项目负责人提供的当前角色视觉基准；狐火小妖 v1 已被 v2 替代，仅作为历史版本保留。
- 此前由助手生成的护寺棍僧与狐火小妖探索图均未通过，不代表项目结论，也不得作为后续角色或动画的视觉基准。
- 护寺棍僧与山野猎户采用兽类拟人身份已获项目负责人确认；与旧版“凡人”和初始阵容身份构成记录的同步由总控及相关工作流处理。
- 山野猎户继续保持“近战输出”定位；当前 v1 设定稿中的短弓、箭筒和射箭动作已被要求修改，不能再作为正式武器与战斗动作基准。
- 为尽快完成 Demo，当前角色动画范围缩减为待机、移动、普通攻击、受击、退场五个基础动作；技能动作与正式技能 VFX 等技能设计稳定后再补。现有八动作稿保留为探索参考，其中技能格不约束后续设计。

## 尚未确认部分

- 最终采用国风、绘本、动画、厚涂、贴纸或其他表现方式。
- 最终线条粗细、材质、光影、色彩饱和度和场景细节密度。
- UI 的最终结构、装饰风格、字体和动效。
- 英雄升星后的具体外观变化方案。
- 正式角色、普通敌人和 Boss 的完整造型规范。

因此，不能根据当前 Demo 直接批量生产正式美术资源。

## 当前 Demo 方案

`art/demo/` 中的资源是为了验证玩法而制作的明亮国风 Q 版方案，参考了讨论时选中的三头身角色比例和庭院棋盘构图。它是一个待评估的美术样例，不是最终定案。

- `demo/temple_battlefield.png`：当前单战庭院背景。
- `demo/hero_atlas_keyed.png`：唐僧和原型英雄透明图集。
- `demo/enemy_atlas_keyed.png`：原型敌人和虎先锋透明图集。
- 没有 `_keyed` 后缀的图集保留为生成过程中的源文件。

上一版“守粮仓”原型的丰收题材素材已经从当前项目删除，如需查阅只能从 Git 历史恢复。

## 当前二维手绘候选方向

用户认可了一版暗色二维手绘棋盘画面的整体方向，并确认可以学习《九日》的画风方法，但不参照其中某一个具体角色。该方向尚未成为最终美术规范。目前允许在这一方向下制作少量原创角色探索稿，继续验证比例、轮廓和动画成本，不允许直接批量生产。

- `ACTION_KEYPOSE_PROMPT_RULES.md`：当前角色动作关键姿势提示词的统一制作规则，规范单一基准图输入、八动作结构、动画形体、角色/VFX 分层、一致性检查和进入逐帧前的通过条件。

- `concepts/guard_monk/history/guard_monk_model_sheet_exploration_v1.png`：护寺棍僧一星形态的首张角色设定探索稿；项目负责人已表示不满意，本稿未通过，不得作为后续角色造型基准。
- `concepts/guard_monk/history/guard_monk_shape_exploration_v2.png`：不使用 v1 作为参考、从空白画布生成的六种原创轮廓方案；当前待选择，任何一个方案都尚未确认。
- 护寺棍僧六方案中的第 3 个曾是阶段性偏好，现已被项目负责人基准图替代。
- `concepts/style/dark_handdrawn_battle_style_reference_v1.png`：此前生成的暗色二维手绘棋盘候选图，保留用于比较实际战场尺寸下的线条、色块与角色辨识度；图中兔子、鸟弓手等不是已确认角色。
- `concepts/guard_monk/README.md`：探索稿状态、限制和进入正式动画前的检查项。
- `concepts/guard_monk/history/guard_monk_five_view_exploration_v3_a.png`～`v3_c.png`：已否定的五视图方向；虽然压缩了头身比，但仍保留写实骨架和僵直设定稿逻辑，不得作为后续基准。
- `concepts/guard_monk/history/guard_monk_five_view_exploration_v4_a.png`～`v4_c.png`、`v5.png`：均未通过项目负责人审核，只保留为已否定探索历史。
- `concepts/foxfire_imp/history/foxfire_imp_five_view_exploration_v1.png`：未通过项目负责人审核，只保留为已否定探索历史。
- `concepts/foxfire_imp/foxfire_imp_project_owner_reference_v2.png`：项目负责人提供的狐火小妖当前视觉基准，表现为一尾小型狐妖、狐火施法、五视图、表情与动作；v1 已被本版替代。
- `concepts/guard_monk/guard_monk_action_keypose_sheet_v1.png`：项目负责人生成并要求保存的护寺棍僧八动作关键姿势稿，用于后续动作与动画拆分参考。
- `concepts/foxfire_imp/foxfire_imp_action_keypose_sheet_v1.png`：基于狐火小妖 v2 生成并由项目负责人要求保存的八动作关键姿势稿，用于后续动作与动画拆分参考。
- `concepts/wild_hunter/wild_hunter_project_owner_reference_v1.png`：项目负责人提供的山野猎户身份与造型基准；兽类拟人身份有效，短弓与射箭部分待按近战定位修改。
- `concepts/sparrow_spirit/sparrow_spirit_project_owner_reference_v1.png`：项目负责人提供的山雀精当前视觉基准，表现为山雀拟人精怪与羽翼/风刃攻击。
- `concepts/herbal_spirit_child/herbal_spirit_child_project_owner_reference_v1.png`：项目负责人提供的药灵童子当前视觉基准，表现为草木通灵童子、药杖、草药烟雾和草灵伙伴。
- `concepts/herbal_spirit_child/history/herbal_spirit_child_action_keypose_sheet_v1.png`：VFX 修正前的八动作探索稿，已归档为历史。
- `concepts/herbal_spirit_child/herbal_spirit_child_action_keypose_sheet_v2.png`：项目负责人提供的 VFX 修正版；人物与动作保持稳定，待机、普攻、单体治疗、毒草和群体治疗的特效层级已清楚。Demo 仍只取五个基础动作，技能格不约束后续设计。
- `concepts/bear_lord/bear_lord_project_owner_reference_v1.png`：项目负责人提供的熊山君当前视觉基准，表现为巨熊妖王、碎山棒以及践踏、暴怒和恢复动作。
- `concepts/bear_lord/bear_lord_action_keypose_sheet_v1.png`：保持巨熊体量、将践踏明确修正为脚掌冲击的八动作探索稿；项目负责人确认当前版本先用于 Demo，不再修改。受击姿势后仰较大、碎山棒持握不够稳定的问题只留作正式动画优化备注。
- `concepts/wild_hunter/history/wild_hunter_action_keypose_sheet_v1.png`：短弓修改前的八动作视觉试稿，只保留为历史，不再作为后续动作基准；猎犬和鹰仍需独立资产。
- `concepts/wild_hunter/wild_hunter_action_keypose_sheet_v2.png`：已通过审核的近战八动作参考稿，以单手猎刀表现待机、移动、突进、横斩、猎犬指令、鹰哨、受击和退场；猎犬与猎鹰仍需作为独立资产制作。
- `concepts/sparrow_spirit/sparrow_spirit_action_keypose_sheet_v1.png`：保持自然鸟体比例、以羽翼与风刃完成的八动作视觉试稿；不代表已确认用风刃替代箭矢语义。
- 六名角色的项目负责人设定稿均尚未完成透明抠图、身体分层或骨骼绑定，不能直接作为游戏贴图使用。
- 当前动作关键姿势稿均不是最终 Sprite Sheet；正式制作前仍需统一部件、拆分角色与特效、补齐必要朝向并进行实际棋盘尺寸测试。
- 下一轮优先使用护寺棍僧与狐火小妖动作稿进行实际棋盘尺寸测试，再确认正/背 3/4 朝向、角色与特效分层以及首组逐帧数量。

## 下一次美术确认计划（已确认）

下一步先把相同场景、相同角色和相同构图制作成几套并排方案，再逐项确认：

1. 角色比例与轮廓。
2. 描边和上色方式。
3. 场景透视与棋盘可读性。
4. UI 是否与角色画面统一。
5. 缩小到游戏实际尺寸后的辨识度。

确认结果应写回本文件；在确认前，所有新图仍标记为 Demo 或探索稿，不批量生产正式资产。
