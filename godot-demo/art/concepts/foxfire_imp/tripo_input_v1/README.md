# 狐火小妖 · Tripo单图建模输入

日期：2026-10-11。负责人要求核对Tripo图片要求，并制作一张狐火小妖输入图，由负责人自行生成模型。

上传文件：`foxfire-tripo-front-tpose.png`。1254×1254、RGB PNG、1,325,452字节，白色背景。内置imagegen生成一次、定向调整留白一次；采用第二张原件，未像素加工。主体近正面T姿、手脚完整、腿间可辨、一条实体尾巴，无文字/多视图拼板/漂浮火焰。白狐、赤围巾、暗袍、腰饰、橙白单尾沿用已认可[九日方向图](../nine_sols_v1/foxfire-nine-sols-sample.png)，只是本次建模输入，不替换角色原稿、运行图或确认完整三维设计。

## 官方要求核对

截至本次检查：

- [角色输入教程](https://www.tripo3d.ai/blog/comic-character-to-3d)：单角色、正面全身、近T姿、白色或透明背景；四肢和附属物避免遮挡，去除文字、场景和运动线。
- [Studio质量指南](https://www.tripo3d.ai/help/features/how-to-get-better-image-to-3d-results)：建议至少1024×1024、主体占画面70%～85%、四周留白、均匀光照。属于最佳实践，不是已核实的全部上传硬限制。
- [Image to Model API](https://developers.tripo3d.ai/en/docs/generation-image-to-model)：PNG/JPEG/WebP，最大20MB，建议至少256×256；这是API参数，不把256像素写成Studio建议质量。
- [自动绑定帮助](https://www.tripo3d.ai/help/features/is-it-possible-to-upload-my-existing-model-for-animation)：人形T姿是支持范围；本图采用双足T姿，但不能据此保证生成模型自动绑定、尾巴与衣摆权重合格。

## 使用

1. 在Tripo Studio选择Image to 3D，上传本目录最终PNG。一次只上传这一个单人物图，单图模式不拼正侧背三个人。
2. 生成后旋转模型，检查耳尖、双手、双脚、腿间间隙、尾根及背面。特别检查尾巴是否被复制或与衣摆粘连、宽袖/围巾是否粘住肩臂；这些部位不能只看正面预览。
3. 若轮廓基本成立，导出带材质的GLB供Blender/Godot继续处理。若背面猜错，下一轮再制作一致的独立侧/背图走多视图输入；本次不额外生成未经核对的背面。

狐火飞弹、手中火焰与粒子后续独立制作，不要求Tripo把它们重建成实体。T姿是建模/绑定参考，游戏斜俯视镜头在三维模型完成后设置。

## 生成与检查

实发提示词分别为`PROMPT.txt`与`PROMPT_FRAMING.txt`。生成首件为`exec-90c28d91-1b72-44a0-9a7a-8973d0d82757.png`，耳尖留白紧而未采用；最终工具原件为`exec-4997b831-2cf8-4753-af03-a8658550f369.png`，从Codex生成目录原样复制。

最终SHA-256：`f710adfbaef1f5d8c8466c9ae2d6fb4576033f11a90ce0094df5f85f23e3bbcc`。以亮度低于235的像素估计主体包围盒为(125,128,1128,1129)，宽约79.98%、高约79.82%，四侧留白约9.97%～10.21%；该阈值测量仅验证构图，不等于透明边界或三维结构检查。一次视觉检查全身/T姿/身份/单尾/无火焰及留白成立，服装轮廓和表情存在生成细化差异。

本次仅交付建模输入图，未上传Tripo、登录付费服务、生成网格、绑定动画或改游戏。尾根隐藏面、衣袖/裙摆分件及权重仍需模型实测。来源/检查范围见`validation.json`。
