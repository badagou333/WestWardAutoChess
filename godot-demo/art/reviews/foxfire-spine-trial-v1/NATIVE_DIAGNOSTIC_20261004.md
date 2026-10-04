# Spine 原生操作诊断：2026-10-04

本轮尝试原生导入现有狐火输入仍受桌面控制服务阻塞。素材、骨架数据、动画和外部预览均未修改；没有实际导入或原生播放证据。

## 已核实证据

| 检查项 | 结果 |
| --- | --- |
| 当前系统 | macOS 14.2 |
| Computer Use 组件 | `~/.codex/computer-use/Codex Computer Use.app`，版本26.929.1001365，构建1001365 |
| 组件声明的最低系统 | Contents/Info.plist 的 LSMinimumSystemVersion 为14.4 |
| 系统崩溃记录 | `~/Library/Logs/DiagnosticReports/SkyComputerUseService-2026-10-04-000332.ips`：00:03:32 +0800，macOS14.2，同版本组件，EXC_BAD_ACCESS / SIGBUS / KERN_PROTECTION_FAILURE，终止为 Bus error:10 |
| Spine 状态 | `/Applications/SpineTrial.app` 进程仍在运行；启动器4.3.08，应用日志记录Spine4.3.26 Trial已启动 |
| 最后一次受支持入口 | 重置cua会话后，以准确应用路径调用getApp；仍返回 `Sky Computer Use service startup request failed`，未取得窗口状态 |

当前系统低于已安装组件的最低版本要求，是明确的兼容性问题。崩溃记录不充分证明具体崩溃根因或唯一原因，也不能据此认定屏幕录制/辅助功能权限未开启。本轮未复制完整日志或崩溃报告。

## 恢复选择

- 若要继续由助手操作：由负责人安排把macOS升级到该组件支持的版本（至少14.4）；其他聊天工作结束后再重启Codex，核对Computer Use启用及屏幕录制/辅助功能权限，然后进行一次受支持入口检查。系统升级不保证其他问题同时消失。
- 若暂不升级：负责人可在Spine中手动按[README导入步骤](README.md#后续合法导入步骤尚未执行验证)导入当前 `foxfire-external-4.3.json`，检查Setup与三个动作。本记录不把这些尚未执行的步骤记为完成。

本轮未自行升级系统、替换组件、更改权限、强制关闭Spine、使用其他UI控制方式或绕过Trial保存/导出限制。现有GUI及自有文件写入窗口释放，待外部条件变化后再安排原生验证。

权限核对参考：[官方Computer Use文档](https://learn.chatgpt.com/docs/computer-use)。最低系统版本来自本机组件Info.plist，而非该网页。
