# 换机器开发与项目交接

## 跨机器同步原则

- Gitee 仓库 `https://gitee.com/baiweicheng/tower-defense.git` 是跨机器共享项目文件和项目记忆的权威来源。
- Codex 聊天记录不是项目事实源；换机器后可以建立新的同职责任务，通过受 Git 管理的文档恢复上下文。
- 开始修改前先确认本机没有未处理改动，再从 `origin/master` 快进更新。
- 完成一批修改后更新对应工作流文档，创建 Git 提交并推送到 Gitee。
- `/tmp`、`/var/folders`、下载目录中的附件，以及任何未跟踪或未提交文件都不会随仓库同步。需要保留的图片或文件必须先放入仓库内的正确目录并提交。

## 首次获取项目

新机器先安装 Git、ChatGPT 桌面 App 和 Godot 4.7.x，然后执行：

```bash
git clone https://gitee.com/baiweicheng/tower-defense.git
cd tower-defense
git switch master
git pull --ff-only origin master
```

首次提交前配置本机的 Git 身份：

```bash
git config user.name "你的名字"
git config user.email "你的邮箱"
```

远端应显示为：

```bash
git remote -v
```

```text
origin  https://gitee.com/baiweicheng/tower-defense.git (fetch)
origin  https://gitee.com/baiweicheng/tower-defense.git (push)
```

使用 HTTPS 推送时，按 Gitee 的账号安全设置完成登录或使用私人令牌。不得把密码、令牌或本机凭据写进仓库。

## 在 Codex 中建立本地项目

1. 打开 ChatGPT 桌面 App，切换到 Codex。
2. 添加本地项目，选择刚克隆的 `tower-defense` 仓库根目录，而不是只选择 `godot-demo/`。
3. 如果项目附加了多个文件夹，将 `tower-defense` 设为主文件夹。新任务会从主文件夹启动，Codex 也会从这里识别 `AGENTS.md`、Git 仓库和项目配置。
4. 长期职责聊天选择 `Local`，让它们共同读写这个本地仓库。
5. 只有需要隔离并行代码修改时才选择 `Worktree`。Worktree 中的成果必须提交并合并，或交接回 Local，才算进入共享项目。

建议按顺序建立以下八个任务：

1. `00｜项目总控`
2. `01｜玩法与系统设计`
3. `02｜英雄 / 敌人设计`
4. `03｜关卡 / 数值 / 经济`
5. `04｜剧情 / 世界观`
6. `05｜美术 / 角色 / UI`
7. `06｜程序开发`
8. `07｜测试 / Bug / 发布`

新建 `01`～`07` 任务后，可发送以下初始化提示，并将最后一个文件替换为当前职责对应的工作流文件：

```text
请按 AGENTS.md 初始化当前职责。只依次读取 AGENTS.md、docs/PROJECT_STATE.md、docs/DECISION_LOG.md 和当前职责对应的 docs/workstreams/*.md，报告简短摘要后等待安排。不要扫描资产目录，不要打开图片或其他媒体文件。
```

`00｜项目总控` 使用：

```text
请按 AGENTS.md 初始化项目总控。读取 AGENTS.md、docs/PROJECT_STATE.md、docs/DECISION_LOG.md，并只检查各工作流文件中的“待总控同步”，报告简短摘要后等待安排。不要扫描资产目录，不要打开图片或其他媒体文件。
```

## 每次切换机器

离开当前机器前：

```bash
git status --short --branch
git push origin master
```

必须确认重要修改已经提交，且状态不再显示本地领先 `origin/master`。如果仍有未跟踪或未提交文件，先完成当前批次的整理、验证和提交；不要假设另一台机器能看到它们。

在另一台机器开始工作前：

```bash
git status --short --branch
git pull --ff-only origin master
```

如果工作区不干净、分支出现分叉或拉取失败，先停止修改并处理冲突，不要强制覆盖任何一台机器的内容。

