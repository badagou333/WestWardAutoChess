# 西游护送 · 双模式试玩

默认入口仍是格子版`scenes/escort_route.tscn`；新增无格子半自动**对照试验**`scenes/free_escort.tscn`，不是最终玩法替换。两版共用十个新版角色、四段遭遇、三个营地和经营系统。当前仍是可玩原型，不是完整第一章；未实现章节存档、完整英雄技能或连续逐帧动画。

当前完整分发包含棋盘猎户的Robinhood76新声（CC BY-NC 4.0），**仅供本次非商业试玩**。这不是商用许可；未来商业版须换源或取得许可，其他素材仍分别按原CC0/CC BY许可。完整署名随[CREDITS.md](CREDITS.md)及[当前棋盘音效声明](audio/runtime/board-selected-20261010/ATTRIBUTION.md)分发，不只保留在候选目录。

## 启动

需要 Godot 4.7.2 Standard（Compatibility 渲染）。Mac 双击 `launch.command`，Windows 双击 `launch.cmd`，或在仓库根目录运行：

```sh
godot --path godot-demo
```

启动器需要本机安装引擎。旧 `scenes/main.tscn` 固定棋盘保留作对照；经营规则与角色素材共用新版，不再保留旧免费券/五候选玩法。

## 独立菱格双角色小样（2026-10-19，作者自测）

双击`launch-diamond-duel.command`，或运行`godot --path godot-demo --audio-driver Dummy res://scenes/diamond_duel.tscn`。只保留护寺棍僧、山狼各一名：点击左侧角色卡，再点完整菱格布置；成功放置自动清选，另一阵营占格拒绝，右键/Esc取消。开始后真实自动接敌/攻击/扣血，支持P暂停、1×/2×、同阵重试和返回开战前布置；战斗及暂停均锁阵。无唐僧、增删单位、经营或技能，不替换任何旧入口。声音默认静音/Dummy，原声表和非商业用途限制保持。

横向矩形场地内有71个完整192×96菱格；绘制、正逆映射、布置、四邻、搜索和实际移动使用同一合法格集合。残格/石框不吸附到可走格。整数轴坐标是格心，`(-1,-1)`也是合法格，失败拾取另用`(-9999,-9999)`；这套坐标不改变旧矩形棋盘。角色节点保持1倍，原PNG以脚锚只乘一次0.34，未加旧0.72或逐帧缩放。只复制05推荐的17帧，未推荐3帧及镜像不用；仅棍僧斜前的两张腿姿交替，其余为有限移动姿势，受击闪光/退场淡出沿用原反馈，不冒称完整步态/死亡动画。未知、遮挡、腾空脚底仍为空，不画虚构足点。原HP/伤害/射程/攻速、命中时钟、0.50秒格段和双端占格不变。

作者source/实际PCK各6925几何检查通过；新小样source3151、pack3177检查/各5局完整真实对打通过，含四向、远近与边缘、30FPS/2×/暂停、原事件时钟/唯一占格/锁阵与重试。5局完整报告及攻击/命中/声音事件包源相同，原主棋盘9局、音效试场9边界/6局、旧7入口与旧整局最小回归保持。证据与准确边界见[本批摘要](tests/board-trial-runtime/diamond-duel-20261019/summary.json)。首几何脚本类型解析失败及完整修复复跑留证，不把退出0误算通过。

本轮已在获授权的专用1440×810新窗口采集[布置](tests/board-trial-runtime/diamond-duel-20261019/actual-window/01-deployment.png)、[接近](tests/board-trial-runtime/diamond-duel-20261019/actual-window/02-approaching.png)、[起手](tests/board-trial-runtime/diamond-duel-20261019/actual-window/03-attack-windup.png)、[实际扣血](tests/board-trial-runtime/diamond-duel-20261019/actual-window/04-actual-contact.png)、[即时结果](tests/board-trial-runtime/diamond-duel-20261019/actual-window/05-result.png)，均为实际OpenGL/Metal Viewport，不是离线合成。作者查看布置/接触/结果，格心归属、角色尺度、HUD与实际HP变化可辨；即时结果帧不是退场淡出完成证据。**原生鼠标、连续视觉/05、07独立及负责人体验仍未验**，不把5张图称为完整动画通过。

本批实现/资源/证据已按持续授权提交并推送`origin/master`，工作区干净。此前两次限定提交审批超时（含一次允许的重试）确已发生并保留在本工作流与summary中；恢复后未绕过审批、未强推、未改历史。

首次图形启动遇系统XPC限制；随后自动审批服务一度容量不足。服务实际恢复执行后，先按本轮日志路径核对并停止唯一失败PID30013，再成功运行专用采集并自行退出；未绕过审批、换模型或操作用户原窗口。额外补采审批超时未执行；未提交未运行的额外测试，无设备听感。`diamond_duel_capture.gd`只允许真实图形后端保存Viewport，拒绝headless假截图。

独立导出预设为`Diamond Duel PCK`，自定义feature只改变该包的默认入口；旧Windows预设与源工程默认护送不变。最终临时包`/tmp/diamond-duel-20261019.1lR3WG/diamond-duel-final.pck`共400项，SHA仅维护本批summary；未分发EXE/ZIP，PCK不入Git。为验证旧入口，该包也保留原有入口依赖，但本批只增17帧/运行manifest/程序，不含原候选、源图、审阅图、测试或独立3D工程。

```sh
godot --headless --path godot-demo --script res://tests/diamond_duel_geometry_test.gd -- --output=/tmp/duel-geometry-source.json
godot --headless --path godot-demo --audio-driver Dummy --script res://tests/diamond_duel_test.gd -- --output=/tmp/duel-source.json
godot --headless --path godot-demo --export-pack 'Diamond Duel PCK' /tmp/diamond-duel.pck
python3 scripts/inspect_godot_pck.py /tmp/diamond-duel.pck --release-policy --usage noncommercial --diamond-duel --output /tmp/duel-pck-files.txt
```

包内复核必须直接调用引擎，不经启动器；在新建的空目录作工作目录和`--path`，传`--main-pack /tmp/diamond-duel.pck --script <仓库绝对路径>/godot-demo/tests/diamond_duel_test.gd -- --expect-packed --source=/tmp/duel-source.json --output=/tmp/duel-pack.json`。该测试核包默认入口、拒绝宿主原PNG/源码fallback，逐帧比较实际导入RGBA及完整战斗事件。图形采样需审批恢复后以专用新窗口运行`--script res://tests/diamond_duel_capture.gd -- --output=/tmp/duel-window`，不能用离线合成替代。

## 当前棋盘：正面轻透视森林石台（2026-10-17）

双击`launch-board-trial.command`，或运行`godot --path godot-demo res://scenes/board_trial.tscn`。仍是12×7、左友右敌，原布阵/选择/换位/R撤下/右键取消、暂停倍速和重试均保留；不是把概念图误画的14列变成玩法。普通启动器仍进护送，旧矩形棋盘、独立音效试场和独立狐火3D工程保持原入口。

场景使用05交付的[干净底图](art/boards/perspective_stage_v1/scene-clean.png)，按[HANDOFF](art/boards/perspective_stage_v1/HANDOFF.md)的0.92缩放+(120,110)起始标定接入，没有叠加旧平台/灯/台阶。准确网格、范围/选中提示和点击逆映射共用单应投影；可玩范围按逻辑`[0,12)×[0,7)`半开域，石框、立面、台阶及森林不接收布阵。人物移动先在逻辑格间按原0.50秒连续插值再投影，围脚点平滑远近缩放；身体不压扁/斜切。影子、排序、血条锚高及弹道发射/命中同步，HUD文字与条宽保可读像素。原十角色正背面关键姿势、攻击/弹道时钟、AI/射程/数值/声表/胜败均保持。

作者无窗口source/实际PCK各完成9824项几何、963项逻辑视口输入、1234项十角色方向、1555项显示/动作与24自然局对照；实际新场景A/R/B两调度含暂停倍速与旧矩形/历史完整report、攻击/发射/接触和声音事件时序保持。实际包另24配置自然局与固定历史一致，9音频PCM/19语义、音效试场9边界/6自然局及7入口启动通过。证据为`tests/board-trial-runtime/board-perspective-20261017/`。首次夹具/解析/浮点及JSON索引失败和修正记录保留，不冒称首跑通过。

本轮只无窗口：三档960×540、1280×720、1440×810验证的是逻辑视口映射与事件注入，不是OS鼠标、任意DPI或实际渲染验收；未操作用户已有窗口、播放设备声音或制作离线假截图。远排实际可读性、武器越格/前后遮挡和风格化轮廓影仍交05真实画面复核，07独立及负责人体验未完成。旧[正背面交付预览](art/production/directional_v1/README.md)与[旧石台预览](art/boards/depth_trial_v1/README.md)保留历史，不当当前轻透视运行截图；原关键姿势非完整跑步动画、药灵点击及Windows等未验限制保持。

本批临时PCK为`/tmp/board-perspective-20261017.pck`（可重建，不入Git），实际353项；只新增有效底图及必要程序，不带本批HANDOFF/integration/review/概念候选，仍仅非商业试玩。源码检查示例：

```sh
godot --headless --path godot-demo --script res://tests/board_frontal_projection_test.gd -- --output=/tmp/board-perspective-geometry.json
godot --headless --path godot-demo --script res://tests/board_depth_input_test.gd -- --output=/tmp/board-perspective-input.json
godot --headless --path godot-demo --script res://tests/board_directional_test.gd -- --output=/tmp/board-perspective-direction.json
godot --headless --path godot-demo --script res://tests/board_depth_test.gd -- --output=/tmp/board-perspective-depth.json
godot --headless --path godot-demo --script res://tests/board_perspective_runtime_test.gd -- --output=/tmp/board-perspective-runtime.json
godot --headless --path godot-demo --export-pack "Windows x86_64 Release" /tmp/board-perspective-20261017.pck
python3 scripts/inspect_godot_pck.py /tmp/board-perspective-20261017.pck --release-policy --usage noncommercial --output=/tmp/board-perspective-files.txt
```

包内测试必须直接调用引擎，以新建空临时目录作为工作目录及`--path`，加`--main-pack`和绝对host测试脚本；不要经启动器带入源码`--path`。`board_trial_pack_boot.gd`先跑源码取`stage.decoded_rgba8_sha256`，包内须显式传`--expect-packed --expected-stage-pixels-sha=<该值>`；它拒绝宿主原PNG和测试源码回退，并检查交接/review/独立3D不入包。这是导入纹理像素校验，不虚称包内含原PNG头。其余包测试也在同一隔离条件执行；runtime加`--baseline=<仓库绝对路径>/godot-demo/tests/board-trial-runtime/board-balance-20261009-natural.json --source=/tmp/board-perspective-runtime.json`。旧`audio_integration_test.gd`源码先用`--output`保存原文件/实际导入sample证据，包内用`--expect-packed --source-audio=<该证据绝对路径>`逐项对照，不拿不存在的原WAV头作包内哈希。正常窗口/原生鼠标检查须另获允许后才运行；`board_depth_input_test.gd --native-pointer`会操作指针，默认分支不会。

## 独立音效试战（2026-10-10，非商业试玩）

Mac双击[launch-audio-trial.command](launch-audio-trial.command)，或在仓库根目录运行：

```sh
godot --path godot-demo res://scenes/audio_trial.tscn
```

默认一名棍僧对一只山狼，不强制唐僧。左侧分别选我方/敌方类型、数量后“添加”；每方最多6个（仅试場实施默认），可有同种多个，底栏按唯一实例ID选择。点选地图单位或底栏实例，再点空格/拖动移位；双方战前都能放在全棋盘合法格，同阵营可交换、跨阵营不能覆盖。右侧删除选中，右键/Esc取消；成功移位后释放选择，不因随后松手二次放置。空一方/越界/超过容量会给出理由。战中及暂停锁配置；如要增删，先“返回布置”。

上方复选“我方声／敌方声”可听双方、只听一方或全关；只过滤实际声音输出，攻击/AI/伤害/有效治疗/结束结果不变，已过滤的旧攻击不会在打开后补播。切换阵营只阻止后续事件输出，已在播放的尾音会自然结束。唐僧受伤警示按唐僧所属一方过滤。还有静音/音量、P暂停及1×/2×；2×不变调。当前9资源/10事件与正式棋盘同一声表、同一真实战斗触发，不是点播WAV；死亡/战斗结果仍禁加载/请求/播放，英雄退场无新声，保完整NC署名。

