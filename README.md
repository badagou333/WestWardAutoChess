# 西游护送

一个结合棋盘布阵、自走棋战斗、塔防压力和队伍经营的单人 PVE 护送游戏原型。

当前仓库只保留 Godot 版本。默认启动“不规则格子地图＋A→B 移动护送”原型：唐僧沿路线前进，玩家实时调动队员拦截敌人；保留招募、刷新、升人口和自动三合一。地图现为玩法验证用简化地形，未采用最终场景美术，完整技能仍待实现。操作和试玩边界见 [Demo 说明](godot-demo/README.md)。

## 项目入口

- [`godot-demo/`](godot-demo/)：当前可运行的单战 Demo。
- [`docs/PROJECT_STATE.md`](docs/PROJECT_STATE.md)：跨聊天共享的项目阶段、优先级和阻塞项摘要。
- [`docs/DECISION_LOG.md`](docs/DECISION_LOG.md)：项目负责人已确认的跨领域决策记录。
- [`docs/CONFIRMED_GAME_DESIGN.md`](docs/CONFIRMED_GAME_DESIGN.md)：只记录已经明确确认的玩法和范围。
- [`docs/DEVELOPMENT_HANDOFF.md`](docs/DEVELOPMENT_HANDOFF.md)：换机器运行、测试和迁移说明。
- [`godot-demo/art/ART_DIRECTION.md`](godot-demo/art/ART_DIRECTION.md)：当前美术确认状态。

## 在另一台机器继续开发

Gitee 仓库是本项目跨机器同步的权威来源：

```bash
git clone https://gitee.com/baiweicheng/tower-defense.git
cd tower-defense
git switch master
git pull --ff-only origin master
```

然后在 ChatGPT 桌面 App 中切换到 Codex，添加该仓库根目录为本地项目，并将它设为主文件夹。长期的 `00`～`07` 职责任务使用 `Local`；只有确实需要隔离并行代码改动时才使用 `Worktree`。

不同机器和不同 Codex 任务不依赖聊天记录同步。开始工作时按 `AGENTS.md` 读取受 Git 管理的共享记忆；完成一批修改后必须提交并推送到 Gitee。临时附件、未跟踪文件和未提交修改不会自动出现在另一台机器上。

完整的 Codex 工作区建立步骤、任务命名、初始化提示和换机检查清单见 [`docs/DEVELOPMENT_HANDOFF.md`](docs/DEVELOPMENT_HANDOFF.md)。

## 运行

安装 Godot 4.7.x 后，在仓库根目录执行：

```bash
godot --path godot-demo
```

打开 Godot 编辑器：

```bash
godot --editor --path godot-demo
```

如果本机命令名是 `godot4`，将命令中的 `godot` 换成 `godot4`。

## 当前状态

- 不规则地图四段护送可以完整运行，原固定棋盘场景保留作对照。
- 商店、金币、人口、候选区、布阵、自动合成与合成锁已经接通。
- 战中点击/拖动下达移动令、格子占用寻路、自动攻击、暂停、倍速和逐段结算已接通。
- 沿用现有角色动作与已采用音效；新地形是程序绘制的玩法样板，不代表最终画风。

旧浏览器 Demo 和旧“守粮仓”Godot Demo 已从当前版本删除；需要时仍可从 Git 历史恢复。
