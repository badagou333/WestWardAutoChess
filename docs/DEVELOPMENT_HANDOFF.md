# 换机器开发与多聊天分工

更新时间：2026-11-10（GitHub 为权威远端；主攻 2.5D 熊山君展示；改用 Claude 项目聊天分工）

## 跨机器同步原则

- GitHub 仓库 `https://github.com/badagou333/WestWardAutoChess.git` 的 `main` 分支是跨机器共享项目文件和项目记忆的权威来源（D-20261110-001）。
- 原 Gitee 仓库 `https://gitee.com/baiweicheng/tower-defense.git` 因项目体积过大已无法推送，停止使用；其内容停留在旧提交。
- 聊天记录不是项目事实源；换机器或换聊天后，通过受 Git 管理的文档恢复上下文。
- 开始修改前先确认本机没有未处理改动，再从 `origin/main` 快进更新。完成一批修改后更新对应工作流文档，提交并推送到 GitHub。
- 下载目录、临时目录中的附件，以及任何未跟踪或未提交文件都不会随仓库同步。需要保留的文件必须先放入仓库内的正确目录并提交。
- GitHub 拒绝单个超过 100MB 的文件；大体积视频/母版素材入库前先确认大小，必要时改用 Git LFS 或仓库外存档并在说明中登记来源与哈希。

## 首次获取项目

新机器先安装 Git 和 Godot 4.7.x Standard（本机现用 `C:\software\Godot-4.7.2\Godot_v4.7.2-stable_win64.exe`），然后执行：

```bash
git clone https://github.com/badagou333/WestWardAutoChess.git
cd WestWardAutoChess
git switch main
git pull --ff-only origin main
```

首次提交前配置本机 Git 身份（`git config user.name` / `user.email`）。远端应显示为：

```text
origin  https://github.com/badagou333/WestWardAutoChess.git (fetch)
origin  https://github.com/badagou333/WestWardAutoChess.git (push)
```

不得把密码、令牌或本机凭据写进仓库。

## 在 Claude 中建立分工聊天

本项目在 Claude 项目「游戏开发」中沿用多聊天分工（D-20261110-003）。每个职责一个长期聊天，聊天标题使用下表名称，均在该项目内新建，并关联本机仓库目录 `C:\software\workSpace\WestWardAutoChess`。

| 聊天标题 | 工作流文件 | 当前方向下的重点 |
| --- | --- | --- |
| `00｜项目总控` | `PROJECT_STATE.md`、`DECISION_LOG.md` | 拆任务、汇总“待总控同步”、维护全局状态 |
| `01｜玩法与系统设计` | `workstreams/01-gameplay.md` | 为 2.5D 新方向重新提出玩法范围，待负责人确认 |
| `02｜英雄 / 敌人设计` | `workstreams/02-units.md` | 角色身份、机制与四方向动作需求 |
| `03｜关卡 / 数值 / 经济` | `workstreams/03-levels-balance.md` | 新玩法确认后再启动 |
| `04｜剧情 / 世界观` | `workstreams/04-story.md` | 世界观与叙事 |
| `05｜美术 / 角色 / UI` | `workstreams/05-art-ui.md` | 2.5D 棋盘与角色逐帧素材加工、视觉复核 |
| `06｜程序开发` | `workstreams/06-development.md` | 在熊山君展示基础上扩展 2.5D 运行逻辑 |
| `07｜测试 / Bug / 发布` | `workstreams/07-qa-release.md` | 独立验收、Windows 实机 |
| `08｜音效设计` | `workstreams/08-audio.md` | 音效与原声来源/授权 |
| `09｜Spine 动画` | `workstreams/09-spine.md` | 骨骼动画候选（按需） |
| `10｜项目清理` | `workstreams/10-cleanup.md` | 负责人确认范围内的归档/删除 |

不必一次建齐：先建 `00`，其他职责在第一次派工时再建。

### 初始化提示

新建 `01`～`10` 聊天后发送以下提示，把最后一个文件替换为该职责的工作流文件：