“治疗试听预设”提供药灵＋初始50%HP棍僧＋远处灰鼠；也可选友方设50%/100%初始血量。辅助仅此试场、清楚标记并随阵位重试保存，最大HP/伤害/CD不变；必须真实恢复HP>0才播放治疗声，满血不伪播。试场以一方全灭结束（同时全灭失败优先），不是正式唐僧死亡胜败规则。无输出组合可能久战，可返回布置手动停止，不设超时假胜或自动复活循环。同阵重试直接恢复所选实例/落点/初始HP后开战；返回布置恢复开战前配置，清空只布置阶段允许。开关、音量与阵营听声设置保留，旧弹道/死亡/结果/声音账本清除。

作者source/实际PCK各9边界、6真实自然局通过：四filter完整1v1报告相同（14.55秒），2×/暂停报告保持，多棍僧/多狼独立实例与6/6容量、真实药灵回血、唐警过滤、逻辑输入和控件回调覆盖。正式D001 A/R/B两调度完整报告/source与包均保持，旧入口声音最小回归通过。重复棍僧步态只增加按node找到自身Actor的小hook，正式原有唯一实例等价，不重写战斗/选敌/寻路。证据`tests/board-trial-runtime/audio-trial-20261010-*`保首次5个UI兼容字段回调失败及修正后完整结果，不称第一次通过。

最终临时包`/tmp/audio-trial-20261010.pck`实际301项，含新scene/controller/UI/filter与现9声10事件，非商业资源策略通过，未制作EXE/ZIP/Windows发行。当前只无窗口，未开GUI、操作用户鼠标/已有Godot或Spine、播放设备/录音；逻辑InputEvent和Button回调不是OS指针/渲染/实际聆听验收，待07本试場独立及负责人亲自听。不关闭原GUI/药灵点击/动画P3等限制。正式入口/旧模式默认不替换，08在用试听页不改。

```sh
godot --headless --path godot-demo --script res://tests/audio_trial_test.gd
godot --headless --main-pack /tmp/audio-trial-20261010.pck --script /absolute/repo/godot-demo/tests/audio_trial_test.gd -- --output=/tmp/audio-trial-20261010-pack.json
```

## 12×7单关布阵对照（2026-10-15，2D斜视石台）

Mac双击`launch-board-trial.command`，或在仓库根目录运行：

```sh
godot --path godot-demo res://scenes/board_trial.tscn
```

玩法仍为独立单关、公开固定敌阵，不替换默认护送；无经营/营地/人口上限/主动技能。默认为加强六怪＋一只熊山君，保原六怪／强化六怪／强化＋熊配置，开战后锁定。**本节下方13帧样板及旧显示对照为2026-10-09交付历史，只在legacy入口保留；当前主入口是上方2026-10-17轻透视及十角色16姿势版，旧动画切换按钮禁用。** 请自行关闭旧试玩窗口再重开，旧进程不会自动更新；未新增Boss技能。

历史显示阶段见[松风台2D斜视棋盘记录](art/boards/depth_trial_v1/README.md)：2026-10-15固定0.9尺寸和当时未补背面的限制、938项/635项图形输入及旧包预览只证明该阶段，不代表当前轻透视已做GUI验收。10月17日正背面素材已另行接入，本轮保留使用；当前深度缩放、证据及未验范围以本页顶部新节为准。旧矩形对照使用`launch-board-legacy.command`或`scenes/board_trial_legacy.tscn`，默认护送和独立音效入口保持。

### D-20261010-001 · 当前声音：短狼与死亡／结果静音

当前profile为`board-selected-noncommercial-20261010`，schema2；[新运行清单](audio/runtime/board-selected-20261010/manifest.json)仅9个实际WAV/10事件：九角色行为共8主声＋唐僧遇险警示。山狼采用已确认的第一声短版`wolf_first_call.wav`，12789帧/0.290秒，原切点、速度、音高、增益保持；选材/裁剪唯一权威为[08本批HANDOFF](audio/candidates/wolf-first-call-v1/HANDOFF.md)。旧2.415669秒完整声和旧09目录留备用，不进入本版有效表或当前包。

当前棋盘不请求、不播放、不加载`rat_death/boar_death/wolf_death/bear_lord_death/victory`，不新增失败/结果声，也不加载或补用旧UI/通用材质声。专用Audio不调用旧父类初始化（它会加载旧整套并合成victory），只经固定10键/9路径白名单加载；通用播放只许唐警，主声仍走原实例＋固化serial去重。原死亡动画/淡出/节点释放、唐僧死亡失败、全敌清除胜利、结果界面/数据/重试保持。其余攻击/有效治疗/唐警、声音开关/音量/暂停/倍速pitch1和两个8槽池仍在，不因静音结果删玩法。下方D006长狼/死亡/胜利/UI/唐材质保留口径仅历史，已由本条授权替代。

新9 WAV与对应源完整SHA及原PCM一致，9份`.wav.import`固定无损PCM、不变率/声道/不修剪归一化/循环，源码冷启动直接读原WAV，不依赖未生成的导入cache；实际PCK加载导入sample，核PCM SHA/16bits/44100/通道/完整帧数，不能假称包内有原WAV头。猎户NC仍仅本次非商业试玩、固定新运行路径＋原SHA；八外部来源的完整署名与短狼裁剪说明、项目内唐警来源随包；唐警未虚称CC0。商业默认检查仍拒，未泛放其他NC。

作者无窗口source/PCK各9资产/19语义、6禁载/死亡边界及A/R/B双调度6自然局，全部执行零失败：四类实际原攻击致死后退场淡出/节点free，独立记录实际加载和声音请求，生产死亡/胜败全过程五禁键为0请求/0调度/0加载；手动五禁拒绝另列隔离夹具，不混作生产请求。A18.616667秒胜/唐148、R25.416667胜/唐168、B7.175秒败/唐0，完整report与原黄金报告一致；重试/暂停/原警示保持。旧入口音效最小回归通过，仍可使用其旧v1资源；这些旧资源在共享PCK中不等于当前棋盘加载。最终临时`/tmp/board-audio-short-20261010.pck`实际293项，非商业策略通过、商业默认拒，旧09/候选/试听/源/备份排除。证据在`tests/board-trial-runtime/board-audio-{short,silence}-20261010-*`。

原`audio/audition/current-game-20261010`页/生成器/清单本批不改，仍可能展示旧14声快照；须本交付后由00交08更新实际9声10事件，不能把旧试听表当当前运行证据。没有GUI、鼠标、设备试听或Windows发行；实际听感、药灵原首帧点击及旧动画P3等仍待本人许可/独立复核。

```sh
godot --headless --path godot-demo --script res://tests/board_trial_audio_test.gd -- --skip-natural --output=/tmp/board-audio-short-20261010-core-source.json
godot --headless --path godot-demo --script res://tests/board_trial_audio_silence_test.gd
python3 scripts/verify_board_audio.py --mode noncommercial
godot --headless --path godot-demo --export-pack "Windows x86_64 Release" /tmp/board-audio-short-20261010.pck
python3 scripts/inspect_godot_pck.py /tmp/board-audio-short-20261010.pck --release-policy --usage noncommercial --output /tmp/board-audio-short-20261010-pack-files.txt
godot --headless --main-pack /tmp/board-audio-short-20261010.pck --script /absolute/repo/godot-demo/tests/board_trial_audio_test.gd -- --skip-natural --output=/tmp/board-audio-short-20261010-core-pack.json
godot --headless --main-pack /tmp/board-audio-short-20261010.pck --script /absolute/repo/godot-demo/tests/board_trial_audio_silence_test.gd -- --baseline=/absolute/repo/godot-demo/tests/board-trial-runtime/board-balance-20261009-natural.json --output=/tmp/board-audio-silence-20261010-pack.json
```

### 历史D006 · 2026-10-09声音接入（长狼／死亡结果口径已替代）

本入口专用`board-selected-noncommercial-20261009`声表；8个原选WAV映射9个行为，棍僧/熊共Qat，狐火保持A，药灵用新版，猎户必须用已确认第2段。精确素材参数唯一权威为[08 HANDOFF](audio/candidates/selected-20261009/HANDOFF.md)，运行副本/来源/许可在[audio/runtime/board-selected-20261009/](audio/runtime/board-selected-20261009/manifest.json)，旧v1/候选/备份及旧入口默认声音不改。左侧“声音：开/关”和音量条控制全部新旧声音；顶栏标非商业试玩，“帮助→声音署名”查看完整第三方声明。实际输入和显示可读性未作图形验收。

唯一主声时机：棍僧/熊/狼/猪实际正伤害；猎户/山雀/狐火实际发射；灰鼠实际投石正伤害（发射无主声）；药灵实际恢复HP>0；唐僧不新增主声。实例ID＋攻击请求时固化、随事件携带的serial去重，晚到弹道不读当前新serial；同serial的两狼、棍熊共文件不互吞，溅射多目标/重复回调不重复。选表攻击不叠旧主声/材质层；唐伤警、原死亡/UI/胜利及未替换唐攻击材质保持，未虚构原棋盘不存在的失败/UI触发。静音/零音量/暂停/容量丢弃也消费本事件，不在恢复时补播；重试清账本/尾声，保音量与开关，2×不变调变速。

并发策略：原8条非替换反馈音轨保留，另8条主声音轨，合计16，均受同一开关/音量/暂停与原限幅器控制。山狼完整2.415669秒，不裁尾、不变速；同单位后续攻击可用空槽叠尾。主声满8槽时丢新声，不抢断已有主尾，也不占/抢UI、死亡、唐警池，无延迟队列。`stats/audit`记录请求/播放调度/重复/静音/暂停/丢弃/过期，primary抢占数为0；无窗口极速推进自然局的拥挤计数受真实墙钟影响，**不是实机丢音率或混战听感结论**。药灵原非零首帧2948/32768可能点击，保原选哈希，真人聆听仍待。

8 WAV完整文件SHA与08选版逐字节一致；本批8个`.wav.import`明确保存无压缩PCM/不单声化/不改率/不修剪/不归一化/不循环，跨机器沿用，不让Godot默认压缩改变选声。最终PCK只存导入sample而非原WAV头，因此包内核对加载的16-bit/44.1kHz/通道/完整帧数与PCM SHA，原WAV SHA作为清单来源记录，不能冒称包内原WAV文件哈希已读。首包压缩导致18项格式/PCM失败，修导入配置后source/PCK各8资产、19语义反例、熊A/R两调度4自然局全部通过，完整游戏report与D002原证据一致；旧声音回归通过。证据见`tests/board-trial-runtime/board-audio-20261009-{source,pack,material-license}.json`，首次失效日志/首包失败报告保留。

最终临时`/tmp/board-audio-20261009-final.pck`实际291项，载入新profile/8声音、可见用途文字及完整署名；只显式`--usage noncommercial`通过资源/许可策略，默认commercial及篡改猎户路径/哈希或扩其他NC均拒绝。未来Windows构建脚本也默认commercial拒本声音，只本次非商业用途显式`RELEASE_USAGE=noncommercial`；本轮未生成EXE/ZIP/发行包。候选HQ源/参考/备份不入包；原已授权v1/狐火运行资源为保持旧入口而继续在包中。未打开GUI、试听、录音或测实际设备/峰值；事件/无损/用途通过不等于游戏听感、07独立、旧D002/D003视觉/P3或Windows通过。

```sh
godot --headless --path godot-demo --script res://tests/board_trial_audio_test.gd
python3 scripts/verify_board_audio.py --mode noncommercial
godot --headless --path godot-demo --export-pack "Windows x86_64 Release" /tmp/board-audio-20261009-final.pck
python3 scripts/inspect_godot_pck.py /tmp/board-audio-20261009-final.pck --release-policy --usage noncommercial --output /tmp/board-audio-20261009-final-pack-files.txt
godot --headless --main-pack /tmp/board-audio-20261009-final.pck --script /absolute/repo/godot-demo/tests/board_trial_audio_test.gd -- --baseline=/absolute/repo/godot-demo/tests/board-trial-runtime/board-balance-20261009-natural.json --output=/tmp/board-audio-20261009-pack.json
```

### 既有D004与玩法／动画说明

