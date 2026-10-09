# D-20261009-006｜08 → 06 音效素材交付

交付日期：2026-10-09。权威采用依据：D006/负责人逐项选材与药灵新版选择。本目录只交付素材，未修改任何运行代码或现有v1。当前 **7个已选可用外部来源覆盖8个角色行为，猎户为旧声占位**；总计9行为、8个WAV。选定的第8个外部来源是猎户NC参考，仍隔离、未打包。

## 导入清单

本目录下 `wav/` 即可导入文件；`manifest.json` 提供精确版本、来源、修改、帧数、sha256和事件建议。统一44.1kHz/16-bit PCM，保留既定单/双声道，Godot可直接导入。不要用v1生成器重写选定文件，也不要将整个候选目录当运行包。

| 角色 / 事件键 | 文件 | 来源ID | 授权 | 实际时长 | 峰值 | 唯一推荐时机 |
|---|---|---|---|---|---|---|
| 护寺棍僧 / `guard_monk_attack` | [monk_bear_whack.wav](wav/monk_bear_whack.wav) | 114683 | CC0 1.0 | 0.441247s | -11.000dBFS | 近战实际造成伤害时一次 |
| 山野猎户 / `wild_hunter_attack` | [hunter_old_fallback.wav](wav/hunter_old_fallback.wav) | 原v1占位 | project-generated (existing v1 asset; no external source) | 0.250000s | -10.000dBFS | 投射物实际释放时一次 |
| 山雀精 / `sparrow_spirit_attack` | [sparrow_attack_first.wav](wav/sparrow_attack_first.wav) | 410751 | CC0 1.0 | 0.510000s | -11.000dBFS | 投射物实际释放时一次 |
| 药灵童子 / `herbal_spirit_child_attack` | [healer_new_full.wav](wav/healer_new_full.wav) | 523649 | CC0 1.0 | 0.904762s | -12.000dBFS | 实际恢复HP>0时一次 |
| 狐火小妖 / `foxfire_imp_attack` | [foxfire_A_faithful.wav](wav/foxfire_A_faithful.wav) | 136696 | CC BY 4.0 | 0.570000s | -11.000dBFS | 投射物实际释放时一次 |
| 灰鼠喽啰 / `rat_attack` | [rat_attack_second.wav](wav/rat_attack_second.wav) | 325913 | CC BY 3.0 | 0.200000s | -11.000dBFS | 投石实际造成伤害时一次 |
| 山猪喽啰 / `boar_attack` | [boar_attack_full.wav](wav/boar_attack_full.wav) | 416890 | CC0 1.0 | 0.386667s | -11.000dBFS | 近战实际造成伤害时一次 |
| 山狼 / `wolf_attack` | [wolf_attack_full.wav](wav/wolf_attack_full.wav) | 260776 | CC BY 3.0 | 2.415669s | -11.000dBFS | 近战实际造成伤害时一次 |
| 熊山君 / `bear_lord_attack` | [monk_bear_whack.wav](wav/monk_bear_whack.wav) | 114683 | CC0 1.0 | 0.441247s | -11.000dBFS | 近战实际造成伤害时一次 |

角色ID/事件键沿用08既有清单，06映射当前棋盘实际实体，不借此改人物、技能、数值、动画或旧入口默认音效。山雀取原声前事件0.170～0.680秒；灰鼠取第二事件0.655～0.855秒；这两条按D006本次接入要求交付现版本。狐火A、药灵新版与此前选定音频逐字节一致。

## 单次触发和长声限制

- 以攻击者实例＋该次攻击序号做语义去重（具体实现由06确定），每攻击最多一条主要声；棍僧/熊用同一文件，但不要把两个单位的不同攻击误当同一事件。
- 近战在有效命中时一次；山雀/狐火/猎户在实际发射时一次，不再到命中时追加主声或共用材质受击层；灰鼠只在投石有效命中时一次，发射不加第二声。范围/多目标命中按同一次攻击去重，不能按每个受击者重复播。
- 药灵在有效治疗、恢复HP大于0时一次，空放/满血不触发；若同一治疗影响多个目标，只播一次。唐僧不新增攻击声。UI、胜利等非替换事件按原需求保持；英雄退场继续暂缓。
- 山狼 **完整2.415669秒**，未裁事件、未改变音高/速度。原作者已降调，08本轮没有再降调。若攻击间隔小于该时长或多狼同时攻击，尾声会重叠并占用音轨；06按现有并发/优先级管理并报告实际丢弃/截断策略，不通过偷偷裁音、变速或改变攻击节奏解决。建议后续真人检查连续攻击的清晰度。
- 药灵按已选版本原样交付：首帧为2948/32768（约0.090），非零起点，尾帧为0；有潜在启动点击风险，尚未实听验证，未擅自改已选版本。其余7文件首尾为0。峰值一致不代表感知响度一致，混战听感仍待验收。

