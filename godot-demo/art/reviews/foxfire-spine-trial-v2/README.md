# 狐火 Spine 小样 v2

2026-10-07。独立候选；原图来自 v1，未重绘或覆盖运行资产。本版将两条刚性腿改为大腿—小腿—脚的加权网格，并修复移动首尾脚位与待机不一致。

- [动画预览](review.html)：外部渲染，不能冒充 Spine 录屏或游戏截图。
- [验收标准与结果](ACCEPTANCE.md)：本轮专项自检、实际原生验证和运行接入边界。
- `foxfire-v2.json`：17 骨骼、12 槽、两张腿部网格；idle、move、basic_attack，以及 move_start / move_stop 辅助动作。
- `foxfire-v2-qa.json`：相同五动作，另加 25 秒 / 20 次切换的 `qa_switches` 验收序列。
- 图片使用相对路径 `../foxfire-spine-trial-v1/images/`；请保留 v1 与 v2 相邻位置。

## 打开

Spine → 左上菜单 → 导入数据 → 用文件夹按钮选择 JSON，缩放 1。可导入为新骨架并隐藏旧骨架。当前本机窗口已导入 QA 版，名称 `foxfire-v2-reviewed`；较早实验骨架 `foxfire-v2` 已隐藏。

输入数据由外部合法编写；不是 Trial 保存或导出的 `.spine` 工程。未绕过保存、导出或打包限制。本机入口见 [v1 原生接入记录](../foxfire-spine-trial-v1/NATIVE_ACCESS_20261005.md)。

## 重建与检查

需要 Python、Pillow、NumPy。依次运行本目录 `build_rig.py`、`build_transition_qa.py`、`inspect_rig.py`、`check_acceptance.py`、`render_transition_preview.py`。前两项生成输入，后几项产生独立数值报告与外部预览。任何动画更改后，应重新导入 Spine 检查；不能只靠脚本结果。
