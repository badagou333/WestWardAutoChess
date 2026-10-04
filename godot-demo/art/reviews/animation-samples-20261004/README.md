# 棍僧 / 山狼动画候选归档 · 2026-10-04

仅保存已有成果。**未接入游戏、未通过动画验收，不是可直接替换的生产包。** 本次没有生图、重画、重构脚本或启动游戏窗口。

## 当前候选与历史

| 路径（相对此目录） | 状态 |
| --- | --- |
| `guard_monk/` | 原棍僧候选，13帧、图集、manifest、静态审核图及离线播放 |
| `wolf_correction_v2/mountain_wolf/` | 山狼v2候选，13帧、图集、manifest、退场播放；只替换11/12 |
| `mountain_wolf/` | 历史原狼，未采用；只保留原图集/manifest/两张旧退场帧，0～10与v2相同 |
| `mountain-wolf-gait-keyposes.png` | 失败步态补稿，未采用：尾部触边、反相支撑不足 |
| `wolf_correction_v2/six-correction-poses.png` | 前四格步态失败未采用，后两格用于v2退场 |
| `baselines/` | 当时production图集首帧的原样快照，供复现，不受未来生产图替换影响 |

源稿完整提示词分别为根目录四个`*-prompt.txt`和`wolf_correction_v2/PROMPT.txt`；所有五张生成源稿保留。两份HANDOFF保留准备过程和时序细节，已增加历史状态说明，本README优先。

## 交给06的相对路径

- 棍僧：`guard_monk/manifest.json`、`guard_monk/body-atlas.png`。
- 山狼：`wolf_correction_v2/mountain_wolf/manifest.json`、同目录`body-atlas.png`。
- 统一256×256、脚点(128,218)，图集3328×256；棍僧源朝右、山狼朝左。source字段相对各manifest所在目录。
- `motion-sample-v1-requires-player-adapter`不是当前播放器即插即用格式。此归档不授权接入，也不修改production。单层身体包含武器/四肢，没有骨骼分层或新增VFX。
- WebP仅离线时序参考，预览循环不代表死亡后复活；实际死亡规则以程序实现为准。攻击接触事件须保持每个attack_serial仅一次，不另加伤害。

## 质量限制

- 山狼步态仍未明确形成相反支撑腿交替，两次步态补稿均未解决，不允许标记移动动画通过。v2只解决退场源轮廓相连问题，0～10帧保持原样。
- 棍僧衣纹、脸型、握点及棍长透视仍有帧间漂移，脚步承重/滑步未在引擎验收。
- 新退场与旧受击之间的体量、脚点、重量衔接仍待试播。透明与图集结构合格不等于动画自然。
- 原狼退场曾用源x=1080暂定分界，此旧方法只留历史；v2使用独立源轮廓。

## 复现与现有验证

保留原脚本，仅将原始待机输入改为随包快照、manifest改用相对路径，没有重构算法。需Python 3、Pillow及WebP支持；原环境Pillow版本见`ARCHIVE_CHECK.json`。复现会生成被精简掉的历史单帧和审核输出，**请先复制整个本目录至临时目录后运行，不要直接覆盖归档或production**：

```sh
python3 build_samples.py
python3 validate_samples.py
python3 wolf_correction_v2/build_correction.py
```

以上为原有复现顺序，本轮未重跑生成脚本或重新验动画。根`validation.json`/`light-alpha-review.png`是原棍僧与原狼历史静态检查；`wolf_correction_v2/validation.json`记录v2的0～10不变、11/12更新、退场间隔62px、步态未过及运行未验。`ARCHIVE_CHECK.json`是本轮轻量归档完整性检查，并非新增动画验收。

当前图集SHA-256：

- 棍僧：`42bc2c3621fec485cb94428900c408ae445a75cf1eca4576a6b56894aab0a291`
- 原狼历史：`505f807497ee19b68764ddd6e0b6b6e78df5e7f41232276f36d0e81a0c3fa8e6`
- 山狼v2：`895f53f7a2d3ca2fc48ede8fcc5258a584f7ff17b473aa866b193bf3a38c416c`

## 本轮限定UI意见

只看06的`../../../tests/free-escort-runtime/run-casualties-20261004-zero-survivors.png`这一张1280×720截图：顶部存活0/阵亡3/可用0/人口3、底栏1～3编号与阵亡/本关不可替补提示可辨，没有观察到这些字段相互遮挡。文字较小且阵亡提示低对比，其他DPI及真人阅读舒适度未验；本次不列新增阻塞、不重做UI。此结论不代替07的死亡规则独立验收。

下一步等待00/负责人另行安排，不自动批量扩展角色或接入候选。