```text
你是本项目的「<聊天标题>」。项目在本机 C:\software\workSpace\WestWardAutoChess（GitHub badagou333/WestWardAutoChess，main 分支）。请按 AGENTS.md 初始化：只依次读取 AGENTS.md、docs/PROJECT_STATE.md、docs/DECISION_LOG.md（先看最新几条）和 docs/workstreams/<对应文件>.md，报告简短摘要后等待安排。不要扫描资产目录，不要打开图片或其他媒体文件。
```

`00｜项目总控` 使用：

```text
你是本项目的「00｜项目总控」。项目在本机 C:\software\workSpace\WestWardAutoChess（GitHub badagou333/WestWardAutoChess，main 分支）。请按 AGENTS.md 初始化：读取 AGENTS.md、docs/PROJECT_STATE.md、docs/DECISION_LOG.md（先看最新几条），并只检查各工作流文件中的“待总控同步”，报告简短摘要后等待安排。不要扫描资产目录，不要打开图片或其他媒体文件。
```

### 聊天之间如何交接

Claude 聊天之间不能直接发消息。专项完成或受阻时，把报告写进自己工作流的“待总控同步”，并在聊天末尾给出一段可转给 00 的简短回报；负责人把这段话贴给 `00｜项目总控`。00 每次工作都会检查全部工作流的“待总控同步”。详细规则见 `AGENTS.md` 的“主动交接与异常恢复”。

### 关于提交与推送

能在本机执行 git 的会话（例如 Claude Code，或具备本机 shell 的聊天）按 `AGENTS.md` 自动提交并推送到 `origin/main`。只能读写文件、不能执行 git 的聊天，须在回报中列出修改文件并注明“未提交”，由负责人或有 shell 的会话完成提交。

## 每次切换机器

离开当前机器前：

```bash
git status --short --branch
git push origin main
```

在另一台机器开始工作前：

```bash
git status --short --branch
git pull --ff-only origin main
```

如果工作区不干净、分支出现分叉或拉取失败，先停止修改并处理，不要强制覆盖任何一台机器的内容。

## 项目主入口（当前方向）

- 主攻：`bear-forehand-showcase/`，2.5D 熊山君四方向攻击展示（D-20261110-002）。
  - Godot 项目文件：`bear-forehand-showcase/project.godot`，主场景 `showcase.tscn`，逻辑 `showcase.gd`。
  - 播放配置：`clips.json`；正面素材 `art/attack/`，背面素材 `art/back/`，原声 `audio/`。
  - 详细说明与边界：`bear-forehand-showcase/README.md`。
- 同方法的其他角色展示：`c03-attack-showcase/`（翠鸟）。
- 素材加工方法：`docs/VIDEO_TO_GAME_WORKFLOW.md`；Skill 清单：`docs/GAME_PRODUCTION_SKILLS.md`。
- 已作废的旧玩法原型：`godot-demo/`（棋盘自走棋、更早的 A→B 护送）。仅作历史参考与共用素材来源，不再迭代。

## 运行与验证

Windows：双击 `bear-forehand-showcase\launch.bat`。它会依次查找环境变量 `GODOT_BIN`、PATH 中的 `godot.exe`/`godot4.exe`、`C:\software\Godot-4.7.2\`。带参数运行时在当前窗口执行，设 `GODOT_CONSOLE=1` 使用控制台版查看日志。

无界面测试：

```bat
bear-forehand-showcase\launch.bat --headless --audio-driver Dummy --script res://test.gd
```

Mac/Linux 用 `launch.command` 加同样参数。素材校验：`python bear-forehand-showcase/verify_front_v3.py --output=<输出json>`。更多检查与采样命令见该目录 README。

打开编辑器：`godot --editor --path bear-forehand-showcase`。不需要跨机器复制 `.godot/` 缓存目录。

## 当前边界

- 熊山君展示只有一只熊、四个方向的攻击动作，没有战斗、敌人、伤害或菜单；不代表新玩法已经确定。
- 新方向下的玩法、关卡、数值和美术规范都需由负责人重新确认；`docs/CONFIRMED_GAME_DESIGN.md` 中的旧玩法规则已标注作废。
- 视频原声的商用授权未核实，仅供项目内试验。
