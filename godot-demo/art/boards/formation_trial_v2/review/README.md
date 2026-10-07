# v2制作与离线检查

2026-10-07。本目录有`.gdignore`，不导入运行资源。

## 来源与次数

1. 内置imagegen：以`../../../reviews/formation-ui-v2/ui-concept.png`作气氛参考，用[PROMPT.txt](PROMPT.txt)生成首张干净图。工具原件`exec-9c4e7bb4-dcaf-4762-8e51-03a4af7c2302.png`保存为[first-pass-not-adopted.png](first-pass-not-adopted.png)。台沿进入末排、地面边框仍带透视，**未采用**。
2. 以内置imagegen编辑首稿，完整指令见[REPAIR_PROMPT.txt](REPAIR_PROMPT.txt)。原件`exec-5f9fece1-154e-4049-9437-7af3bdc62655.png`原样保存为上级`board-courtyard.png`。没有第三次调用，无付费API替代。
3. 修正稿铺满1920×1080时仍缺下边缘留白；离线叠层后采用上级[integration.json](../integration.json)中的背景Rect(0,-12,1920,1128)显示映射，精确84格保持不变。只校准显示矩形，不修改源图像素。

原件/概念来源SHA-256见元数据；首稿仅供复现编辑输入，严禁接成运行底图。最终图是环境图，不带角色或UI；四盏外侧灯与低对比石纹是允许保留的生成差异。

## 可复现离线检查

从任意目录用带Pillow的Python执行本目录脚本：

```
python3 build_overlay_preview.py
python3 build_overlay_preview.py --sprites --output readability-overlay-720p.png
```

第一条默认输出脚本同目录`geometry-overlay-720p.png`；第二条的显式输出路径相对执行目录（建议先进入本目录）。脚本只合成审阅叠层：读取元数据、原背景、已有角色待机PNG和manifest，核验哈希/方向，绘制84格及UI区域；不重绘环境、不运行游戏、不修改人物或游戏文件。可用`--height 1080 --top 0 --output <临时路径>`对照未校准的铺满方式。

- [geometry-overlay-720p.png](geometry-overlay-720p.png)：原色地面+黄色棋盘外框+青色留白检查框；UI框仅示占位，非实际最终界面。
- [readability-overlay-720p.png](readability-overlay-720p.png)：同场十二个静态实例，按manifest让友军朝右、敌军朝左；未加真实战斗HP/状态，不伪装实机。

视觉结论：校准后可用格及外围留白避开台沿/灯/饰角；手绘青灰场地与现有角色可分离。右侧覆盖区必须使用深色高不透明度面板。几何叠层通过不代表完整UI排版、真人动态、游戏输入、动画、PCK或独立07通过。下一步按上级README交06接入，本批停止生成。
