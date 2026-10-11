# Blender 本机脚本接入验证

日期：2026-10-11。负责人安装 Blender 后要求检查能否接入。

已实际验证本机后台脚本通道：Blender 5.2.2 LTS 可创建网格、材质、两骨骼与一秒动画，保存 `.blend`，用 Cycles CPU 渲染 480×480 PNG，并导出带蒙皮和动画的 GLB。Godot 4.7.2 在独立项目中读入该 GLB，得到三网格、三蒙皮网格、两骨骼及 `probe_head_turn` 动画；推进0.45秒后头骨旋转变化约0.47994弧度。

这是工具连接测试，测试物由几何体组成，不是护寺棍僧造型或正式角色。未安装 MCP、Tripo 插件或付费服务；未修改 Blender 用户配置；未替换主游戏素材、程序、入口或角色动画。`.gdignore` 将本目录隔离于主项目资源导入。

## 文件

- `probe.py`：可重建的 Blender 脚本。
- `probe.blend`：实际保存的测试工程。
- `probe.glb`：三网格、两骨骼与动画的实际导出文件。
- `probe.png`：实际 Blender 渲染结果，已查看。
- `blender-result.json`、`godot-result.json`：实际执行结果。
- `project.godot`、`verify_godot.gd`：独立无窗口导入与动画推进验证。
- `validation.json`：本轮执行范围、首轮失败及独立结构核对。

## 重建

在本目录执行；最后的 `.` 是输出目录，文件会重建：

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --disable-autoexec --python-exit-code 1 --python probe.py -- .
/opt/homebrew/bin/godot --headless --path . --script verify_godot.gd --log-file /private/tmp/blender-integration-godot.log
```

使用其他电脑时替换两个软件的可执行路径。`.blend` 中保存的渲染路径属于首次临时工作目录，需通过脚本重建或调整 Render Output 后再渲染；脚本和 Godot 验证均按当前目录使用输入输出。

## 执行与边界

首轮 Blender 在受限运行环境的 Metal 设备初始化阶段崩溃，Python尚未运行；正常本机权限下同一脚本成功退出0。首轮 Godot 在受限环境无法创建用户日志目录，但模型和动画数据检查通过；正常本机权限复跑无错误并退出0。不能将最终成功表述为受限环境启动也通过。

独立只读 GLB 核对：glTF2文件头与实际21,996字节长度相符，三网格/三材质/一个skin/两关节，三个网格均有蒙皮且权重和为1；动画含变化的头部旋转采样。GLB SHA-256：`f36f0966f70ba41e59220c731b65d2dc84f557aa1f00b7591674d6fe69be7fd7`。

已证实的是脚本建模、Blender渲染、工程保存、GLB导出及Godot无窗口模型/蒙皮/动画读取。尚未验证 Blender 原生桌面自动操作、Godot三维画面、角色美术质量或当前游戏接入。下一步可在独立候选中试一名角色的三维造型，角色制作与棋盘迁移范围需另行安排。