2026-10-09 D004待机朝向小修：熊山君atlas0实际源左，却被整套manifest的right标签误镜像成右；仅当前棋盘`board_trial_bear_view.gd`在实际取0帧时修正绘图X轴，包含攻击起手/收势用0帧的阶段。开场/无目标等待/重试逻辑敌方向左，0帧正确显示左向；实际目标在右时仍可转右，不锁死方向。1—4帧原变换、逻辑facing、脚点/socket、所有时钟/数值/寻路与旧模式不改。敌情/详情头像修前也实际镜像，且无窗口逐字节核实idle.png与atlas0完全相同，因此同一缺陷的两处头像按原生左源显示；未重画或改共享manifest。18帧/朝向矩阵、4真实移动/攻击/暂停/死亡重试活动与熊A/R两局完整报告均通过，包内同一专项也通过；A18.617秒/唐148、R25.417秒/唐168与原D002完整report一致。当前临时包为`/tmp/board-bear-facing-20261009.pck`，实际269项含新适配，资源策略通过；紧凑证据`tests/board-trial-runtime/board-bear-facing-20261009-{source,pack}.json`。只看过授权的一张源atlas，无图形窗口/鼠标/截图，几何与源像素事实不冒充实机连续视觉验收；待07本小修独立复核，原GUI/05视觉/P3待验保持。

旧矩形版表现说明（当前仅legacy及沿用旧显示的入口，主棋盘以本页顶部轻透视说明为准）：底图`art/boards/formation_trial_v2/board-courtyard.png`（1672×941）映射到`Rect(0,-12,1920,1128)`，画布裁到1920×1080；仅背景纵向拉伸/裁剪，棋盘、角色及输入不动。旧v1保留，不把生成概念整图用作UI。底图来源、映射与样式权威见[05 v2交接](art/boards/formation_trial_v2/README.md)和`integration.json`；程序独立UI/真实头像裁切/细血量条在`scripts/presentation/board_trial_{ui,portrait,meter}.gd`，配色及场上HUD在`board_trial_style.gd`。头像只裁当前production/idle.png，不采用错误人脸/漂移头像/虚构防御或概念数值。重要正文22—24、次级18—20逻辑像素。

界面：顶栏为唐僧实时HP、阶段、计时、暂停/倍速/帮助；左窄A/B/C、对照选项和短键鼠提示；右上按所选配置显示三／四类敌情动态数量，点类型可轮看同类，E1—E6及熊E7可直接看具体单位，右下显示选中实时HP/攻或疗/间隔/射程/目标编号/格位/状态，仅己方战前显示可用R撤下。底部六个真实头像卡含编号/姓名/HP细条/部署或战斗状态，右下主开始/次重试；结果后主按钮查看战果，完整六人伤害/治疗/阵亡统计可关闭并重开。帮助按需展开，遮挡时不向棋盘/按钮透传鼠标或部署键，Esc关闭；不强制暂停自动战斗。操作失败原因短时在棋盘下方显示，不常驻版本号或大段规则。原点放/拖放/交换/取消语义保持。

朝向：战前和无目标默认友军右、敌军左，换阵/重放/重试恢复；实际攻击、治疗及移动按目标转身，不整场锁右。按各素材source_facing只镜像一次；狐火源左需翻，狼/猪源左保持，灰鼠源右需翻。`face()`继续使用表现父坐标系目标点，不把相对点误改成全局点；socket不再乘source_sign。新棋盘仅在projectile_released时将原父空间发射点经`view.parent.to_global → combat.to_local`计入0.72演员缩放，改显示from/position，不改目标、释放/命中时序或伤害；共享攻击模块/时钟与旧入口未改。

D-004药灵例外由实际像素而非错误shared manifest/right决定：atlas0/idle实际左，只在本入口`board_trial_healer_view.gd`对所选frame0的绘图X轴翻一次，原点/逻辑facing/socket不翻；头像同idle明确source_left。治疗起手前0.30windup及最后0.30recover会使用frame0，也按该帧处理；治疗主姿势frame2实际右、move1右保持。hit3按05中置信结论保留原行为，退场4俯首低置信、不未经证据翻转；不宣称全部动作已正式视觉通过。原PNG/共享manifest、旧模式不改。

- 战前左6列部署，坐标为从1开始的(列,行)。默认A阵放好唐僧＋五名一星英雄，可选名单/1—6后点格子，或拖动已部署者；目标已有友军则原子交换。第7列及棋盘外拒绝，原位置/库存不变。R/“撤下选中”可撤下（不出售），右键/Esc取消。唐僧必部署，其他英雄可不上场，不设五选三限制。敌阵不能编辑，左侧A/B/C按01交接切站位，属性和敌阵相同。
- D-005输入收尾：点地移动、点友军换位、库存放置或拖放成功后释放对原英雄控制，清选中/拖拽/选中框/射程，不自动选目标友军；后续须重新选人。失败/非法落点保原英雄与数据，棋盘外松手只结束拖拽标志。纯点选自己看详情、敌情查看及R撤下原语义保持；帮助/战中含暂停拒绝不触发成功清选。正常悬停边框不属于选中，不删除。数据`place()`仍只处理守恒，成功清选仅在输入包装层。
- 开战自动战斗，只可查看、P/按钮暂停、1×/2×、棍僧显示对照及重试；拖放、点地、右键、R/F不能调队或补位，暂停不解除锁阵。左6列仅战前限制，棍僧/三远程可合法跨中线。唐僧/药灵驻留及治疗血比/距离/ID规则保持。棍僧、狼、猪、熊统一使用`combat/board_trial_melee.gd`的同一策略：无目标/死或不可达按当前可达攻位成本→ID重选，无路就当前位置等待/原SCAN重试；棍僧不再受AGGRO3/LEASH2、专属永久锁/2秒长堵或自动归锚控制。初始anchor仅保留部署/重试/阵亡统计用途，原锚点专属画面标记已去除。详细规则以[01第3/5节](../docs/workstreams/01-gameplay.md)为准。
- 逐格移动：原六怪配置10个、加熊配置11个可移动演员每次落格后重评目标与攻位。更近按到合法攻击格的可达路径步数判断，严格更短才换敌，同成本保旧；已经在射程内的目标成本0，继续驻留按原CD攻击。近战沿原现目标可攻优先/邻敌ID/严格成本规则，三远程与灰鼠在实际落格时进行一次重评；没有落格的普通idle刷新仍保持合法旧锁，不在移动/攻击半段换敌。未进入射程时，Stepwise搜全部当前攻位，比较完整移动及已知等待时间，只提交下一相邻格；最低成本首步依接近当前目标→等价提示→稳定方向，不锁旧终点。唐僧/药灵仍驻留。
- 调度：全员落格、旧伤害/死亡处理后收集请求，按需求首次等待时刻→ID统一批准下一段；排队不提前改格/朝向/活动。冲突者尝试等成本空闲首步或等待，不因抢格失败清目标。源格、目的格在整个0.50秒中唯一占用；不因为其他人也请求离开就允许对向交换。只有已发活动的源格有确定释放时间，目的格落地后继续占用。所有角色有独立通行活动序号，有限等待在真实完成/取消/死亡后重评；不预测目标未来攻击位置。五近战原互锁距2交接仍保留，只观察本批提交前已存在的那一步，射程仍为1。
- 四向寻路、曼哈顿射程，无地形障碍/弹道遮挡。各演员按自己的实际落格时间重评，不同步成半秒回合。原0.25秒选敌/空闲重试时机与原攻击冷却保持，已发移动/攻击活动安全走完。真正僵局不强制超时胜利，状态可查看并重试；年龄优先只保证本批请求排序，不承诺任意封堵必解。
- 本场死亡不治疗复活、不补位、取消该来源待生效事件；整步结算先判唐僧死亡，再判全敌清除，同步死亡优先失败。英雄全灭但唐僧活着仍继续。结果只一次，无金币奖励；只继续视觉收招/淡出，不继续结算伤害或战斗计时。重试恢复双方全员，回**上次开战前部署**，不是战斗结束位置；清空目标/预约/冷却/弹道/死亡/结果/暂停倍速，不用旧跨营地阵亡账本。

可调参数权威实现：`scripts/data/board_trial_config.gd`，配置版本`board-v5-legacy`／`board-v5-normal`／默认`board-v5-bear`；近战标签`melee-stepwise-20261009`、远程标签`ranged-step-target-20261009`保持。仅棋盘按类型精确覆盖下表数值，不再乘第二次倍率，系数仍1；共享`enemy.gd`、我方HP/伤害/攻速/射程及旧护送保持。全员移动0.50秒/格，唐僧/药灵仍驻留；STEP1/120、SCAN0.25及寻路/选敌/调度未调整。熊复用现有bear_lord造型和基础普攻，纳入近战、单步占格、死亡释放、敌情/实际参数报告与结果/重试。

| 类型 | 原六怪：HP／伤害／攻击间隔 | 强化：HP／伤害／攻击间隔 | 射程 | 公开一基初始格 |
| --- | --- | --- | --- | --- |
| 山狼 E1/E2 | 155／14／0.90秒 | 180／17／0.90秒 | 1 | (8,2)／(8,6) |
| 山猪 E3/E4 | 96／10／1.10秒 | 120／12／1.10秒 | 1 | (9,3)／(9,5) |
| 灰鼠 E5/E6 | 52／7／0.95秒 | 65／9／0.95秒 | 3 | (11,2)／(11,6) |
| 熊山君 E7 | 不加入 | 280／20／1.20秒（仅加熊配置） | 1 | (10,4) |

以上为03经00批准的本轮试验起始值，不是负责人确认的最终平衡。A/B/C保留；R为测试/手动调整的支援阵，不新增一键预设，依唐/棍/猎/雀/药/狐顺序为(2,4)/(5,4)/(4,3)/(4,5)/(3,4)/(4,4)。三配置各四阵在37FPS×1、60FPS×2＋暂停共24局真实AI、38400 STEP，完整报告及逐角色真实承伤/有效治疗/剩余HP/首次接战/阵亡一致。下列承伤为全友军实际HP损失合计，不含溢出伤害；详细逐角色账只维护[自然报告](tests/board-trial-runtime/board-balance-20261009-natural.json)。

| 配置 | 阵 | 胜败 | 唐僧HP | 秒 | 友军承伤／有效治疗 | 友军阵亡 |
| --- | --- | --- | --- | --- | --- | --- |
| 原六怪 | A | 胜 | 300 | 11.825 | 417／189 | 狐火 |
| 原六怪 | B | 败 | 0 | 10.100 | 370／0 | 唐僧 |
| 原六怪 | C | 胜 | 300 | 10.558 | 361／168 | 山雀 |
| 原六怪 | R | 胜 | 300 | 10.383 | 331／148 | 无 |
| 强化六怪 | A | 胜 | 300 | 15.367 | 648／288 | 狐火 |
| 强化六怪 | B | 败 | 0 | 6.300 | 348／0 | 唐僧 |
| 强化六怪 | C | 胜 | 283 | 14.217 | 612／197 | 山雀、狐火 |
| 强化六怪 | R | 胜 | 300 | 11.533 | 484／178 | 无 |
| 强化＋熊 | A | 胜 | 148 | 18.617 | 811／360 | 狐火 |
| 强化＋熊 | B | 败 | 0 | 7.175 | 368／0 | 唐僧 |
| 强化＋熊 | C | 败 | 0 | 18.508 | 1040／197 | 唐僧、山雀、药灵、狐火 |
| 强化＋熊 | R | 胜 | 168 | 25.417 | 1152／413 | 棍僧、山雀、狐火 |

熊四阵均实际走格、攻击并产生HP减量，胜阵需要其真实死亡。已有A/R可胜，未触发全败后的额外阵位/220HP备选回调，也未使用340档。旧ABC完整战斗报告除新增配置元数据外与07已提交D001报告一致，历史JSON不覆盖。11项[配置/熊边界](tests/board-trial-runtime/board-balance-20261009-boundaries.json)通过；首轮熊同速但错开一STEP的夹具前提已纠正，未改生产让测试过关。

棍僧样板只取`art/reviews/animation-samples-20261004/guard_monk/{manifest.json,body-atlas.png}`：3328×256、13个256格、源右、脚点(128,218)，当前演员0.72/脚底原点不改。idle0/1/0，walk2—5各0.125秒与真实0.50格段同步，attack6—9/0、hit10/0、death11/12单次淡出；共享攻击0.54秒、0.235秒接触阈值/帧8及每serial一次14伤害不改。专用board monk view适配真实格段与hitstop后的步态，切换不重建View、不消费姿势边界或重置时钟。6组真实活动夹具和三配置ABC的9组旧/新/120FPS×2＋暂停反复切换、共27自然局完整战果相同，见[动画技术报告](tests/board-trial-runtime/board-monk-sample-20261009.json)。

