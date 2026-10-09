# 山雀精攻击 · Arrow strike前段

2026-10-09 · 08｜音效设计 · 来源前段获负责人指定，精确切点待试听，未接入。

来源：[Arrow strike.mp3 — plantmonkey](https://freesound.org/people/plantmonkey/sounds/410751/)，Freesound 410751。页面说明为用马鞭与尺子制作的箭矢声音；不是新增角色技能的依据。

授权：[CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/)，核对于2026-10-09，允许商业使用和修改，无强制署名；仍保留作者和来源便于追溯。音频及本次裁剪继续按CC0提供。

## 本次裁剪

- 公开HQ MP3预览解码长2.678866秒。未取得需要登录的原始下载，不能将转码WAV称为无损原始录音。
- 波形在约0.2～0.6秒出现第一段声音，约0.8秒起第二段。“前半段”按前面第一段完整事件理解，**取源0.170～0.680秒**，不按全长50%切到第二段中间。
- 成品 `sparrow_attack_first.wav` 长0.510秒，44.1kHz、16-bit PCM、立体声；2毫秒淡入、25毫秒淡出，峰值调整至-11dBFS。保持原音色/音高/速度，不从零合成或叠加命中声。
- 选择和切点供负责人试听，本批不替换运行时，亦不改狐火A/棍僧熊山君共用来源/其他角色。

## 文件与复现

`index.html` 对照成品与原预览；`manifest.json` 记录切点、授权、修改与校验值；`source/` 保留HQ预览及解码文件。

macOS解码：`afconvert -f WAVE -d LEI16@44100 -c 2 source/410751_182472-hq.mp3 source/preview-decoded.wav`。
随后运行 `python3 tools/trim.py`（依赖NumPy）。

技术检查：PCM格式/0.51秒时长/峰值余量/首尾零点/仅第一段来源/校验值/复现性。尚未人工听感或实际游戏内同步验收。确认切点后再交06以一次攻击一条声音接入。
