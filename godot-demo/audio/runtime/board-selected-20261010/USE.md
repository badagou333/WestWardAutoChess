# 棋盘选定音效运行副本：仅非商业试玩

Profile：`board-selected-noncommercial-20261010`，schema 2。D-20261010-001已确认采用狼第一声短版，停用4种怪物死亡声与胜利提示，保留其余攻击/治疗和唐僧受伤警示。本目录共9个WAV／10个事件／9个角色攻击或治疗映射：棍僧和熊山君共用，唐僧警示另列为secondary cue；8个外部来源加1个项目内程序合成警示。此目录不依赖候选、备份或原始预览，不把旧完整狼声列入有效映射或包列表。

所有文件从已选成品逐字节复制，没有本轮裁切、变调、变速、增益或响度处理。统一44.1kHz、16-bit PCM；狐火A与唐僧警示为单声道，其余为双声道。9份Godot导入配置均使用PCM0，不改变声道、采样率、normalize、trim或loop；资源源路径与导入路径是本版专属，旧UID不复用，实际资源UID由Godot后续导入生成。

## 用途与许可

猎户 `wav/hunter_launch_02.wav` 是Robinhood76的CC BY-NC 4.0素材，整套仅供本次非商业试玩。NC例外仅限 `godot-demo/audio/runtime/board-selected-20261010/wav/hunter_launch_02.wav` 及SHA-256 `6936dbe90b719c90d1dfa8900fc1736ca1bda035b767931d00e67e94027ac9a7`。这不扩大到其他路径、版本或NC来源，也不构成商用许可。商用须替换猎户来源或取得商用许可，再经授权及发布检查；不能仅删除非商业标记。

其余外部素材仍分别按原CC0 1.0、CC BY 3.0或CC BY 4.0有效；唐僧警示按v1项目内自制记录处理，不擅自新增公开授权许可证。分发时完整带入 [ATTRIBUTION.md](ATTRIBUTION.md)，保留所有作者、作品、来源、许可、修改和不背书说明。

## 映射、停用与保留

以 [manifest.json](manifest.json) 的roles、secondary_cues、disable_cues和preserve_cues为有效表。棍僧/猪/狼/熊在实际近战有效伤害时触发；猎户/雀/狐在实际发射时触发，命中不重复加主声；灰鼠仅在投石有效伤害时触发；药灵仅在恢复HP大于0时触发。每攻击者实例＋攻击序号最多一条主要声，不按范围受击数量重复。唐僧警示仅在其实际承受正伤害时保留既有规则，不新增唐僧攻击声。

停用 `rat_death`、`boar_death`、`wolf_death`、`bear_lord_death`、`victory`；monster_death与battle_result类别均无相应请求、加载或播放，不新增失败或其他结果音，不用旧通用声补回。保留上述9条攻击/治疗及唐僧警示共10个事件。英雄退场继续无声，不恢复共用材质受击层；UI等无关事件按原规则。只停用音效，不删除死亡动画、胜败结算、界面或战斗数据。

狼短版为0.600～0.890秒第一声，12789帧、0.290秒；08保既定切点、音高、速度与增益，2ms淡入/30ms淡出，未新增处理。原完整2.415669秒声音、09运行版与其他旧源留在原位置备用，不作不可逆删除。本运行副本的整理不表示程序接线、包有效列表或试听页已经修改生效；实际清单须待06完成接线、测试和包检查后更新。

## 技术验证与边界

```sh
python3 scripts/verify_board_audio.py --mode noncommercial
python3 scripts/verify_board_audio.py --mode commercial
```

第一条核9个固定源→运行WAV与PCM哈希、44.1kHz/16-bit/声道/帧数、9角色＋1警示映射、5停用/10保留、狐火A、完整署名、PCM0导入选项和精确猎户例外；第二条应唯一因猎户NC拒绝并返回非零，默认未传mode同样按commercial安全拒绝。清单sha256是含文件头的完整WAV；pcm_sha256是wave.readframes的交错小端PCM字节哈希。Godot通常导入为.wav.import/.sample，后续包检查应加载AudioStreamWAV.data比较PCM哈希及格式/帧数，不能假称原WAV文件头在PCK内可读。

药灵首帧2948/32768的点击风险仍待实听；峰值近似不保证感知响度一致。外部声音来自公开HQ MP3预览而非原始无损下载，警示为项目内合成。此验证不播放音频、运行游戏或联网，不等于真实事件去重、静音/暂停/倍速/死亡/重试、禁用项无加载/播放、听感、试听页或最终PCK验收通过。
