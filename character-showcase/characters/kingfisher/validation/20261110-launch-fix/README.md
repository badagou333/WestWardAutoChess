# QA-20261110-C03M-01 修复复测（launch.bat 不认 GODOT_BIN）

2026-11-10，06。删除 `launch.bat` 中位于“1) 优先使用环境变量 GODOT_BIN”判断之前的 `set "GODOT_BIN="`，其余不变。`bear-forehand-showcase/launch.bat` 有同样写法，一并删除。

复测：Windows 11，`cmd /c launch.bat --headless --quit`，未设 GODOT_CONSOLE。日志为 cmd 原始输出（GBK）。

| 项目 | GODOT_BIN=console 版 | 未设置 | 指向不存在的文件 |
|---|---|---|---|
| c03-attack-showcase | 输出“使用环境变量”，选用 console 版，exit 0 | 自动找到标准版 `…win64.exe`，exit 0 | 输出“不存在，改为自动查找”，选用标准版，exit 0 |
| bear-forehand-showcase | 同上 | 同上 | 同上 |

未验：双击启动的 GUI 窗口；引擎不在 PATH 和已知目录时的手动指定场景（本机已有默认安装）。