D002/D003当批最终临时PCK实际包含熊idle和13帧样板、新View/标签，267项资源策略通过、五入口启动通过；包内三配置A/B/C/R旧/新显示共24局完整报告与源码一致，含暂停/切换/重试与熊死亡节点释放后的详情，见[包内运行报告](tests/board-trial-runtime/board-balance-20261009-pack.json)。随后07在3da136e独立无窗口阶段通过，不是渲染/视觉或整体验收通过；新D004包项数以上方实际清单为准。当前GUI许可仍等待负责人本人回答，未开图形窗口、采截图/连续片段或执行已适配的输入专项；旧支撑脚滑移、握距/站姿跳变及review WebP导入P3未关闭，05实机视觉、正常输入、真人手感与Windows仍待。详情/参数正确不证明新布局可读性已通过。

### 历史D001：落格换敌（以下为旧六怪原数值证据）

2026-10-09落格换敌作者验证：`board_trial_step_target_test.gd`完成五远程×左右镜像×六类60个隔离边界，核真实半格保锁/0.50秒落格换更近、同成本与range0保持、直线近但绕路更长不换、死亡/重试/无落格idle、实际攻击活动与原CD。七初阵全12真实AI两调度/暂停下全report、发段、等待与完成时间线一致，共19640个STEP、622次完整0.50秒格段；原26单步/78近战＋活腾格、远程真实追击/伤害/射程/CD、基础回归和263项PCK/五入口/A局通过。远程长追旧断言不再强保“灰鼠永远追唐僧/英雄必须追到第7列”，改验实际离射程后确实追击、最后当前目标range3驻留；保全部真脑和原能力断言。必要证据为`tests/board-trial-runtime/board-step-target-20261009-{boundaries,natural}.json`，基线直接引用下方已提交逐格版报告，不覆盖历史数据。

| 部署 | 逐格版→落格换敌版秒数 | 新结果 / 唐僧HP / 阵亡 |
| --- | --- | --- |
| A | 10.875→11.825 | 胜 / 300 / 狐火 |
| B | 10.100→10.100 | 败 / 0 / 唐僧 |
| C | 10.558→10.558 | 胜 / 300 / 山雀 |
| D006 | 12.025→12.025 | 胜 / 300 / 棍僧 |
| D007 | 12.125→12.367 | 胜 / 270 / 狐火 |
| 11.55 | 12.667→12.725 | 胜 / 300 / 狐火 |
| 21.37 | 12.125→12.233 | 胜 / 300 / 山雀 |

新的换敌规则改变击杀顺序，A新增狐火阵亡、11.55山雀存活、两录屏唐僧HP改变；未改数值保旧战果，不据此确认正式平衡。本批仍为作者无图形窗口验证，07独立/Windows及新版真人体验待安排。

历史逐格版作者验证：新专项26个隔离边界涵盖10移动演员、全部等价首步、旧攻位合法但更远、途中入射程、必要绕障、同格/对向/年龄/备选、在途源格等待和驻留角色拒绝；七原初阵全12真实AI在30FPS×1与120FPS×2＋暂停下，完整report、实际发段、等待原因及格段完成时间线一致。每轮9657个STEP、302次完整0.50秒格段，安全断言全保；20个横纵0.25半程/0.50落格动作夹具继续通过。基线在改程序前由`dba3f4d`实际运行，完整report与已有同速报告逐字段相同。新旧必要证据为`tests/board-trial-runtime/board-stepwise-20261009-{baseline,boundaries,natural}.json`，旧报告不覆盖。

| 部署 | 同速旧版→逐格版模拟秒 | 逐格版结果 / 唐僧HP / 阵亡 |
| --- | --- | --- |
| A | 9.525→10.875 | 胜 / 300 / 无 |
| B | 11.067→10.100 | 败 / 0 / 唐僧 |
| C | 12.017→10.558 | 胜 / 300 / 山雀 |
| D-006录屏布阵 | 12.875→12.025 | 胜 / 300 / 棍僧 |
| D-007录屏布阵 | 11.875→12.125 | 胜 / 262 / 狐火 |
| 11.55录屏布阵 | 10.725→12.667 | 胜 / 300 / 山雀、狐火 |
| 21.37录屏布阵 | 11.533→12.125 | 胜 / 276 / 山雀 |

21.37原初阵棍僧先(4,4)→(4,3)→(4,2)，1.008秒争格未获准就等待，1.508秒E1实际靠近后原地range1接战，未为了旧攻位往上折返。后期换敌仍会回头；七局未经语义筛选的前后相反格段次数为旧6/新13（包含换敌和长时间攻击后移动，不等于无谓折返次数）。D007山雀有一组连续回头：发上步时队友尚未承诺腾格，随后队友真的移动释放道路，新一格重评改走下方；不假称所有动态往返已消除或本批观感必更优。伤害/HP没有暗调保成绩，真人体验与07独立验收仍待。

历史同速版本验证：`board_trial_uniform_movement_test.gd`核10个可移动演员，20个横/纵隔离动作夹具均在0.25秒到半程、0.50秒完整落格，暂停中段不推进，换阵/重试保持统一值；隔离夹具明确禁用脑，不冒充自然战斗。七份原部署各运行30FPS×1与120FPS×2＋暂停，全12真实AI、原HP/伤害/攻速，每STEP检查双端占用唯一、完整格段、脚点/真实射程、唐药驻留；完整report及已完成移动时间线一致。两轮共19108个STEP、582次实际完成格段均通过，紧凑报告见`tests/board-trial-runtime/board-uniform-movement-20261009.json`，历史报告不覆盖。

| 历史同速版本部署 | 结果 | 唐僧HP | 阵亡 | 模拟秒 |
| --- | --- | --- | --- | --- |
| A | 胜 | 300 | 无 | 9.525 |
| B | 败 | 0 | 唐僧 | 11.067 |
| C | 胜 | 300 | 山雀 | 12.017 |
| D-006录屏布阵 | 胜 | 300 | 棍僧 | 12.875 |
| D-007录屏布阵 | 胜 | 300 | 狐火 | 11.875 |
| 11.55.10录屏布阵 | 胜 | 300 | 山雀 | 10.725 |
| 21.37录屏布阵 | 胜 | 300 | 山雀 | 11.533 |

同速改变真实接战时机：B从此前5HP险胜变为失败，D-006布阵也新增棍僧阵亡；没有暗调伤害/HP维持旧结果。基础、AI、五近战活动交接、统一近战78边界＋2真实腾格、四敌、三远程、朝向与旧格子/自由护送定向回归通过。临时PCK的261项资源策略及五入口启动/实际A局/同速配置通过；本批为无图形窗口作者自测，没有真人观感、07独立或Windows验收，也未实施前述协作寻路候选。

历史D-20261008-002（其选敌/冷却沿用，以下路线缓存由逐格版替代）：棍僧与E1/E2狼、E3/E4猪共用原D-007策略，不是只扩大旧警界。可打旧目标含CD优先驻留；否则合法邻敌按ID接战，其他追击在原SCAN比较候选与旧目标各自fresh可达攻位成本，严格更短才换、同成本保旧。同目标先trim完成段，再严格短于有效余缓存才替换，等长保留，失效重算；换敌清旧等待/路线但不重置CD，同目标缩路不取消已观察活动。无预测/半格瞬停/穿人或强配对，原棍僧310HP/14伤害/0.5秒每格/1.15秒攻击间隔/range1保持。帮助改为全棋盘主动近战，不再展示3/2或短堵归锚。

以下为统一速度之前的历史对照：全部12演员真实AI、相同六份原部署/敌阵/属性，D-20261008-001→002完整自然战果；公共30FPS×1、120FPS×2及中途暂停的完整report/攻击时刻/棍僧所有发段记录一致。当时A/B/C都胜，不代表当前同速版本战果，也不据此称正式平衡或站位价值已充分验证：

| 部署 | 结果 / 唐僧HP / 阵亡，旧→新 | 旧→新模拟秒 | 旧→新友军伤害 / 有效治疗 |
| --- | --- | --- | --- |
| A | 胜300/无→胜300/无 | 12.217→10.358 | 606/206→606/138 |
| B | 败0/唐僧→胜5/无 | 11.383→11.517 | 525/0→606/0 |
| C | 胜300/雀狐亡→胜300/雀狐亡 | 13.267→13.150 | 606/62→606/24 |
| D-006录屏布阵 | 胜300/棍僧亡→胜300/无 | 12.667→11.925 | 606/98→606/84 |
| D-007录屏布阵 | 胜300/狐火亡→胜296/狐火亡 | 13.092→11.500 | 606/0→606/52 |
| 11.55.10录屏布阵 | 胜300/雀狐亡→胜300/雀狐亡 | 15.325→14.500 | 606/168→606/48 |

新录屏初阵（一基唐2,4/棍1,5/猎2,2/雀3,4/药1,4/狐2,6）沿用已核诊断，不重开媒体。旧棍僧3.508秒才因E4入警界发步/4.508首攻，新0.008333首步(1,5)→(1,6)选E2，3.008333秒首次真正range1攻击；全局最远离初始anchor6格，未强制穿友军直走，该局最右仅第5列，跨中线另由A/B/C等自然实轨及边界检验。

`board_trial_melee_unified_test.gd`核棍僧/狼/猪×左右镜像78个原属性等状态边界；当前可攻/多邻敌ID、fresh严格换敌/同成本保（不拿旧缓存作成本）、同目标短/等长/trim/失效、死/无路/SCAN原格等、格段/攻击先完、互锁距2观察/同tick完成续段/预约/暂停全部通过。主程序另补棍僧同目标真实道路释放2组：猎户原AI真正完成释放源格后合法range3驻留，E1实际range1/CD驻留，棍僧0.500秒第一格完成后有效余路5→fresh3步，未换敌掩盖缩路；夹具CD100/零基/开战后明确状态，非自然平衡。原四敌8组道路释放与五近战活动边界继续通过。

六局新旧完整报告/旧第六局来源见`tests/board-trial-runtime/board-melee-unified-20261008-comparisons.json`，每STEP检查后的初态/改变演员及棍僧发段见`board-melee-unified-20261008-natural-traces.json`，策略/真实腾格记录为`board-melee-unified-20261008-boundaries.json`。旧第六局完整自然15.325秒从27aa2d6原controller+原Melee临时副本重跑两帧率，仅改preload路径；原A与已提交旧report逐字段相同确认副本身份，7秒诊断不是终局。新`melee_rule=melee-unified-d20261008-002`，配置与ranged tag保持；旧JSON不覆盖。最终261项PCK实际六report与源码相同，新入口及输入/药灵/旧模式定向自测通过，待07本提交独立验收，不替代真人/Windows。

历史D-20261008-001三输出（合法旧锁由本次落格严格短成本规则局部替代）：猎户/山雀/狐火按最短可达攻击位路径成本→稳定ID选敌，保持仍存活可达的目标，不因更近者出现换锁；死亡/不可达才重选，无路在原SCAN等待。超距按灰鼠逐格接近，到真实射程3按原冷却驻留攻击，目标真正脱离可继续追。三者无部署AGGRO/LEASH或自动归锚，原整格/攻击活动先完成、四邻双端预约、弹道/狐火溅射/朝向与数值保持；不加入近战缓存/互锁等待/风筝后退/未来位置预测。历史细则见01，本批新确认交00同步。

历史D-007→D-20261008-001五份完整报告如下（不是本批最新结果）；30FPS×1、120FPS×2及中途暂停完全重复，没有硬保旧JSON或宣称正式平衡改善：

| 部署 | 结果 / 唐僧HP / 阵亡，旧→新 | 旧→新模拟秒 | 旧→新友军伤害 / 有效治疗 |
| --- | --- | --- | --- |
| A | 胜 / 300 / 无→无 | 13.383→12.217 | 606/236→606/206 |
| B | 败 / 0 / 唐僧→唐僧 | 7.150→11.383 | 90/20→525/0 |
| C | 胜 / 300 / 山雀→山雀、狐火 | 13.517→13.267 | 606/133→606/62 |
| D-006录屏布阵 | 胜 / 300 / 棍僧→棍僧 | 20.283→12.667 | 606/279→606/98 |
| D-007录屏布阵 | 胜 / 300 / 无→狐火 | 13.300→13.092 | 606/120→606/0 |

