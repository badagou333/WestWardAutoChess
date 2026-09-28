# 现有 Demo 野猪五基础姿势

2026-09-28；05 美术。遵照最新纠正沿用现有 Demo 双足野猪，不采用四足候选另起造型。

唯一身份参考：`art/demo/enemy_atlas_keyed.png` 的 Rect2(768,0,768,470)，精确裁切为 `demo_boar_reference_crop.png`，提取工具 `../../production/tools/extract_demo_boar.py`。保留橙棕毛色、绿金护甲/围巾、裤装、腰带与钉头锤，不改原 atlas。

- `demo_boar_action_sheet_v1.png`：内置 imagegen 五姿势源图，生产使用待机、移动、普攻、退场；原受击朝右且护肩换侧，不使用。
- `demo_boar_hit_v3.png`：直接参考原 Demo 裁切单独补受击，低头闭眼、屈膝防御，脸朝左、护肩在画面右、持锤在画面左。
- 完整提示词：`PROMPT_DEMO_ACTIONS_V1.txt`、`PROMPT_DEMO_HIT_V3.txt`；使用内置工具，无 CLI/API fallback。
- 整图局部修正未解决换侧，不采用；失败提示词存于 history/PROMPT_DEMO_HIT_FIX_V2.txt。
- 旧四足候选及提示词归档至 history，不再作为本轮基准。

来源哈希见 `../../production/boar/demo_v1/manifest.json`；交付与限制见该目录 README。各格武器装饰和面部细节仍有生成差异，快速 Demo 阶段不再整组重绘。未接入主 Demo，自动续跑保持暂停。
