# 狐火混元模型 · Blender实际导入复核 v1

日期：2026-10-12。负责人提供已下载GLB，05保留下载原件并原样复制为[source.glb](source.glb)。复制前后SHA-256为0bef120b2d008b67d57df7bbe5317fec8da1e1a07c860533eb9eb838daf0a425，34,919,844字节（约33.3MiB）。本目录.gdignore隔离，不进入当前游戏资源。

## 结论

建议保留这版作为静态候选，不需立即重新生成。白狐、大耳、额纹、赤围巾、暗袍和单尾身份基本保持；真实侧背视图有体积，尾巴确实从臀部后中线向后伸出。尾根与后腰衣摆紧贴，静态观察不能排除局部粘连/穿插。

此文件没有可用骨架、蒙皮权重或动画：0 skins、无节点skin/骨骼层级引用、顶点无JOINTS/WEIGHTS、0 animations，Blender实际导入也为0 Armature/0 Action。这是新的混元静态网格，不能继承Tripo网页那次人形绑定；下一阶段若要动起来，需要完整人形＋尾巴绑定，而不是只补尾骨。本次没有执行该制作或授权范围扩展。

## 实际结构

- 1 mesh / 1 primitive / 1 node / 1 material；40,292导出顶点、50,789三角面。所有索引顶点使用，无退化三角面（独立二进制审计）；Blender读入面数一致。
- 3张内嵌4096² RGB PNG，分别为法线、基础颜色、金属/粗糙度；没有外链图片/缓冲。Blender三个贴图数据块已读入打包，UVMap存在。
- glTF节点绕X轴+90°；Blender导入后直立，原始约1.041单位高。仅复核场景临时归一至2单位，不写回原件。
- 材质双面并有KHR_materials_specular、specularColorFactor=[2,2,2]。此处仅记事实，未据此判定规范违规或擅自改材质。
- 临时BMesh副本以约1.05e-6容差合并重合点，排除UV/法线拆点后得到25,339顶点、2连通片。小片164顶点/324面，位于身体中线偏后、较低位置；19条边界/非流形边在中线低处。精确位置见[blender-report.json](blender-report.json)。不能把原始25,815条UV拆点边界都当作破洞，也不能凭小连通片数直接删部件；尾部/腿间局部需再确认，未做自交检测或变形测试。

33MiB与三张4K贴图是存储/贴图规格，不等于实际显存或帧率测量；当前50k网格应保为基准，后续再制作低面/较小贴图的游戏用副本。暂不代替Godot同屏/动画/性能验收。

## 真实Blender渲染

全部是原GLB导入后渲染的静态图，不是再次AI生图，也不是已经生成动画或游戏截图。原材质保留，另设灰色地面/灯光；Cycles CPU 24采样，Standard视图变换，800²。当前白毛有高光裁切，不能据此认为原贴图细节永久丢失。

- [正面](view_neg_y.png)：相机世界-Y。
- [背面](view_pos_y.png)：相机世界+Y。
- [左侧](view_pos_x.png)：相机世界+X，鼻尖朝画面左。
- [右侧](view_neg_x.png)：相机世界-X，鼻尖朝画面右。
- [固定斜俯视效果](game_view.png)：独立复核场景，不是已接入棋盘。

主代理看四面及斜俯视；独立只读复核只看背/侧/斜俯视三图，限定静态候选可保留，无明显重复肢体/第二尾。几何边界、小部件、衣袖/衣摆/尾巴权重和动作仍待检。未检查真人实时旋转、Godot图形效果或性能。

## 重建和报告

[inspect_blender.py](inspect_blender.py)仅导入/诊断/渲染，不绑定或导出模型。使用已安装Blender，在本目录运行：

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --disable-autoexec --python-exit-code 1 --python inspect_blender.py -- --views cardinal
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --disable-autoexec --python-exit-code 1 --python inspect_blender.py -- --views game --front-y -1
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --disable-autoexec --python-exit-code 1 --python inspect_blender.py -- --views audit
```

后续审计写报告、渲染会更新本复核文件，原source.glb保持不变。本次正常本机权限下Blender5.2.2后台三次执行成功；use_nodes只报未来版本弃用警告，不是导入失败。未重试已知受限Metal启动、不操纵用户已有Blender窗口或进程、不安装插件/付费API。

- [glb-report.json](glb-report.json)：原始glTF2结构与独立审计交叉核对。
- [blender-report.json](blender-report.json)：实际导入、临时网格诊断与贴图读取。
- [render-cardinal.json](render-cardinal.json)、[render-game.json](render-game.json)：相机/渲染参数。
- [provenance.json](provenance.json)：原件、复核边界及下一步提案。生成平台由负责人提供，GLB导出器字符串不证明来源或商用许可。

下一步建议负责人先认可造型，再明确授权局部检查/必要修补、完整人形＋尾巴绑定和一段待机/走路验证。当前仅完成文件复核，未改原件、源网格/材质、既有二维资产、游戏程序或其他工作流。

## Blender中打开与跨机器使用

1. 在Blender新建常规场景，删除新场景的默认立方体，避免遮住模型。
2. 选择 **File（文件）→ Import（导入）→ glTF 2.0 (.glb, .gltf)**，找到本目录的[source.glb](source.glb)并导入。GLB通过“导入”加载；“打开”用于Blender的.blend工程。
3. 保持模型选中，在三维视图区选择 **View（视图）→ Frame Selected（查看所选）**，居中显示模型。Mac没有数字小键盘也能通过该菜单操作。
4. 点击三维视图区右上角的 **Material Preview（材质预览）** 球形按钮，等待贴图显示。GLB已内嵌三张贴图，不需要另找贴图文件。
5. 如需保存后续编辑，选择 **File（文件）→ Save As（另存为）** 保存为新的.blend工程，例如`foxfire-working.blend`。本次只提供原始GLB和复核文件，尚未创建该工作工程或动画。

另一台机器先将项目更新到`origin/master`，再从其本地项目目录打开`godot-demo/art/concepts/foxfire_imp/hunyuan_model_review_v1/source.glb`；不依赖此Mac的Downloads路径。若以后新增.blend工程，也需纳入后续Git提交才能跨机器同步。

参考：[Blender官方glTF导入说明](https://docs.blender.org/manual/en/3.6/addons/import_export/scene_gltf2.html)、[聚焦所选物体](https://docs.blender.org/manual/en/4.1/editors/3dview/navigate/navigation.html#frame-selected)、[材质预览](https://docs.blender.org/manual/en/3.3/editors/3dview/display/shading.html#material-preview)。

## 远端同步授权

2026-10-12，负责人在被明确询问“是否允许将这份GLB和审核预览同步到项目Gitee”后答复：“要推送，我会跨机器开发”。原始GLB、审核预览和说明由此纳入本批提交推送范围，目标为项目`origin/master`：https://gitee.com/baiweicheng/tower-defense.git 。此前安全审批要求的单独外传授权已补齐，授权阻塞解除；实际同步结果以Git远端为准。此授权不等于确认模型的商用许可，也不扩展为绑骨或游戏接入。