新旧五局完整逐角色/事件时刻报告见`tests/board-trial-runtime/board-ranged-20261008-comparisons.json`，旧基线直接取已提交D-007五局，不重做历史录屏诊断。`board-ranged-20261008-natural-traces.json`保存初始全员快照及每次改变的演员（未列演员状态持续），每STEP核预约唯一、原段安全提交、实际射程/脚点、唐僧药灵不动与guard边界；另有三输出隔离动态专项。新报告增加`ranged_rule=ranged-pursuit-d20261008-001`，`melee_rule`仍为D-007、Config仍board-v1-base。历史JSON保留，不新增媒体。

隔离动态`board_trial_ranged_pursuit_test.gd`六例：三英雄/灰鼠等存活者全跑原AI，灰鼠0.591667秒真实脱离射程后，英雄各走7段越中线/离anchor7格，在猎户4.558333、山雀5.025、狐火5.033333秒进入最终range3驻留尾段，原CD/每击伤害及跨帧率活动证据通过；合法目标不抢、死/不可达成本→ID、SCAN无路恢复、安全段/攻击/双端预约、暂停/重试也有边界断言。另一次狐火实际弹道对相邻两敌各损20、指标40，range1溅射保持。夹具明确零基、post-start高HP10000与holder/core CD100（溅射双鼠CD10），并非自然布阵/平衡、不是冻结敌脑；必要35KB记录为`board-ranged-20261008-boundaries.json`。三窗口输入、成功清选、药灵/旧模式和261项包五报告自测通过，07本提交独立验收待执行。

历史D-007仅扩四敌近战，棍僧当时保旧锁敌/缓存；当前D-20261008-002已将棍僧并入同策略，旧棍僧排除断言不再现行。以下D-007/D-006轨迹与报告只供追溯，不能当当前首次接战对象/时刻预期。

历史D-006→D-007完整自然战果如下（不是本批最新结果）；30FPS×1、120FPS×2及中途暂停报告/事件时刻重复一致：

| 部署 | 结果 / 唐僧HP / 阵亡 | 旧→新模拟秒 | 旧→新友军伤害 / 有效治疗 |
| --- | --- | --- | --- |
| A | 胜 / 300 / 无 | 11.283→13.383 | 606/178→606/236 |
| B | 败 / 0 / 唐僧 | 7.150→7.150 | 104/0→90/20 |
| C | 胜 / 300 / 山雀 | 13.517→13.517 | 606/133→606/133 |
| D-006录屏布阵 | 胜 / 300 / 棍僧 | 24.158→20.283 | 606/286→606/279 |
| D-007新录屏布阵 | 胜 / 300 / 无 | 11.475→13.300 | 606/48→606/120 |

D-007初阵依次唐僧(2,4)、棍僧(4,4)、猎户(2,3)、山雀(3,4)、药灵(1,4)、狐火(2,5)，左上1基。棍僧随后走至(4,3)，不是开场(4,3)；录屏时钟含启动，以下为模拟时刻。旧E4始终锁棍僧，3.508秒(5,4)追棍僧9步、山雀/狐火各3步仍绕行；道路腾空后6.308秒(5,2)新近路1步、旧余路5步仍走(5,1)，从未真正落(4,2)，不能称range1漏attack。新局E4在2.808秒(5,5)从棍僧新成本6切到狐火4，5.608秒真实接战，五次攻击、实际伤害50；山雀同成本4，按原ID不保证优先山雀。新旧行动线/时长/治疗因此改变，不称平衡改善或全局零必要绕行。

两项分开验证：`board_trial_enemy_pursuit_test.gd`覆盖四敌严格换敌/同成本保持及真实邻敌、在途/攻击/CD/交接。独立道路释放夹具让对手真实走完且继续自己的AI，同一目标始终最佳，旧有效余路5步缩为3步；E1/E2在0.525秒边界、E3/E4在0.700秒边界改走新近路，30×1/120×2一致，不用自然换敌让第二项未覆盖。夹具为高冷却100秒/零基布局，明确不是自然平衡证据；等长路线/完成前缀修剪与guard仍保旧路也有断言。

新旧五局完整报告在`tests/board-trial-runtime/board-d007-comparisons.json`，全五近战逐STEP检查后的连续离散状态、四敌重评前后成本/路径/原因/攻击及旧E4四个关键时刻/完整旧报告保存在`board-d007-enemy-traces.json`；独立分项动态记录为`board-d007-boundaries.json`。只保存必要JSON，不复制整录屏或旧8MiB临时1377步资料/图片。报告新tag为`melee-pursuit-d007`、Config仍board-v1-base；历史D-006 JSON保留。

历史D-006真实自动战斗（以下为旧交付，不是D-007当前结果）：

| 部署 | 结果 / 唐僧HP / 阵亡 | D-004→D-006模拟秒 | 友军伤害 / 有效治疗，旧→新 |
| --- | --- | --- | --- |
| A | 胜 / 300 / 无 | 11.725→11.283 | 606/178→606/178 |
| B | 败 / 0 / 唐僧 | 6.675→7.150 | 101/0→104/0 |
| C | 胜 / 300 / 山雀 | 14.167→13.517 | 606/133→606/133 |
| 录屏同部署 | 胜 / 300 / 棍僧 | 26.408→24.158 | 606/316→606/286 |

录屏部署依次为唐僧(1,4)、棍僧(6,4)、猎户(1,3)、山雀(1,5)、药灵(2,4)、狐火(3,4)，不冒用A。真实1.258秒棍僧停在(7,4)、互锁E3且只等其第2段；1.408秒E3落到(7,3)，双方按实际射程起攻，此后两者驻留持续交战至棍僧7.000秒阵亡，没有原首轮错身/折返。围攻没有强制配对或退让；此修复不保证棍僧存活或每种部署零必要绕路，不是正式平衡。

完整三阵及录屏战果/攻击时刻/逐角色分配见`tests/board-trial-runtime/board-d006-comparisons.json`；全五近战目标/当前格/移动起止及序号/路线攻位/攻击的连续状态变更见`board-d006-melee-traces.json`。离散状态保持到下一事件，移动time/冷却在事件处采样；每1/120模拟步核唯一预约、原段提交、真实射程与等待，未遗漏未记录时段的离散变化。真实30FPS×1、120FPS×2公共step及暂停重复完整report/时刻相同。另有32组四敌类型/镜像/不同步速/反向更新顺序的双方活AI夹具，步速变更只属边界测试，不用作自然平衡证据。

旧录屏20.008秒诊断快照仍保留并明确不是旧终局；旧完整26.408秒结果由7aba204原控制器/原D-004近战在临时目录重新运行两帧率复现，仅重定向近战模块路径，其余共享数值/运行资源保持，结果也包含在trace JSON。旧三阵/原诊断证据不覆盖，新报告标`melee_rule=melee-handoff-d006`，不是完整JSON保持。隔离边界专项补有效旧攻位/失效重算、同tick完成又发段、活动取消/死亡/越界/解除互锁、距离/角色排除、冷却驻留、敌方原不可达选敌与无LEASH/长堵机制，不能替代上述自然AI。

历史D-003→D-004真实自动战斗（以下为旧交付，不是D-006当前结果）：

| 01站位 | 新结果 / 唐僧HP / 阵亡 | 旧→新模拟秒 | 旧→新伤害 / 治疗 |
| --- | --- | --- | --- |
| A集中支援 | 胜 / 300 / 无 | 12.533→11.725 | 606/202→606/178 |
| B暴露与脱节 | 败 / 0 / 唐僧 | 6.675→6.675 | 101/0→101/0 |
| C上下覆盖 | 胜 / 300 / 山雀 | 13.058→14.167 | 606/150→606/133 |

新完整输出、攻击时刻/首次接敌/逐角色伤害治疗在`tests/board-trial-runtime/board-d004-comparisons.json`；旧`board-trial-comparisons.json`不覆盖。配置版本仍board-v1-base，报告另标`melee_rule=monk-lock-d004`；既有HP/伤害/攻速/格位/射程不动，仅加批准的LONG_BLOCK_SECONDS=2。允许新策略改变攻击时刻/伤害分配，不能以表中胜败仍相同声称JSON相同或已经正式平衡。原三固定夹具不代替真人手感。

最小序列：`board-d004-melee-traces.json`记录目标ID/格与移动目的地、模拟时刻、阻塞计时；指定E2源格(7,3)→(7,2)预约短堵时，棍僧锁E1一直不变，(6,3)等待→只去(7,3)攻击E1，无(5,3)归锚绕路。另含近敌不抢、死亡/越界段边界、长堵2秒/1.9秒解堵、合法旧路径优先、攻击等待不计堵、未到锚点的归位段接新敌。完全僵局仍可暂停/重试，不瞬移或扩范围。

验证入口（所有图形专项须串行独占窗口/鼠标，保持正常生产逐帧，非人工OS验收）：

```sh
godot --headless --path godot-demo --script res://tests/board_trial_bear_facing_test.gd
godot --headless --path godot-demo --script res://tests/board_trial_enemy_profiles_test.gd
godot --headless --path godot-demo --script res://tests/board_trial_balance_20261009_test.gd
godot --headless --path godot-demo --script res://tests/board_trial_monk_sample_test.gd
godot --headless --path godot-demo --script res://tests/board_trial_pack_boot.gd
godot --headless --path godot-demo --script res://tests/board_trial_profile_pack_test.gd
godot --headless --path godot-demo --script res://tests/board_trial_test.gd
godot --headless --path godot-demo --script res://tests/board_trial_uniform_movement_test.gd
godot --headless --path godot-demo --script res://tests/board_trial_stepwise_test.gd
godot --headless --path godot-demo --script res://tests/board_trial_step_target_test.gd
godot --headless --path godot-demo --script res://tests/board_trial_stepwise_natural_test.gd
godot --headless --path godot-demo --script res://tests/board_trial_ai_test.gd
godot --headless --path godot-demo --script res://tests/board_trial_melee_handoff_boundaries_test.gd
godot --headless --path godot-demo --script res://tests/board_trial_enemy_pursuit_test.gd
godot --headless --path godot-demo --script res://tests/board_trial_melee_unified_test.gd
godot --headless --path godot-demo --script res://tests/board_trial_ranged_pursuit_test.gd
godot --headless --path godot-demo --script res://tests/board_trial_facing_test.gd
godot --path godot-demo --script res://tests/board_trial_selection_release_test.gd
godot --path godot-demo --script res://tests/board_trial_healer_input_test.gd
godot --path godot-demo --script res://tests/board_trial_modal_input_test.gd
godot --path godot-demo --script res://tests/board_trial_input_test.gd
```

本批前三个无窗口专项分别验证精确敌人数值/熊边界、三配置四阵的真实承伤账、棍僧动作与新旧显示战果。旧D001精确数值/12演员夹具已显式选`legacy`，不拿六怪断言误验默认加熊。输入专项已扩展四类/E7及新配置/动画控件，但本批尚未获得图形窗口许可，不能将脚本适配称输入验证通过。最后两个包脚本不继承`res://tests`，可用其宿主机绝对路径在`--main-pack /tmp/board-balance-20261009.pck`下执行；profile_pack脚本的`-- <自然报告绝对路径>`参数指向上方已保存的24局source JSON，包内测试/证据本身仍排除。示例（将两个宿主路径换成本机仓库绝对路径）：

```sh
godot --headless --path godot-demo --export-pack "Windows x86_64 Release" /tmp/board-balance-20261009.pck
python3 scripts/inspect_godot_pck.py /tmp/board-balance-20261009.pck --release-policy --usage noncommercial --output /tmp/board-balance-20261009-pack-files.txt
godot --headless --main-pack /tmp/board-balance-20261009.pck --script /absolute/repo/godot-demo/tests/board_trial_pack_boot.gd
godot --headless --main-pack /tmp/board-balance-20261009.pck --script /absolute/repo/godot-demo/tests/board_trial_profile_pack_test.gd -- /absolute/repo/godot-demo/tests/board-trial-runtime/board-balance-20261009-natural.json
```

D-20261008-002当前断言分流：`board_trial_melee_lock_test.gd`标明D-004历史，锚点/永久锁/2秒长堵/归锚前提不拿当前源码跑假绿；旧断言原样保留在历史测试，当前通用安全段/真实range/CD/暂停/重试由unified与handoff专项继续严格验证。ownership仅唐僧/药灵驻留，四英雄合法邻步/双端预约；AI原guard path改验真实空攻位而非LEASH，原封角/死亡/攻速断言保。实际左行代替自动归锚朝向夹具，脚点/无目标右向断言保。旧B改为胜的真实新战果已公开，窗口失败能力另用正常300HP唐僧单独合法部署、原12演员生产战斗验证，不调HP/伤害、不冻敌或删失败统计断言。首轮子测试复活敌人误用`battle_dead`导致4例脚本提前返回，虽exit0/尾行failures0并未当通过；修字段后完整78例及两真腾格重跑零失败，另加78完成数量断言，原错误日志保留。不新增媒体/Windows发布；独立验收交07。

