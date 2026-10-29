# 熊山君普通攻击展示

双击 `launch.command` 启动。独立窗口只显示负责人选定的林间菱格棋盘和一只熊山君；熊会循环做右前正手攻击，播放原视频自带的声音。没有战斗、敌人、伤害或游戏菜单；原游戏不受影响。每张选帧按照源视频相对时间显示，视频画面到 3.500 秒结束后末帧再停留 0.35 秒。声音从每轮开头同步播放，不叠加其他音效。

本素材为试验候选，只使用源片中选出的 20 帧，按原时间显示也无法完整还原原视频的连续动作。源片两帧棍头出画已跳过，挥击有跳帧，原大挥击弧已移除。当前 PNG 使用 `godot-demo/art/candidates/bear_lord_matte_v2/` 的确定性边缘去白污染版本，20张均原样复制；对白圈和索引10–12的脚部浅色雾进行了局部光学校正，没有重绘角色或补画缺失武器。全帧深浅底及局部棋盘对照中白边减轻，仍有源片运动模糊和少量雾感；方法、前后图与限制见该候选 README。画布、脚锚、播放时间、角色比例和原声音轨不变。循环从最后一帧切回首帧，连续衔接尚待完善；实际连续接地与修正后的观感仍需负责人观察。

棋盘 `art/forest-board.png` 原样取自本仓库分支 `codex/full-board-art-prototype-20261019` 的 `godot-demo/art/reviews/painted-roster-demo-v2/assets/environment.png`（SHA-256 `7b568eb54ad25d18efa7dab24adcce833a4528940fdd615ca053196cd6ad1ed6`）；格线采用该展示的144×72菱格和中心位置。音频 `audio/source-track.wav` 来自 `godot-demo/art/candidates/bear_lord_video_attack_v1/forehand-7499-short-windup-v2.mp4` 的完整音轨，解码为44.1kHz立体声16位PCM，前置79个静音采样对齐视频音轨起始偏移，未叠加、变速、调音或另造声音；完整音轨约3.622秒，不超过3.85秒循环。视频音轨的商用授权尚未单独核实；此展示仅作项目内试验，未试听真实扬声器。

使用 Godot 4.7 可运行 `./launch.command --headless --script res://test.gd` 做帧序检查；需要图形采样时运行 `./launch.command --rendering-method gl_compatibility --script res://capture.gd`，20 张当前窗口渲染画面写入 `/tmp/bear-showcase-render/`。单帧采样不代替连续播放和实际听感检查。
