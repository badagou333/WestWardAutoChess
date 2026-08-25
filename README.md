# 西游护送

一个结合棋盘布阵、自走棋战斗、塔防压力和队伍经营的单人 PVE 护送游戏原型。

当前仓库只保留 Godot 版本。玩家在 5×7 棋盘上围绕唐僧布置队伍，通过招募、刷新、升人口和自动三合一规划章节经济；开战后英雄自动走位、攻击和释放技能。

## 项目入口

- [`godot-demo/`](godot-demo/)：当前可运行的单战 Demo。
- [`docs/CONFIRMED_GAME_DESIGN.md`](docs/CONFIRMED_GAME_DESIGN.md)：只记录已经明确确认的玩法和范围。
- [`docs/DEVELOPMENT_HANDOFF.md`](docs/DEVELOPMENT_HANDOFF.md)：换机器运行、测试和迁移说明。
- [`godot-demo/art/ART_DIRECTION.md`](godot-demo/art/ART_DIRECTION.md)：当前美术确认状态。

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

- 单场四波 Boss 战可以完整运行。
- 商店、金币、人口、候选区、布阵、自动合成与合成锁已经接通。
- 自动战斗、暂停、倍速、战利品暂存和星级结算已经接通。
- 画风仍待确认；当前明亮国风 Q 版素材是探索方案，不是最终定案。

旧浏览器 Demo 和旧“守粮仓”Godot Demo 已从当前版本删除；需要时仍可从 Git 历史恢复。