历史D-20261008-001断言分流：三输出移动后，旧所有friendly远程驻留改为当时唐僧/药灵驻留、guard原LEASH、三输出合法邻步；该guard边界已被当前D-002替代。旧D-006/D-007自然脚本精确时序/角色不改等仅属旧源基线，当前以新六局和机制边界为准，不强保旧JSON。

D-005最小回归：新专项完整press/move/release验证按下成功后拖往第三格松开仍只首提交、A/B交换守恒且不选B、后续空地不移动、拖空格/友军/同格成功清选，非法右半/棋盘外/库存换位失败保A及原位，帮助/暂停/敌情/R保持。正常输入旧“成功后立即R/点7列”断言改为先检查清选、重新选A再继续边界与撤下，不删除原覆盖。图形普通专项可加`-- --no-capture`禁用截图产出；本次无媒体查看/生成、新素材或全套PCK重跑。完整三阵JSON与D-004逐字一致，锁敌/朝向重要专项及新入口120帧冒烟通过；待07本修订独立复验。

D-006定向隔离：D-005成功清选、三尺寸正常输入/帮助含暂停锁阵、药灵真实源帧向右/左右治疗/脚点释放、AI/朝向/D-004锁定与旧格子/自由/整局死亡核心通过；药灵图形专项也支持`-- --no-capture`，本轮未查看或生成图片/视频。初轮选中专项有两次系统指针稳定超时（保留日志/断言，不改生产指针），独占窗口完整重跑零失败，原因未完全确认。一次最终临时PCK`/tmp/board-d006-20261007.pck`261项策略通过，实际包A/录屏自然战果与源码相同，测试/Spine候选不入包；未Windows EXE/ZIP/真人OS验收，待07本提交独立动态复验。

D-007回归口径：新A没有敌人进入唐僧射程，旧“每阵唐僧都必须出伤害”前提不再成立。正伤害断言保留到唐僧/E5双方真实AI的range3独立夹具，继续验实际HP损失、原伤害6/间隔1.2及驻留，不改数值硬保A。B实际治疗20，窗口结果改验实际总伤害/治疗/阵亡，不写死旧治疗0。首次原数值断言失败和后续两次系统指针稳定超时日志保留；仅测试初始化请求窗口(80,80)后完整复跑，原指针断言/生产picking保留，不保证外部焦点原因已修或所有OS/DPI。D-005、三尺寸/帮助/暂停、药灵、guard/远程及旧自由/格子/死亡核心定向通过，未重跑无关8+8/媒体。一次最终`/tmp/board-d007-20261007.pck`261项策略通过，实际包五局完整report与源码相同；没有Windows EXE/ZIP，待07本提交独立分项验收。

QA-20261007-UI2-01定向修复：07在`caefd76`发现帮助打开时全局右键仍先取消底层选择，旧作者输入专项没有覆盖这条路径，不能以当时零失败称全面隔离。现在帮助可见时先把鼠标交给帮助GUI，不执行全局取消，并在未处理输入入口补防漏；自己的关闭按钮/Esc可用，关闭后原右键取消、数字键/R与暂停锁阵保持。新增模态专项覆盖960×540/1280×720/1440×810各部署和暂停六组，内外左/右/中键/滚轮/侧键/完整拖动、遮住的卡片/按钮、快捷键、关闭和恢复；选择/详情/部署/提示/拖动/时钟/阶段/暂停/倍速有完整不变断言。修复作者自测与原07复现均通过，独立关闭仍交07，不代改其报告。新源码定向包为`/tmp/board-ui-v2-modal-fix-20261007.pck`，257项与包内五入口/A阵通过；本次不改布局、素材、朝向或战斗，不替换下述四图。

基础四图`board-trial-20261007-*`与D-002三图`board-art-20261007-*`保留为历史，不能称新UI截图。最新实际1280×720四图：`tests/board-trial-runtime/board-ui-v2-20261007-{deploy,selected,battle,victory}.png`（媒体目录.gdignore，不入运行包），测试额外输出`/tmp/board-ui-v2-20261007-{paused,defeat}.png`。本轮六卡真实HP/头像及三类敌情/具体敌人、敌我R权限、帮助遮挡、实时目标编号/状态、结果六人统计/关闭重开、84格/左6列、960×540/1440×810四角和6/7列/框外对齐、点放交换拖放取消、暂停锁阵/自然A胜B败/重试均零失败。朝向专项检查最终绘图矩阵/source镜像、左右/竖向动作、左治疗/归位、空闲和重试恢复、真实缩放发射点及不动脚点；完整三阵JSON与dc56036沿用基础证据逐字一致。旧格子/自由核心定向回归通过。仍是程序Viewport注入，不是人工OS鼠标、Windows或任意DPI通过；05/07新一轮复核待执行。

D-004证据：`tests/board-trial-runtime/board-d004-20261007-{healer-source-compare,deploy-healer-right,heal-left,heal-right}.png`均实际720p视口。对照图是同源frame0/头像程序放大对照，非自然战斗；开场为真实满员A，左右治疗为明确唐僧100HP、其他AI隔离/隐藏、仅保留一敌不提前结算的夹具，不能当自然A战果。`board-d004-healer-samples.json`记录左右起手0/接触2/收势0及实际释放，根脚点(605,547)不动，释放分别(633.8,504.52)/(576.2,504.52)，无double source镜像。原三素材哈希未变。旧D-003四图与描述保留历史，不能据它们称药灵待机已正确或D-004已验收。

最终新源码包`/tmp/board-d004-20261007.pck`：261项策略通过，要求新近战和药灵局部表现模块，保留有效v2/九头像，审阅/测试/Spine/失败狼候选排除。实际包A阵11.725秒胜并启动五入口；普通UI/药灵真实输入、AI/生命周期/朝向、旧格子/自由核心自测零失败，新三阵帧率/暂停/倍速稳定。系统证书/日志/编辑器设置权限警告保留，无新增脚本/资源错误；未制作Windows EXE/ZIP，待05新药灵图与07本提交独立验收。

历史矩形版UI坐标接口：1920×1080逻辑，棋盘`ORIGIN=(220,190)`、`CELL=(110,102)`、Rect(220,190,1320,714)，720p按2/3映射，部署线x880/实际586.67。当前轻透视棋盘不使用这些矩形坐标，应调用`display_center/display_cell_at`；UI区域仍保留以下布局。顶栏Rect(32,20,1856,112)，左窄边x26—194；右敌情Rect(1572,176,314,274)、详情Rect(1572,467,314,437)，详情文本Rect(1590,613,278,231)、R按钮y851—889。六卡x220—1540/y958—1052/间10，主按钮Rect(1572,918,314,72)、重试y1003—1048。临时反馈y918在棋盘下方；完整帮助展开Rect(660,170,600,724)，结果Rect(555,278,820,550)，展开时覆盖区按交互需要拦截。普通常驻UI不侵入棋盘，边缘角色头/血条仍可高于首行脚点。当前投影精确变换见本页顶部轻透视说明及board_depth_projection.gd，不按台沿反推格心。

## 棍僧动画样板试接（2026-10-04，待05/07审核）

Mac双击`launch-monk-trial.command`，或在仓库根目录运行：

```sh
godot --path godot-demo res://scenes/monk_animation_trial.tscn
```

这是独立的无格子战场入口，初始3金币与原四段流程不变；只给护寺棍僧启用归档13帧候选。左侧“棍僧样板 · 切换旧版”按钮随时对照当前production/nine_sols_v1旧动画，不重新开局，不改变位置、指令、攻击序号/时钟、血量、人口、金币或阵亡。切回旧版不是旧造型motion包。新购买/合成保留者及拿起预览遵循当前选择，重开创建新局但保留本入口的表现选项；切到格子模式仍按原约定重新开局，返回普通无格子入口不默认启用样板。原入口与原资源不替换，山狼仍用现行版。

`presentation/motion_sample_track.gd`明确适配motion-sample-v1：待机0/1/0按各帧时长，移动2/3/4/5每拍0.125秒，相位不随寻路小步重置；攻击6/7/8/9/0共0.54秒，第8帧对齐既有0.235秒命中时钟，轨道不另发伤害；受击10/0，死亡11/12后淡出，不循环。启用样板关闭旧整图前冲/摇摆/弹跳，根节点仍由既有寻路驱动；只做镜像和原有命中闪色/短顿帧，不重构其他角色。正式伤害、攻速、射程、永久阵亡、营地经营不变。

候选有衣纹、脸型、握点/棍长透视差异，脚步承重与滑步质量待05真实游戏尺寸动态评审；程序时序通过不等于动画已验收。截图为正常逐帧720p窗口中的明确夹具，位于`tests/free-escort-runtime/monk-trial-20261004-{walk-left,contact-new,contact-old,death}.png`；接触新旧图在同一暂停时刻切换，不是拼接示意图。高HP被动敌人、1HP伤员及加速营地为测试边界，不是自然试玩战果。普通入口仍是本README以下的双模式试验。

