# D-20261101-002 C3单向作者实测

2026-11-02，06程序开发。00以c81199d后正式放行共享入库与作者实测；从此前核过112文件的隔离候选接续。此前“未执行”阶段归档在provenance/preparation-20261102/；本文件只报告本次实际执行，不冒称07独立或C3美术/真人验收。

## 资源与保护

项目运行资源自足于`c03-attack-showcase/`，默认停在无声Ready，由用户点击播放，单向/单次/末态/重播。原98PNG/映射manifest/选定WAV及棋盘101件与来源a36cd562和已确认棋盘逐字节一致。来源和每件散列以provenance/resource-list.json为准，原manifest不改写；T=260250/90000、末index97源duration0、960²/475,760/.21/720,441保持。0.21和0.405仍为试接值。无镜像/自动循环/主战斗、新媒体或声音处理，不改熊展示和冻结05候选。

| 证据 | 实际结果 |
| --- | --- |
| `assets-source.json` | 1209项／0失败；全部101运行资源固定pin、98行PTS/duration/WAV/PCM/配置，加仓库候选和棋盘字节比较。 |
| `assets-cold.json` | 1108项／0失败；不含候选，全部固定pin/运行资源仍核，少101项仅为仓库跨目录比较。 |
| `test-source-first.json`、logs/test-source-first.log | 首次解析失败，1项／1失败；不是通过。 |
| `test-source-final.json`、`test-cold.json` | 各1032项／0失败，全98时刻/实际纹理、T前96/T后97、零末样本、原PCM、固定变换、音起点/迟帧相位/恰尾/Ended、重播与审帧禁声。 |
| `cold-start.json` | 独立副本首测不含候选，首次测试和图形前均无.godot/.import/.uid；生产脚本与源码字节一致。 |
| `render/capture.json` | 专用1440×810 macOS/Apple M1 OpenGL4.1 Metal Compatibility真实窗口，9组／18PNG，success=true、errors=[]。 |
| `realtime-first.json`、logs/realtime-first.log | 首正常图形探针4段/26项中2项观测失败，保留。 |
| `realtime-final.json`、logs/realtime-final.log | 修正观测后4段/33项、0错误，正常两次达T、声音活跃时重播及真正树退出。 |
| `baseline.json`、`scope-check.json`、`summary.json` | 起始版本、受保护范围、实际执行/未验及Git交接摘要。 |

引擎4.7.2。headless保留应用数据目录写权限/系统证书错误及冷副本退出5个ObjectDB实例告警；修正后的边界套未出现脚本/资源错误。实际图形采样和最终探针正常退出0；Dummy+总线静音，没有OS输入、用户原Godot/Spine操作、设备播放或录音。

## 两次首失及修复依据

首个生产解析错误为动态Array循环index比较结果无法推断`is_terminal`类型，补显式bool后通过；只修类型声明，来源/时序和保护断言未放宽。测试的脚本can_instantiate门禁实际捕获错误并输出失败JSON，未把退出码或旧JSON当通过。

首次图形探针将外部保留的旧WAV原生对象`is_playing()`当作是否仍进入混音的依据，重播/树退出两处失败。4.7.2源码显示：播放器stop把AudioServer节点标为淡出删除，混音后移除server引用；保留的WAV对象active字段可仍为true。[播放器停止](https://github.com/godotengine/godot/blob/4.7.2-stable/scene/audio/audio_stream_player_internal.cpp#L256-L271)、[Server淡出删除](https://github.com/godotengine/godot/blob/4.7.2-stable/servers/audio/audio_server.cpp#L367-L503)、[原生WAV状态](https://github.com/godotengine/godot/blob/4.7.2-stable/scene/resources/audio_stream_wav.cpp#L36-L71)。

只修探针观测，生产stop路径不改，也不调用旧引用stop/mix/seek来制造通过：保留重播即时主播放器停止/事件清零、树/唯一播放器真实释放保护；先跨3次实际mix时钟回绕让淡出删除完成，再跨3次回绕严格要求旧游标完全不变。两处旧游标均冻结在0.017845805秒，观察墙钟约0.516749/0.585114秒，早于旧1秒文件剩余自然结束时间；不以自然播完冒充停止。保留native.is_playing=true作为诊断。回绕观察期间不持AudioServer锁，原过程仍正常推进并记录帧/时间。[回绕计时API](https://docs.godotengine.org/en/4.7/classes/class_audioserver.html#class-audioserver-method-get-time-since-last-mix)。

原起播精度另由headless套短AudioServer锁内、同WAV独立native参考核恰0、跨微小步及0.2秒迟帧相位，三组差0，保持原2采样容差。原生游标含预填，不拿它作设备听感同步。

## 实际画面与未验

实采Ready首帧0、0基29/30/31/32/33/34/96的Inspection、经play/_process(T)进入真正Ended的97；不是把审帧冒充正常播放。每组保存完整Viewport及同一Image.get_region原像素裁片，覆盖完整变换画布和12像素边缘，记录state/time/源PTS/index/manifest和PNG散列/脚参考/世界脚点/倍率。没有离线叠底。

作者已看Ready全景、30/31/32/34局部和Ended全景：中文播放/重播/结束提示可见，单角色尺寸和固定格心参考一致，飞羽仍随原帧出现，没有运行额外裁切或删除烘焙飞羽。31→32飞羽分离、足/尾附近灰软残留可见，贴地和灰晕过渡留给C3美术实际复核，不据字节一致宣布画面合格或改图。97作为明确静态末态，没有延长源时间。

正常探针两次达到T/97，每次音事件单次处理；活跃声音时重播清旧状态，实际退出不再混旧声音。按钮信号由程序触发，非OS点击。最终两次完整播放主观测段分别看到84/68个不同索引；第二次重播前段另记录在停止观测trace中，不能把该计数当源98条丢失，也不保证每次屏幕呈现全部98时刻。静帧、源码验证和自动播放都不代真人连续观感。

07独立、C3美术31→32/灰残留/足点/飞羽/首尾、真人设备听感和其他平台仍未验。保留原工具QA fail及源混合残留说明，不因此重新抠像/换源或加工声音；单向必要技术/视觉通过后再镜像。

## 复现与交接

命令见项目README。无缓存作者副本在本机`/private/tmp/c03-single-author-20261102.EeuOVP/c03-attack-showcase`，只是本次证据环境，正式入口不依赖它；复制时排除validation/.godot/.import/.uid/__pycache__，不带仓库候选。该副本使用相同生产脚本及最终采样脚本，所有证据入本目录保存。

本批160个明确文件已本地提交`6349598`。唯一正常push退出1（sideband连接中断）；随后ls-remote退出0核Gitee master仍`7097d075b91e1404c773c38928c26bb6aa4beebe`，未收到本批。不能把末尾“Everything up-to-date”当成功，见[git-delivery.json](git-delivery.json)及logs/push.log。仅将真实交付结果另作本地文档收尾提交，不第二次推送；尚未跨机器同步。

全部本轮CLI/专用GUI已退出并释放；收尾提交后tracked/索引及Local-Git窗口释放，原无关未跟踪试稿/缓存保留。待00核收串行07和C3美术，automation-3保持暂停。
