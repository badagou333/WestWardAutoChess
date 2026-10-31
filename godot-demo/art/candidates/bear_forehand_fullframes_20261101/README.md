# 熊山君正面完整帧试验（未完成，禁止接入）

更新时间：2026-11-01。负责人要求检查并修正正面帧率和肩甲色变。本目录是未通过视觉审核的试验，仅用于继续修复，**不替换独立展示**。现有正面运行20帧，背面340个时间点（含重复图）；源正面96帧，3.5秒，PTS非均匀，应按源PTS而非平均FPS播放。

## 本批成果和仍需修复

- 重新完整解码已认可的正面视频96帧，保留所有PTS，统一384×320透明画布、脚锚参数(177,213)，源视频时间和独立展示音轨不改。`manifest.json`为试验数据，状态 `draft_not_for_runtime`。
- 抠像借用背面候选的基础算法，但禁用背面专属足部与灰弧修饰；这是未经批准的正面初步转换，不是旧20帧的等价复建。新旧首帧水平位置有约1像素偏差，双重不透明区对齐后仍有色差，锚点与抠像需重新标定。真实脚点不能只据manifest宣称一致。
- 源视频第52、53帧棍头在画外截断，新素材忠实保留这个缺陷；52帧左脚有镂空，52～54帧灰软边及少量亮点。透明帧四周4px为空不代表源内容完整。
- 护甲由浅银灰转暗灰且形状也变化：源视频同一时段已可见，不能归咎于播放器或抠图。当前96帧**未修肩甲**；固定整帧调色会影响毛发、布料和正常高光，不能作交付。
- 对第52帧尝试内置 image_gen 局部修色，结果为1374×1145并重新绘制身体及武器，未保持384×320画布及原像素，故不采用、不插入动画。成功调用但不等于修复成功。

## 结果与验证

`frames/attack_001.png` 至 `attack_096.png`；`contact-dark.jpg`、`contact-light.jpg`为全帧深浅底初检。已对每帧尺寸、四边透明、源时间顺序及逐项散列做校验；独立只读复核查看深浅底和关键姿势，并指出上述缺陷。`build.py`通过FFmpeg7.1和Python/Pillow/NumPy重新从入库源解码生成；复建96帧与试验输出逐字节相同。重新构建示例（输出目录必须不存在）：

```
python3 build.py --ffmpeg /path/to/ffmpeg --output /tmp/bear-front-rebuild
```

临时复制独立展示，将素材与manifest替换，并**仅在临时副本**将既有测试的“20帧”断言改为96；无窗口3577项0失败，播放序列加载、帧时间索引、音轨和方向控制通过。测试有沙盒日志目录与macOS证书读取告警；无真实连续窗口/设备听感，不等于视觉质量通过或正式接入。现有运行播放器能够按manifest动态载入，但源项目测试的20帧断言将由06在真正接入时修订。

## 后续

需要以同一肩甲的颜色与形状为目标建立**随姿势变化的局部遮罩**，逐帧核深浅底、相邻过渡、皮毛/衣物与高光是否受影响；解决缺棍和足部遮罩，并核精确配准后，才能请求06在独立展示接入，由05和07分别进行连续视觉与技术检查。不能把当前草稿或模型重绘结果称为已修好。

图像编辑试验的实际提示：Make a precise local retouch of reference image 1, a transparent game animation frame. Reference 2 is the same character at rest and provides the intended dull silvery-gray armored shoulder design. Preserve frame 1's EXACT pose, silhouette, every body part, motion, lighting, background transparency, canvas, size, placement, red fabric, club, hands, fur, feet and all other pixels unchanged. Only correct the visible near shoulder metal armor color and patchwork look so it consistently matches the muted silver gray plate armor in reference 2, while preserving its orientation and believable highlights. Do not change angle or redraw the pose; make no additions. Transparent background. This is a single-frame feasibility test, do not produce a grid or sheet.