动态证据：`tests/free-escort-runtime/monk-trial-20261004-runtime.webp`与同名JSON。1280×720原视口、180张真实引擎帧、12.067秒、名义15fps；步行中第73→74张间隔133毫秒，其余约67毫秒，按实测模拟时钟播放，未补帧。实际采样耗时50.889秒，**不是实时/OS录像**：使用[Godot固定帧率输出](https://docs.godotengine.org/en/stable/tutorials/animation/creating_movies.html)，原生产`_process`驱动寻路与战斗，每张强制实际视口绘制；不是离线摆姿势循环。只购一名棍僧，延迟无关波次、隐藏敌人、14HP靶和1HP伤员；非致命攻击源仅从英雄AI目标列表隔离，保留原敌人表现时钟/攻击事件，避免攻击优先规则遮住受击10帧。原攻速、伤害、射程、角色比例与根导航不改。覆盖左右至少两走路循环、停步/转向、6—9攻击、10受击、11/12退场；接触有原命中数字但没有怪物/队友挡住握点和脚。05此前四张静态图仅限定预检，无新明确必修；此短片仍待动态视觉复核，07仍须新提交独立运行验收。

重采样需独占测试鼠标，在仓库根目录先创建新的`/tmp/monk-runtime-review.*`目录，再运行：

```sh
godot --path godot-demo --write-movie /tmp/monk-runtime-review.NEW/engine.avi --fixed-fps 15 --script res://tests/monk_animation_trial_capture_test.gd -- --capture-dir=/tmp/monk-runtime-review.NEW
python3 scripts/assemble_monk_trial_capture.py /tmp/monk-runtime-review.NEW /tmp/monk-review.webp
```

第二条需要Pillow；审阅使用原视口PNG合成的WebP，临时AVI的窗口尺寸/帧数不作为证据。JSON保留逐帧位置、方向、姿势、HP、攻击序号和模拟/真实时钟。原PNG/失败试采样不入发布包。

## 无格子驻守试验（2026-10-03）

Mac双击`launch-free.command`，或执行：

```sh
godot --path godot-demo res://scenes/free_escort.tscn
```

两版左侧均有切换按钮，按钮明确标注“重新开局”；切换会新建场景，金币、队伍、暂停和AI指令不跨模式继承。没有替换默认入口，也没有新Windows发布包。

试验版采用05新增的自然土地/碎石/不规则石板底图，规则方格纹理也已去除，旧格子版仍用原底图。新图并非逐像素保几何，已核对运行岸线叠加，保守边界与少量岩沿仍有视觉差异；来源和核对限制见[自然地表采用说明](art/production/escort_map/natural_ground_v1/README.md)。

- 后备区指已购买英雄的8个席位，不是商店3个候选。8席后备在地图底部、场上状态栏上方横向常显，初始/营地/战斗都可见，B停用。空格或左下“招募商店”按钮只切商店，初始和开战收起商店，营地展开；商店位于后备上方，不覆盖后备、状态栏或R/F操作区。关商店不取消后备拿起/待互换，仍可从后备部署。整备时点击后备英雄拿起半透明预览，鼠标移动预览、原库存不动；第二次左键合法落地才上场。也可按住拖放，两种方式共用库存、整备阶段、人口、地形和范围校验。首次点击释放不部署，拖放释放只提交一次；合法放置成功后清除选中、拿起和待释放手势，后续点空地不会继续搬动刚放的英雄；非法放置保留预览。拿起后备英雄后右键即可取消（包括鼠标位于商店按钮上或正按住左键拖动时），英雄留在原后备席、不扣金币，随后松开左键不会误上场；首次整备和关间均适用。Esc、阶段切换、源英雄合成或移除也会安全取消。商店/后备面板空白、按钮和常驻底栏会拦截地图点击；后备起拖后只有在露出的地图或合法后备席释放才可提交，隐藏控件不再拦截。战中打开面板仅查看，不能购买、刷新、升级、部署或互换。
- 首次布阵及新增名额落位须在唐僧210像素内的可达陆地；落点保留实际坐标、不吸附旧石块中心。同一块旧石面可站多人，只要求脚点间距30像素。地图水面、峡谷、建筑及外岸仍不可走；边缘有角色半径余量，非法点击不会吸附成附近合法点。
- **R下场 / F原位互换 / Esc取消**：整备时选中场上英雄按R退回后备，后备满则拒绝并保留选择、英雄与金币。按F或点击右下“互换 [F]”，再点击另一名场上或后备英雄，一次性交换；进入互换不打开商店，按钮高亮并提示目标/Esc取消。场上两人交换既有坐标，位置集合不变；后备来者继承场上位置和编号，去者占用来者后备席，满后备也能换。编号跟位置、身份/星级/血量跟本人；更新两人驻守锚点并清旧命令，成功后清除选中和预览。不扣钱、不出售、不触发额外合成。Esc、数字切换、点击来源本人、来源死亡/合成/移除、阶段切换会取消待互换；重复完成无效。战斗中R/F不撤回、不互换，也不清除正在执行的移动令。
- **两栏外观（2026-10-04）**：后备与底栏使用墨褐底、细灰金边、米白文字；后备去除厚石台/大阴影，按现有造型的可见范围放大、统一脚底线，星级贴底、合成锁改为小图标，空席只留弱底线和加号。底栏仍固定十槽，编号左上、星级右上；现有角色图裁为较大的上身头像，配短名/实际状态、当前/最大HP和细血条。选中用金框与小三角，低血另加“!”及数字，阵亡显示灰头像/交叉标记/阵亡/0HP及“本关不可替补”；普通空位另显示可上场或未解锁。R/F按钮成组，作用或禁用原因固定两行；QWE仅空键帽和“技能未配置”。
- **大关内阵亡不可复活或替补（D-20261004-001）**：四段属于同一次大关，阵亡身份、原编号和占用名额独立记录，跨营地保留；不能通过R/F、出售、合成、购买同身份或移除角色对象释放阵亡名额。死亡当帧停止行动和治疗，取消该英雄尚未生效的攻击/治疗，包括已释放弹体；普通手动取消不改变活英雄已释放弹体的旧规则。顶部显示存活、阵亡占用、可用及总人口。真正升级所得新名额仍可部署，存活英雄仍可下场/原位互换。全员阵亡仍可出发，按原唐僧/护送规则胜败，不新增强制判负。仅完整重新开局或切模式的新局清空阵亡记录；不加入跨局损失/存档，旧格子与固定棋盘不启用此规则。
- **关间只换人，不重排已有位置**：营地记录本关结束坐标并显示空位圈。R撤回、出售或合成消耗场上英雄后，原位置及编号保留；点放/拖放后备英雄到空圈（24像素选取范围）会精确接替原坐标，不受首次部署210像素范围限制。场上英雄不能在营地靠点地、拖动、右键任意移动；F两名场上英雄交换已有位置是明确例外，不创建新位置；下一关开战后恢复正常指挥。初次开局仍可自由布阵。
- **3/4就是还能上一人**：新增人口或此前未用满的名额允许任意后备英雄自行选一个附近合法落点，包括刚互换下来的已有英雄，不要求额外购买或继承原空位。每个新位置首次落位后就锁定；新落点数量只由人口减去本营地已记录的位置数决定，R/出售/合成不会反复增加自由落点。新位置须避开已保留的空位，其他场上英雄不搬动。
- 英雄不再跟随唐僧。部署点或最近一次手动移动的完成点是固定驻守锚点；无敌原地驻守，只自动接近锚点附近的可达敌人。近战上前、远程进入射程停步；药灵原地治疗自身射程内最低血比的队友/唐僧，不追敌也不追伤员。唐僧走远需要玩家主动调队。
- 数字键1—9选对应上场英雄，第10位用0；英雄脚边显示编号。首次上场分配最低可用空号，移动不改号，死亡保留原号并阻止选择/替补；关间普通空位补员/F互换继承目标位置的编号，新增名额使用未占用且非阵亡的编号，其他人不跳号。空号清空选择，无选中时右键不下令。数字切换取消拿起/互换预览，不消耗库存。
- 底部英雄状态条始终可见，按稳定的1—9/0槽序显示头像、星级、状态和实时当前/最大血量；选中金框，阵亡灰化并保留编号，营地生还者回血/合成/出售/互换实时更新。可点底栏槽选择活英雄，F待互换时也可点存活目标槽（避免展开面板遮住目标）；空号不发令，阵亡位拒绝互换并显示原因。Q/W/E状态区域只显示“— / 未配置”，没有技能CD计时或新技能。底栏右侧并排“下场 [R]”“互换 [F]”，按钮和快捷键调用同一规则；无选中/战斗中均禁用并显示原因，后备满只禁R、不禁F。鼠标按钮不抢键盘焦点、不清掉原选择或穿透地图。操作说明与QWE未配置提示均保留。
- 数字键即使在商店展开时也只选上场英雄，不再购买；Q/W/E是空技能预留，不触发移动、攻击、购买或升人口。购买、升人口和2金币刷新保留鼠标按钮；无格子R不再刷新。忽略长按重复和文本输入框焦点内的快捷键。旧格子模式的1—3购买/E升人口/R刷新不变。
- 战中通过鼠标或数字选人后，右键地面处理本次移动令并立即取消选择；有效命令继续执行，不因取消选中而撤销或被AI抢走；非法/不可达点给拒绝提示并取消选择，已有命令保留。想再下令或用Esc撤销移动须重新选中英雄。无选中时右键无效，后备拿起时右键只取消拿起。点地或拖动仍可下移动令，立即接管并取消未出手动作；已射出的弹体照常飞行。途中自动接敌/治疗不会抢令，新有效令覆盖旧令，到达后更新驻守点。无效或当前无路点击拒绝并保留原任务。连续3秒无进展或Esc取消时，在当前位置合法落脚并设置驻守点、显示反馈；若正穿过队友，则沿路返回最近合法脚点（必要时找附近空位），不瞬移、不在重叠处停步；无空位会等待，可再次手动下令。
- 自由模式战中点其他英雄只切换选择；重复点击当前已选英雄覆盖的合法地面（含脚点上方），会在松开鼠标时下移动令，不再被自身点击框吞掉。按住拖动则以释放位置为目标，按下时不抢先发令；无效落点仍保留原任务。旧格子版点击约定不变。
- 脚边和侧栏标明驻守（绿）、接战（红）、归位（蓝）、手动（金）；选中时绿色小圈显示驻守点。P暂停期间可下令，继续后执行；支持1×/2×。没有新增攻击命令、复杂编队或完整技能。
- 暂停时顶部保留“已暂停”，并同时显示本次命令成功或拒绝原因。反馈按真实时间显示3秒，不随战斗暂停冻结或被2倍速加快；新反馈立即替换旧反馈。切换暂停/继续会清理旧提示，但不清除移动令；营地以结算提示替换，重开清空。
- 警戒/追击范围均相对固定锚点，不相对唐僧。目标死亡、失效、越界、追击超时或持续不可达便返回锚点；返回完成前不会接下一只怪。换目标不改锚点、不重置整轮追击时钟；只有完成归位才清零。该目标3秒重试间隔，归位后0.4秒重新警戒。归位点被占/无路则等待和重寻路，不换锚点追敌；可用有效手动令接管。
- 友军移动可互相穿行，停步保持间距；唐僧在友军之间拥有通行优先，不被友军永久堵死，不推人、不改手动令、不瞬移。短暂视觉重叠是此试验的软碰撞规则，不代表敌人可穿人。敌人身体和地形仍拦截移动；敌人实际堵路时唐僧等待护卫清敌。
- 营地保留生还队员本关结束坐标，并把驻守点更新到该处，下一关不会自动退回更早锚点或跟随唐僧。阵亡不复归，死亡坐标及编号跨后续营地保留为交叉标记，不是可补员空圈；不迁移生还者，仅生还者满血、唐僧血量继承。合成排除阵亡者，其余沿用原保留者/升星规则，不自动把后备保留者搬上场。结算恰逢生还友军穿行产生的短暂重叠只继承原坐标，不擅自挪人；原位换人也不增加新坐标，下一关可手动疏散，新落点仍必须满足间距并避开阵亡保留点。每个新营地重新记录生还者实际位置并继承全部阵亡位，重开清空所有锁位与阵亡。死亡、营地、结果、重开清理自动目标和手动令，营地商店展开供整备，下一段开战仅收起商店，后备始终可见。终点仍需清空所有活敌与待生成队列，失败不结算当段金币。

试验参数集中在`data/free_escort_rules.gd`，不改伤害/攻速/金币或正式确认版：

| 参数 | 当前试验值 |
| --- | --- |
| 距离换算 | 原1格射程→64屏幕像素；近战64，远程/治疗192，狐火溅射64 |
| 英雄/敌人移速 | 64÷原移动间隔，像素/模拟秒 |
| 唐僧 | 30像素/模拟秒，沿原A→B路线连续行进，无逐格停顿 |
| 锚点警戒 / 最大追击半径 | 250 / 330像素；整轮追击最长9秒，换敌不重置 |
| 脚点半径 / 敌我阻隔 / 停步间距 | 10 / 26 / 30像素 |
| 寻路 / 警戒扫描 | 0.45 / 0.4模拟秒；手动新令立即规划 |
| 归位容差 / 无进展超时 / 重试间隔 | 0.1像素 / 3模拟秒 / 3模拟秒；不再使用唐僧125像素归队圈 |

导航仅复用旧地图的**陆地外轮廓**，不复用单位占格。内部24像素辅助图用于找绕行路径，随后用岸线扫掠碰撞检查和直线平滑，保留精确自由终点；角色沿路线连续移动，不逐点跳步。碰撞是脚点圆而非整张人物轮廓。远程攻击需要地形视线，首版不做弹道高度或投射物撞墙。

2026-10-02历史自测（非07独立验收；死亡复归是当时旧规则）：新增R/F、关间锁位、后备满员互换、3/4自由补员、合成出售/死亡复归与库存一致性回归。固定初始三人不经营扩编，合法手动调度策略在60FPS×1与120FPS×2均101.733模拟秒通关、唐僧271.2/300、累计20金；不调队对照38.233秒第二段失守。另一轮自然四段流程在三个实际营地执行R原位补回、购买并F互换、升4人口并补员、三合一，89.592模拟秒通关、唐僧284.4/300、累计20金、消费7金后余13金。商店身份和手动策略是测试夹具，不代表随机经营通关率、真人手感或新平衡定案；没有调整伤害/生命/价格。

2026-10-04阵亡规则自测：上述两种四段通关策略与无调队失败结果不变，未调平衡。新增真实敌人攻击死亡、三次营地/移除角色后阵亡账本保留、关末同帧死亡、待生效治疗/弹体取消、经营绕过拒绝、满后备、新人口及整局重开测试；零存活可继续第二段，最终由唐僧血量归零结算失败。正常逐帧窗口检查死亡提示、鼠标R/F及被封锁目标、真实升级、全员阵亡出发。当前截图`tests/free-escort-runtime/run-casualties-20261004-{battle,camp-full,zero-survivors}.png`；金币/库存/伤害边界是明确夹具，非真人战果或07独立验收。

## 格子版试玩流程与操作

1. 初始3金币、3人口。空格或左下按钮展开招募商店，初次展示棍僧、弓箭猎户、药灵三个不同一费英雄，便于体验前排/远程/治疗。刷新池仍包含全部五名英雄。
2. 点击卡片或按1—3购买；4/5无购买功能。买过的槽位留空，直到刷新或营地补货。R/刷新按钮每次花2金币，第一次也收费；不足2金币不扣钱、不换卡。没有免费刷新券或次数。初次上架及每个营地自动补满3槽不额外扣费。
3. 拖动队员，或先点击队员再点绿色陆地部署。整备部署范围为唐僧周围3格；替补席8格。三名同身份同星且未锁定的英雄自动合成，可出售、设置合成锁；E/按钮升级人口（升4人口4金，之后6/8/10/12/14/16金）。
4. 点击“出发”。战中左键选人后点地、拖动，或右键下令。英雄仅按指令移动，到位驻守、射程内自动攻击/治疗，不自动跟随或全图追敌。
5. 英雄途中可以穿队友，不推动队友；终点必须空闲且不能被其他指令预订。敌人、唐僧及不可走地形仍阻挡。穿行会预留上一合法站位及下一合法落点；途中按Esc取消后，先连续走到下一安全落点再停，不瞬移、不停在队友身上。可重新下令，当前穿行段结束后执行新路线。
6. P暂停/继续；暂停冻结移动、动作、投射物、伤害与波次，可继续下令。空格只展开商店，不暂停战斗；战斗中经营按钮不可用。商店关闭时数字购买/R不生效。
7. 唐僧慢速沿金线前进，没有手动暂驻；邻近敌人不会单独让其停步。**下一格被实际占用时仍等待**，需调走队员或消灭挡路敌人；不穿人、不自动推人。此为本批保留的碰撞边界，长期规则可另评估。
8. 到营地且清敌后进入不限时整备，战利品到账，英雄满血复归、唐僧血量继承。英雄保留行进后站位，阵亡队员复归附近空格。手动出发下一段。最终唐僧存活到B，且所有已生成敌人、待生成队列清空才胜利；入口被占会等空，不丢怪。

金币仍逐波按唐僧血比保留80%/90%/100%奖励并向上取整，满血四波3/4/6/7金；最终不重复发钱。失败不发当前波收益，重开清空阵容/路线/金币并回到3金。

## 本批美术与试验参数

- 各对象采用最新版：五英雄、熊山君、唐僧、狼/鼠/猪，商店肖像与战场同皮肤；具体来源、逐帧提取和未用清单见 [运行素材交接](art/production/NINE_SOLS_RUNTIME.md)。
- 药灵/山雀/熊采用新版五关键姿势，其他为新版静态造型加程序过渡。没有混回旧动作皮肤，也不称完整动画。
- 猎户远程弓箭、灰鼠投石索石块：起手后发射，飞行抵达才扣血。射程暂取3格，其他基础伤害/攻速沿用已有值；是试玩参数，不是正式数值确认。猎犬/合围/鹰哨仍保留设计、尚未实现。
- 弓箭与投石索尚无08的新发射声音，本批发射静音，不复用挥刀声；命中材质/唐僧警示仍有效。原17条采用素材保留，狐火仍采用DWOBoyle改编A版。发行必须携带 [CREDITS.md](CREDITS.md)，没有新增BGM或配音。
- 扩容清洁底图按实际石缝标定134个可走格（不是美术122格提案），四段/三营地/25次路线移动；边缘碎石和装饰不一定可站。点击与显示共用坐标；浅色描边为准确可走边界，图中弯曲石缝与矩形标定有少量像素差异。
- 背景已去除烘焙金线/字标/红箭头；路线/营地/入口由程序唯一绘制。地图清理衍生图存在局部重绘，按清洁版重新核对，不宣称与原图像素一致。
- 唐僧步进等待1.6秒、移动0.75秒，敌人2秒预警；四波敌人组合及生命系数1/1.15/1.35/1.60、攻击系数1/1.05/1.10/1.20沿用。以上均为原型取值。

## 验证入口

```sh
godot --headless --path godot-demo --script res://tests/free_escort_test.gd
godot --headless --path godot-demo --script res://tests/free_guard_test.gd
godot --headless --path godot-demo --script res://tests/monk_animation_trial_test.gd
godot --path godot-demo --script res://tests/monk_animation_trial_input_test.gd
godot --headless --path godot-demo --script res://tests/run_casualties_test.gd
godot --path godot-demo --script res://tests/run_casualties_input_test.gd
godot --headless --path godot-demo --script res://tests/operation_roster_test.gd
godot --path godot-demo --script res://tests/operation_ui_input_test.gd
godot --path godot-demo --script res://tests/bench_actions_input_test.gd
godot --headless --path godot-demo --script res://tests/camp_roster_test.gd
godot --path godot-demo --script res://tests/camp_roster_input_test.gd
godot --path godot-demo --script res://tests/free_roster_input_test.gd
godot --path godot-demo --script res://tests/free_escort_graphical_test.gd
godot --path godot-demo --script res://tests/free_escort_selection_input_test.gd
godot --path godot-demo --script res://tests/free_escort_feedback_input_test.gd
godot --headless --path godot-demo --script res://tests/escort_route_test.gd
godot --headless --path godot-demo --script res://tests/nine_sols_assets_test.gd
godot --headless --path godot-demo --script res://tests/wave_preparation_test.gd
godot --headless --path godot-demo --script res://tests/recruit_ui_test.gd
godot --headless --path godot-demo --script res://tests/demo_integration_test.gd
godot --headless --path godot-demo --script res://tests/audio_integration_test.gd
godot --path godot-demo --script res://tests/route_graphical_input_test.gd
```

最后一项必须有图形窗口，通过真实Control输入分发检查商店/快捷键/部署/移动/暂停，截图写到`/tmp/nine-sols-{shop,route,cast}.png`。仅这是程序驱动的图形输入验证，不替代07真人操作验收。

无格子图形测试也必须有窗口，覆盖实际Control输入分发、精确目标/无效点击、暂停、取消和双向切模式，截图写到`/tmp/free-escort-{preparation,manual,combat}.png`。运行时不要同时手动操作该测试窗口。

`free_escort_selection_input_test.gd`是QA-20261001-01永久回归：完整Viewport指针移动/按下/释放，覆盖暂停及运行时当前英雄上方80像素落点、其他英雄选择、两种拖动起点、右键覆盖、无效点保留、按住时取消与手动不被AI抢令，并检查旧格子重复选中行为不变。不直接调用移动命令函数代替点击。

`free_escort_feedback_input_test.gd`是QA-20261001-02永久回归：检查真实窗口中可见Label的暂停标识/拒绝原因/成功文案，等待真实时间验证到期与2倍速隔离，以及新反馈替换、任务保持、暂停冻结、继续/营地/重开清理、运行态及旧模式。截图输出到`/tmp/free-feedback-paused-{rejection,accepted}.png`，不是只断言内部`command_note`。

`free_guard_test.gd`覆盖固定驻守锚点及串联敌人、超时/死亡/不可达返回、被占锚点等待、手动更新/取消与阵亡跨营地保留。`free_roster_input_test.gd`保持生产`_process`正常逐帧运行，以完整Viewport按下/释放/移动验证预览、点放、拖放、UI不穿透、取消/合成/出售、商店独立开关/后备常显、1—9/0稳定编号、QWE空槽、文本焦点/长按、暂停右键和战中禁部署；明确覆盖左键选中后立即右键取消，再次选中正常、库存/金币/原位不变。十人口部分是专用键位夹具，不是十人口战斗压力测试。截图在`/tmp/free-roster-{deployed,paused-order}.png`。这些均为程序驱动窗口，不是操作系统鼠标或真人试玩。

`camp_roster_test.gd`覆盖位置/人员独立、撤回/互换守恒、远离唐僧的原位补员、新增名额只创建一次、合成出售留位、阵亡保留及生还者短暂重叠、下一关移动及自然四段营地经营闭环。`camp_roster_input_test.gd`使用正常逐帧窗口验证R不刷新、F/Esc/空格/数字切换、点放/拖拽锁位、右键取消拿起、鼠标刷新/升人口、3/4补员、满后备、文本焦点/重复键、开战清理与战斗R/F禁用；库存/营地转换部分是边界夹具。截图输出`/tmp/camp-exchange-{select,complete}.png`。窗口测试逐个运行、不要同时手动操作测试窗口。

护送专项覆盖通行连通、点击对应、同/对向穿友军、目标竞争、暂停/取消/死亡释放、敌人阻挡、唐僧实占阻挡、清威胁胜败、重开及营地经营。固定合法指令策略首营地买两棍僧合二星，次营地升人口并买狐火；约91.6模拟秒通关，唐僧300/300、累计20金。30/60FPS和120FPS×2最终血量/收益一致，输入采样使时间相差约0.03秒。控制商店库存只验证经营/战斗闭环，不代表随机商店的通关率或难度平衡。

旧固定棋盘冒烟、导航、表现、完整四波及综合回归仍保留；其测试已更新三槽收费规则，不能用旧五槽/免费券断言替代新版验收。独立美术旧试玩此前猎户断言问题未在本批修复。

## 资源与扩展

- `scripts/data/escort_map.gd`：清洁图标定、可走地块、路线/营地/入口。
- `scripts/free_escort.gd`：独立连续坐标、固定驻守/手动接管与后备预览控制器，复用经营与攻击结算，不改旧格子AI。共享game仅给后备控件加分组，shop_card新增默认开启的数字角标选项；隐藏和快捷键替换仅由无格子模式启用。
- `scripts/data/camp_positions.gd`：每个营地的位置记录与新增名额判断，独立于英雄引用/库存，供R/F、点放/拖放及合成出售统一使用；不修改人口/金币算法。
- `scripts/data/run_casualties.gd`：整局阵亡身份、稳定编号及坐标快照账本，不依赖角色节点存活；自由模式才启用，共享角色/攻击链默认保留旧模式生命周期。
- `scripts/combat/continuous_space.gd`：可走地形并集、精确岸线扫掠、隐藏导航图与路径平滑；`scripts/data/free_escort_rules.gd`：统一距离和试验参数。
- `scripts/combat/friendly_transit.gd`：友军穿行、唯一落点与取消安全段；敌人与唐僧仍复用原占位寻路。
- `scripts/escort_route.gd`：实时指令和护送流程；继承`game.gd`共用经营/攻击链。
- `scripts/data/`、`presentation/`、`combat/`分别维护参数、素材表现、攻击结算。新运行包独立于原资产，原图和旧包均保留。

导出清单已加入新运行包与地图，并可用`--export-pack`检查资源启动。**本批未重打或发布Windows ZIP，也未进行Windows实机验收**；旧0.1.0-playtest.1包不代表这批玩法。发布流程仍见 [Windows试玩说明](../docs/release/WINDOWS_PLAYTEST.md)。

`operation_roster_test.gd`验证首次/关间场上交换的坐标、编号、血量/星级守恒，满后备交换、重复提交、死亡/失效/合成/阶段清理。`operation_ui_input_test.gd`保持生产逐帧运行，覆盖放置后释放控制、右键有效/无效均取消选择但保留命令、正常2倍速到达与AI不抢令、F场上/底栏目标、商店/UI吞事件与隐藏恢复、战中只读、实时血量/阵亡保留/生还者回血/合成刷新、焦点/重复键/重开；营地、金币及死亡部分使用明确夹具。截图为`/tmp/operation-ui-{preparing,battle,camp,ten-slots}.png`（十槽图由后备专项生成），不替代真人或07独立验收。

`bench_actions_input_test.gd`为2026-10-03常显后备与R/F按钮专项：正常生产逐帧、完整Viewport输入，验证初始/营地/战斗8席常显、空格只切商店且关店后仍可点放/拖放/右键取消、F不强开商店、鼠标/键盘R/F同效、按钮长按/重复键/焦点、满后备仅禁R、F高亮/Esc取消、战中只读及不穿透。实际切换1280×720、1600×1000、1920×1080窗口设置，检查各区矩形不重叠、八席完整、缩放后按钮点击/空格可用；截图`/tmp/bench-actions-{full,swap,1280x720,1600x1000,1920x1080}.png`。按项目现有等比视口显示，非16:9窗口可留边；这仍是程序驱动的Viewport测试，不替代OS鼠标、所有屏幕/高DPI或真人手感验收。

2026-10-04该专项追加五种英雄的混合满后备夹具，验证可见脚底对齐、八席逐个选中/右键取消与库存守恒。窗口输入助手同步系统指针，等待macOS异步鼠标移动完成，再注入完整Viewport事件；修复了系统鼠标位置覆盖测试位置导致的购买失败，原购买断言保留，并在前置失败时安全退出以防数组越界。运行图形测试期间不要手动移动鼠标。最新UI证据为`tests/free-escort-runtime/ui-polish-20261004-{1280x720,full-selected,swap,battle}.png`，历史`bench-actions-*.png`保留原批次含义。新版通过上述三个窗口设置的布局与点击检查，非16:9留边；没有替代05视觉复核或07独立验收。
