# 西游护送

西游题材的单人 PVE 游戏项目（Godot 4.7）。

## 当前方向（2026-11-10）

- **主攻方向：2.5D 制作**，以 [`bear-forehand-showcase/`](bear-forehand-showcase/) 为当前基准：斜视角林间棋盘＋由已审视频加工的逐帧角色动作，四个斜向（右前/左前/右后/左后，左向为脚锚镜像），统一脚点与显示倍率，原声同步。说明见 [该目录 README](bear-forehand-showcase/README.md)，素材加工流程见 [视频转游戏流程](docs/VIDEO_TO_GAME_WORKFLOW.md)。
- **之前的玩法原型已作废**：`godot-demo/` 中的棋盘自走棋试玩（及更早的 A→B 护送）不再迭代，仅作历史参考与共用素材来源；其中的规则、数值和入口不是当前设计基线。新方向的玩法范围待负责人重新确认，见 D-20261110-002。
- `c03-attack-showcase/`（翠鸟）等其他独立展示工程按同一 2.5D 素材方法制作，作为角色候选保留。

## 项目入口

- [`bear-forehand-showcase/`](bear-forehand-showcase/)：当前主攻的 2.5D 熊山君四方向攻击展示。
- [`docs/PROJECT_STATE.md`](docs/PROJECT_STATE.md)：跨聊天共享的项目阶段、优先级和阻塞项摘要。
- [`docs/DECISION_LOG.md`](docs/DECISION_LOG.md)：项目负责人已确认的跨领域决策记录。
- [`docs/CONFIRMED_GAME_DESIGN.md`](docs/CONFIRMED_GAME_DESIGN.md)：已确认设计（旧玩法部分已标注作废）。
- [`docs/DEVELOPMENT_HANDOFF.md`](docs/DEVELOPMENT_HANDOFF.md)：换机器、多聊天分工与初始化说明。
- [`AGENTS.md`](AGENTS.md)：协作规则（各聊天开工前必读）。

## 代码同步

**GitHub 是本项目唯一权威远端**：`https://github.com/badagou333/WestWardAutoChess.git`，共享分支 `main`。

```bash
git clone https://github.com/badagou333/WestWardAutoChess.git
cd WestWardAutoChess
git switch main
git pull --ff-only origin main
```

原 Gitee 仓库（`gitee.com/baiweicheng/tower-defense`）因项目体积过大已无法推送，**停止使用**，其上内容停留在旧提交，不代表当前状态；文档中提到 Gitee 的历史记录仅供追溯。

## 运行

安装 Godot 4.7.x Standard 后：

- 熊山君展示：Windows 双击 `bear-forehand-showcase/launch.bat`，Mac 双击 `launch.command`；或在仓库根目录执行 `godot --path bear-forehand-showcase`。
- 旧棋盘原型（已作废，仅参考）：`godot --path godot-demo`。

如果本机命令名是 `godot4`，将命令中的 `godot` 换成 `godot4`。