## 猎户许可待答

Robinhood76 126464第2段仍为CC BY-NC 4.0，商用许可未获得，负责人对本轮“保旧/仅非商业试玩用新”的选择待答。本目录只含原v1 `hunter_old_fallback.wav`，不含NC音频。新参考仍在仓库根 `docs/audio-references/noncommercial/hunter-robinhood76-v1/hunter_launch_02.wav`，精确哈希见manifest的hunter_pending。即使之后允许非商业试玩，也不视为商用许可；06须按新的书面决定单独处理，不根据参考路径自动复制入包。

## 授权与备份

运行复制时须同时带入 [ATTRIBUTION.md](ATTRIBUTION.md) 内容到游戏鸣谢/第三方声明并确保进入最终分发。鼠/狼CC BY 3.0、狐火CC BY 4.0需作者、作品、来源、许可和修改说明；CC0也保留追溯。全体外部成品均源于合法公开HQ MP3预览，转成WAV并非原始无损下载，没有绕过登录。

旧v1九条行为声音均保持原位，精确路径/哈希见manifest.backups；药灵另有 `../healer-lilmati-v1/healer_old_backup.wav`，原始对比页保留。狐火当前A没有替换成新变体。未来剑声不入包。

## 复现与验收边界

在本目录运行 `python3 tools/build.py`（Python3＋numpy）可离线复现。已存三条公开预览和解码WAV；解码命令为 `afconvert -f WAVE -d LEI16@44100 -c 2 <preview.mp3> <decoded.wav>`。山猪原页48kHz单声道，预览统一输出44.1kHz双声道；以存档解码文件保证跨平台复现。本轮三条新增均保完整解码帧数、2ms淡入/8ms淡出、峰值-11dBFS；其他5文件直接复制原选版/占位，不再加工。

`python3 tools/verify.py` 检查映射、原选版/备份哈希、8文件格式/削波/端点、3个完整声时长、成品哈希/链接、离线重建字节一致与NC隔离。结果见 [VALIDATION.json](VALIDATION.json)。这些是08素材技术自检，不代表06已接入、07独立通过、游戏内听感、正常输入、静音/暂停/倍速/死亡/重试或最终PCK已验证。06应逐项验证真实事件和源→运行→PCK哈希；后续由07独立核验。

## 成品校验值（SHA-256）

| 文件 | SHA-256 |
|---|---|
| `wav/monk_bear_whack.wav` | `56502597d09207bc3b4acc3f866ef685eb5a4306852e2f16b89889cc666d4fde` |
| `wav/wolf_attack_full.wav` | `087c1e90d04801ad1d732df2e8b2df45efda00c54362e0e29ea34db3ad0026f2` |
| `wav/boar_attack_full.wav` | `73258a27856e1b5453e4bbec55555b9fc574b1d522c74ec9c1ac157283fe56c3` |
| `wav/sparrow_attack_first.wav` | `32f3ba8d0c0f48572f5d410202e53add1e675934ec0d2f0a52f11f34f86ee995` |
| `wav/rat_attack_second.wav` | `7b1461f9f572778ab1b58bb5d746b50775087b74abbc160d53620121cc012f94` |
| `wav/healer_new_full.wav` | `3a40ab16654b2be18d4888976833984b6f13057897b11c643aec001f7fa2c894` |
| `wav/foxfire_A_faithful.wav` | `aa30009e92190a69ec99a404f047b453606a8f6e79e5a0f4fe3de495a900a7db` |
| `wav/hunter_old_fallback.wav` | `6c067f0acdc52428e7e258ace8980aeb526e2f5513f2ee0bef0d582e781aa768` |
