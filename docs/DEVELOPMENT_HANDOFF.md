# 换机器开发与项目交接

## 项目主入口

- 当前有效原型：`godot-demo/`
- Godot 项目文件：`godot-demo/project.godot`
- 主场景：`godot-demo/scenes/main.tscn`
- 核心逻辑：`godot-demo/scripts/game.gd`
- 已确认设计：`docs/CONFIRMED_GAME_DESIGN.md`
- 第一章梳理：`docs/FIRST_CHAPTER_DESIGN.md`
- 当前美术状态：`godot-demo/art/ART_DIRECTION.md`

旧浏览器原型和“守粮仓”Godot 原型已经从当前项目删除；如需查阅，只能从 Git 历史恢复。

## 新机器准备

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
