# 山狼｜新版二维手绘候选

日期：2026-09-30。状态：待负责人审核；单张静态待机造型，不是动画或生产包。

- 交付：[候选图](mountain-wolf-nine-sols-candidate.png)、[完整提示词](PROMPT.txt)。
- 方法：内置 imagegen 一次生成，原始PNG直接复制，未程序改色/清底。
- 身份参考：`godot-demo/art/concepts/mountain_wolf/mountain_wolf_concept_v1.png`。
- 画风参考：狐火小妖 `nine_sols_v1` 样例与护寺棍僧 `nine_sols_v1` 候选。学习二维描线、概括形体与平涂方法，不复制《九日》具体角色。
- 生成来源文件：`exec-36b4ad23-fb3d-43a1-bd45-d52cef3fd1b1.png`（内置生成目录；本仓库PNG为持久交付）。
- 保留识别点：四足灰褐山狼，米白胸腹、尖耳、长尾；不采用历史拟人铠甲狼。
- 检查：1536×1024 RGBA；alpha 0～254；alpha≥8边界框 (102,36,1487,994)，主体未触外边界。四图合成深浅底视觉复核无大块残底；透明像素隐藏RGB不应误判为光晕。
- 限制：鬃毛碎形仍偏多，下边留白较紧；棋盘缩小辨识及动作尚未验证。
- 当前未统一角色相对尺寸、画布锚点、动作与运行时；旧图、原生产包及程序保持不变。

整批审核及真实透明合成见 [交接说明](../../../reviews/nine-sols-escort-enemies-v1/README.md)。
