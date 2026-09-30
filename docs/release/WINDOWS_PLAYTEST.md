# Windows 试玩包发布流程

当前首个外发试玩版本为 `0.1.0-playtest.1`，目标平台为 Windows x86_64。它是四波单场原型，不代表第一章正式版本。

## 环境

- Godot 4.7.2 Standard。
- 对应版本的 `windows_release_x86_64.exe` 导出模板。
- 中文文本建议同时安装该版本的 `icudt_godot.dat`。
- macOS 默认模板目录：`~/Library/Application Support/Godot/export_templates/4.7.2.stable/`。

模板必须来自 Godot 官方 4.7.2 发布包。构建脚本会拒绝其他 Godot 版本。

## 构建

在仓库根目录执行：

```sh
./scripts/build_windows_release.sh 0.1.0-playtest.1
```

默认输出到 `build/windows/`；可用 `OUTPUT_DIR` 指定其他目录。正式发布要求 Git 工作区干净，ZIP 内的 `版本信息.txt` 会记录完整源提交。`ALLOW_DIRTY=1` 只用于提交前验证配置，不得用于对外交付。

脚本执行以下检查：

1. Godot 与模板版本匹配。
2. 导出 PE32+ x86_64 Release EXE 和独立 PCK。
3. 检查当前运行时需要的棋盘、角色、音效与声明资源。
4. 拒绝测试目录、概念图、独立审核场景、制作工具和第三方源音频进入 PCK。
5. 使用本机 Godot 无窗口加载导出的 PCK，验证主场景可初始化。
6. 生成 EXE/PCK 与 ZIP 的 SHA-256，并检查 ZIP 完整性。

构建产物不会提交 Git，也不会自动上传到公开位置。

## Windows 实机验收

交叉导出成功不等于 Windows 实机通过。至少在一台 64 位 Windows 电脑完成：

- 解压后直接启动，不依赖已安装 Godot。
- 1440×810 默认窗口文字和控件完整；再检查常用缩放比例或调整窗口大小。
- 商店购买、刷新、布阵、开战、波间整备均可操作。
- 暂停会冻结战斗和音效；1×/2×、音效开关与音量滑条有效。
- 至少完成一次四波胜利；另验证一次失败、结算和重新体验。
- 退出重开后无残留进度，符合当前“无存档”限制。
- 安全提示与“未知发布者”如实记录，不要求关闭防护软件。

完成实机验证后，将电脑配置、结果和发现的问题更新到 `docs/workstreams/07-qa-release.md`。