完成新一批工作后：

```bash
git status --short --branch
git add <本批相关文件>
git commit -m "简洁描述本批修改"
git push origin master
```

Codex 应按照 `AGENTS.md` 自动完成提交和推送；以上命令用于人工检查或在需要时手动补充。

## 项目主入口

- 当前有效原型：`godot-demo/`
- Godot 项目文件：`godot-demo/project.godot`
- 主场景：`godot-demo/scenes/escort_route.tscn`（2026-09-30 起：不规则地图、A→B 护送、战中调度）；入口操作与原型参数以 `godot-demo/README.md` 为准。
- 旧固定棋盘对照场景：`godot-demo/scenes/main.tscn`，旧自动测试继续针对它；新模式专项为 `tests/escort_route_test.gd`，不得把旧回归通过当作新模式验收。
- 核心逻辑：`godot-demo/scripts/game.gd`
- 已确认设计：`docs/CONFIRMED_GAME_DESIGN.md`
- 第一章梳理：`docs/FIRST_CHAPTER_DESIGN.md`
- 当前美术状态：`godot-demo/art/ART_DIRECTION.md`

旧浏览器原型和“守粮仓”Godot 原型已经从当前项目删除；如需查阅，只能从 Git 历史恢复。

## Godot 环境准备

1. 安装 Godot 4.7.x Standard 版本。
2. 获取完整项目仓库。
3. 进入项目目录并运行：

```bash
cd godot-demo
godot --editor --path .
```

如果系统中的可执行文件名是 `godot4`，把命令中的 `godot` 换成 `godot4`。也可以在 Godot 项目管理器中导入 `godot-demo/project.godot`。

直接运行游戏：

```bash
cd godot-demo
godot --path .
```

## 验证环境

迁移后先运行两项测试：

```bash
cd godot-demo
godot --headless --path . --script res://tests/smoke_test.gd
godot --headless --path . --script res://tests/full_battle_test.gd
```

预期分别看到：

- `SMOKE_TEST_OK`
- `FULL_BATTLE_TEST_OK`

## 需要保留的文件

- `godot-demo/art/demo/`：当前 Demo 使用的战场与角色图集。
- `godot-demo/scenes/`：Godot 场景。
- `godot-demo/scripts/`：全部游戏逻辑。
- `godot-demo/tests/`：自动检查脚本。
- `godot-demo/project.godot`：项目配置。
- `docs/`：确认版设计与交接说明。

不需要跨机器复制 `godot-demo/.godot/`，Godot 会在新机器重新生成导入缓存。

## 当前 Demo 与正式设计的边界

- Demo 只实现一场四波 Boss 战，不代表第一章 7 难已经完成。
- Demo 中玉兔、青羽、铁角、黑狼和虎先锋等名称、技能与数值均为原型配置，不是最终内容名单。
- Demo 使用的明亮国风 Q 版美术仍在评估，不能据此直接批量生产正式资产。
- Demo 的目的，是验证商店、自动合成、合成锁、布阵、自动战斗、护送血量和战后结算是否好玩。
- 正式版本已经确认需要操作后自动存档，但当前单战 Demo 还没有实现存档系统。

## 已确认的下一步

1. 暂不批量制作正式英雄和场景素材。
2. 使用相同的角色、相同的场景和相同的构图制作几套画风对照方案。
3. 在游戏实际显示尺寸下比较角色辨识度、棋盘可读性和 UI 协调性。
4. 用户确认最终画风后，再开始第一章正式美术生产。

在画风确认前，可以继续讨论第一章英雄、敌人和关卡设计，但新图必须标记为探索稿。

## 迁移前检查

如果使用 Git 换机器，迁移前确认 `git status` 中的 Demo 图片、脚本、测试和文档都已经加入提交。只复制仓库但没有提交或复制未跟踪文件，会导致新机器缺少当前美术资源。
