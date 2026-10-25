# D002 菱形格双角色 · 07 独立验收脚本

本目录只保存 07 为 D-20261018-002 自建的独立测试与紧凑证据，不覆盖 06 的
`tests/board-trial-runtime/diamond-duel-20261019/`，也不修改生产代码、数值、素材或 06 文件。

验收对象：`4982639d8a6a6cb538c478709037996daebb80bb`。引擎：Godot 4.7.2
(`4.7.2.stable.official.ed1daf0bf`)。全程 headless + Dummy audio；没有 OS 原生鼠标、
真实窗口截图、设备听感或 05 视觉结论。

## 文件

| 文件 | 用途 |
|---|---|
| `qa_geometry.gd` | 从 1344×576 内框与 192×96 菱格独立推导合法域；格心正逆映射、12,096 个屏幕采样、共享边两侧、26 个可见残格、四邻连通、真实 BFS 与 Stepwise 攻击格、旧 84 格不变 |
| `qa_duel.gd` | 实例化真实 `diamond_duel.tscn`；逻辑 InputEvent/Button 布置、跨阵营拒绝、右键/Esc、拖放、锁阵、暂停/倍速/重试/返回、6 局自然对打、源/包完整 report+trace 对比、低 HP 失败分支探针 |
| `qa_old_regression.gd` | 旧主棋盘/旧矩形/音效试场入口的 84 格、放置、0.50 秒移动与原始目录 |
| `qa_assets.py` | 17 帧运行 PNG 与 05 候选逐字节及解码 RGBA 对比；manifest 与 3 个排除帧 |
| `qa_source_assets.gd` | 源码模式实际导入纹理的 RGBA 表，供包内比较 |
| `qa_pack_assets.gd` | `--main-pack` 下 17 帧 RGBA、默认入口、无源 PNG/候选/测试/3D 回退 |
| `evidence.json` | 本轮关键计数、六局战报摘要、report/trace SHA、包 SHA/清单、旧入口结果与未验边界 |

## 复现命令

在仓库根目录：

```sh
GODOT=/opt/homebrew/bin/godot
$GODOT --headless --path godot-demo --script res://tests/qa07-diamond-duel-20261025/qa_geometry.gd -- --output=/tmp/qa-geometry.json
$GODOT --headless --path godot-demo --audio-driver Dummy --script res://tests/qa07-diamond-duel-20261025/qa_duel.gd -- --output=/tmp/qa-duel.json
$GODOT --headless --path godot-demo --audio-driver Dummy --script res://tests/qa07-diamond-duel-20261025/qa_old_regression.gd -- --output=/tmp/qa-old.json
$GODOT --headless --path godot-demo --audio-driver Dummy --script res://tests/qa07-diamond-duel-20261025/qa_source_assets.gd -- --output=/tmp/source-imported-assets.json
/Users/leqiong/.dsh/dsh-runtimes/dsh-primary-runtime/dependencies/python/bin/python3 godot-demo/tests/qa07-diamond-duel-20261025/qa_assets.py
$GODOT --headless --path godot-demo --export-pack 'Diamond Duel PCK' /tmp/qa-diamond.pck
python3 scripts/inspect_godot_pck.py /tmp/qa-diamond.pck --release-policy --usage noncommercial --diamond-duel --output /tmp/qa-pck-files.txt
mkdir -p /tmp/empty && cd /tmp/empty
$GODOT --headless --main-pack /tmp/qa-diamond.pck --audio-driver Dummy \
  --script /ABS/PATH/godot-demo/tests/qa07-diamond-duel-20261025/qa_pack_assets.gd -- \
  --expected=/tmp/source-imported-assets.json \
  --source-manifest=/ABS/PATH/godot-demo/art/runtime/diamond_duel_v1/manifest.json
```

`qa_pack_assets.gd` 与 `qa_duel.gd`/`qa_geometry.gd` 也可用同一 `--main-pack` 空工作目录方式
运行；本轮源码与包结果逐字段相同。PCK 不入库。

## 结果

- 几何：源码与包各 **25,860 检查 / 0 失败**，71 个完整格、26 个残格、12,096 个屏幕点、
  568 个共享边侧样本；71 格全部连通，真实 BFS 到每格。
- 布置/输入/对打：源码与包各 **3,998 检查 / 0 失败**；6 局自然对打全部 monk 胜、38 HP，
  每局 29 次攻击/命中、零双端占格重叠、0.50 秒/格；源/包完整 report 与 trace SHA 相同。
- 资源：17 帧运行 PNG 与候选逐字节/RGBA 相同，3 个排除帧缺失，0.34 统一缩放；包内 122 检查。
- PCK：重新导出 **400 项**，SHA-256
  `89d060a10a8d8463beb630859333446b845302cbd95d278fcc31ab329bb7d795` 与 06 摘要相同，
  文件清单与 `pck-final-files.txt` 完全一致；新候选、测试、独立 3D 未入包。
- 旧入口：本脚本 53 检查、透视 runtime 540 检查/9 局、音效试场 9 边界/6 局全部通过；
  8 个旧入口 headless 启动无脚本错误。

## 未验/阻塞

- 原生窗口/鼠标：**未做**。沙箱拒绝 `ps`，无法枚举/识别新窗口；无 cliclick/PyObjC；
  `screencapture` 只能全屏且无窗口 id/录屏权限许可；审批提示已禁用。详见 `evidence.json`。
- 05 实际视觉/连续步态/遮挡/血条、负责人真人体验、Windows、任意 DPI/拥堵、设备听感未验。
- 自然 1v1 在现有数值下总是 monk 胜；失败分支仅用测试专用 10 HP 探针验证，不是自然平衡结论。
