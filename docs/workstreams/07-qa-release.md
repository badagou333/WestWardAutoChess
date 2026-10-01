# 07｜测试 / Bug / 发布

更新时间：2026-10-01
负责人聊天：`07｜测试 / Bug / 发布`

## 2026-10-01 无格子试验及保留功能独立验收（最新）

- 已完成：等待06本次新任务交付`9cccd6f`并确认Local干净后，独立执行7项自动专项、2项OpenGL图形输入专项、临时补充复现和200项PCK检查；涵盖`ec62ad9`保留功能。不改程序、不重打Windows包。
- 修改文件：本工作流、`docs/release/QA_FREE_ESCORT_20261001.md`；测试脚本、截图和日志仅临时目录。
- 验证结果：核心自动/图形脚本及PCK通过；发现P2：左键合法落点被选中角色上方点击框拦截，右键可下令。具体复现、矩阵、通关数据和证据边界统一见[独立验收报告](../release/QA_FREE_ESCORT_20261001.md)。不宣称整体或真人试玩通过。
- 新确认事项：无；执行00转交的自然地表补充要求，确认free模式使用独立去格新图、旧底图未覆盖。全局摘要仍停在试验未实现，待00据本批提交更新。
- 待确认：真人手感、随机经营难度、保守边界与可见岸边的精确一致性、完整动画及新远程发射音。
- 阻塞/限制：未发现P0/P1；P2待06处理。Windows实机、扬声器试听和完整人工连续试玩未验。
- 推荐下一步：00协调输入优先级问题，06修订后定向复验，再收集负责人两版对比反馈。

以下为历史发布流程与旧试玩包记录，不代表本轮试验已发布。

## 必读文件

- `docs/PROJECT_STATE.md`
- `docs/DECISION_LOG.md`
- `docs/DEVELOPMENT_HANDOFF.md`
- `godot-demo/README.md`

## 当前状态

- 已建立 Godot 4.7.2 的 Windows x86_64 Release 导出配置与一键构建脚本。
- 首个朋友试玩包使用内部标签 `0.1.0-playtest.1`；ZIP 为构建产物，不纳入 Git。
- 发布包内含独立 EXE、外置 PCK、试玩说明、已知限制、反馈模板、第三方署名与校验值。
- macOS 侧的交叉导出、PCK 启动和自动回归已通过；Windows 实机仍待验证。

## 待推进

- 为第一章流程、存档、失败回退和经济结算建立测试矩阵。
- 建立 Bug 状态、复现信息、回归结果和发布阻塞级别规范。
- 在 Windows 10/11 x86_64 实机完成启动、完整四波、音频、暂停与重开验收。
- 后续正式对外版本再确认发布渠道、签名与版本编号策略。

## 最近完成

- 新增 `Windows x86_64 Release` 导出预设，按运行时白名单打包脚本、美术与音频资源。
- 新增 `scripts/build_windows_release.sh`：校验干净工作区、Godot 版本、PE 架构、PCK 内容、PCK 启动、包内校验值与 ZIP 完整性。
- 新增 `scripts/inspect_godot_pck.py`：验证必需运行文件存在，并阻止测试、概念稿、制作工具和音频源文件进入 PCK。
- 生成 `西游护送-0.1.0-playtest.1-windows-x86_64.zip`，用于第一轮朋友试玩。

## 修改文件与验证

- 修改文件：`.gitignore`、`godot-demo/export_presets.cfg`、`godot-demo/README.md`、`godot-demo/release/windows/*`、`docs/release/WINDOWS_PLAYTEST.md`、`scripts/build_windows_release.sh`、`scripts/inspect_godot_pck.py`、本文件。
- 导出验证：Godot `4.7.2.stable` Release 导出成功；EXE 识别为 Windows PE32+ x86_64；PCK 启动未出现脚本解析或资源缺失错误。
- 包内容验证：PCK 共 148 项，必需场景、脚本、图集、音频和清单均存在；测试、概念稿、六角色审核目录、制作工具与音频源目录均未混入。
- 压缩包验证：ZIP 11 项、约 43.5 MiB；压缩完整性、EXE/PCK SHA-256 均通过。
- 自动回归通过：`smoke_test.gd`、`full_battle_test.gd`、`presentation_integration_test.gd`、`demo_integration_test.gd`、`wave_preparation_test.gd`、`audio_integration_test.gd`、`board_geometry_test.gd`、`recruit_ui_test.gd`。
- 脚本检查通过：构建脚本语法检查、PCK 检查器 Python 编译检查。

## 新确认事项

- 项目负责人要求继续产出可直接发给朋友的 Windows 试玩包；本批采用 `0.1.0-playtest.1` 作为首轮内部试玩标签。
- 本批未形成新的玩法或范围确认。

## 待确认事项

- Windows 10/11 实机兼容性、杀毒软件提示与双击启动体验仍需收集结果。
- 正式对外发布版本、发布渠道、代码签名和长期版本编号策略尚未确认。

## 阻塞项

- 目前没有 Windows 实机环境，无法在本批完成原生启动与完整四波人工验收。
- 当前 EXE 未签名，Windows 可能显示 SmartScreen 警告；不阻塞小范围熟人试玩，但不满足正式公开发布条件。

## 推荐下一步

- 在 Windows 10/11 x86_64 机器按 `docs/release/WINDOWS_PLAYTEST.md` 完成一次完整试玩，并回填系统版本、显卡、启动结果、四波结果与日志。
- 收到首轮反馈后，建立 Bug 严重级别与回归清单，再决定 `playtest.2` 是否需要修订。

## 待总控同步

- 2026-10-01：`9cccd6f`独立验收已完成本轮自动/程序驱动图形/临时PCK范围；P2左键落点冲突已复现，待协调。自然地表实际接入、旧图保留、两图进入PCK已核实；真人手感与精确贴岸仍未验，不能写整体通过。完整明细见本批报告。

总控同步标记（2026-09-30）：以下发布流程与旧玩法包状态已纳入PROJECT_STATE。默认入口已改不规则格子移动护送，新入口导出清单/PCK策略已接通并验证；本轮没有重建Windows ZIP，既有0.1.0-playtest.1仍是旧棋盘，不得当作新玩法包发给试玩者。新专项 `tests/escort_route_test.gd` 已通过，后续需重建包及Windows实机验收。

- 2026-09-30：首个 Windows 朋友试玩包与可复现发布流程已建立；macOS 交叉导出和自动回归通过，Windows 实机验收仍待完成。
