# 美术方向：丰收童话贴纸风

## 核心规则

- 西式2D卡通贴纸角色，圆润比例，大头小身体。
- 深棕色粗描边，不使用纯黑轮廓。
- 丰收黄、田野绿、木材棕、辣椒红和鼠群灰紫为主色。
- 平涂为主，只保留少量柔和高光和阴影。
- 守卫统一朝右，敌人统一朝左。
- 单角色、完整身体、强轮廓，缩小至80～120像素仍能识别职业。
- 不使用写实武器、恐怖表情、血腥效果和复杂背景。

## 生产提示模板

```text
Use case: stylized-concept
Asset type: production 2D game character sprite for chroma-key extraction
Primary request: a single [角色描述] for a cozy harvest tower-defense game
Scene/backdrop: perfectly uniform flat solid pure cyan background (#00FFFF), edge to edge; no checkerboard, gradient, texture, floor or shadow
Style/medium: polished 2D Western cartoon game sprite; rounded shapes; bold dark-brown outline; flat harvest colors with minimal soft shading
Composition/framing: centered single character, full body visible, generous cyan padding, square asset, strong silhouette readable at 100 pixels tall
Constraints: one character only; no text, logo or watermark; clean outer silhouette; keep all character colors far from cyan
Avoid: cropped body, multiple poses, sprite sheet, photorealism, anime, excessive detail
```

## 当前资产

- `units/corn.png`：玉米射手
- `units/potato.png`：土豆盾卫
- `units/chili.png`：辣椒炮手
- `units/coffee.png`：咖啡豆辅助
- `enemies/small.png`：小老鼠
- `enemies/fat.png`：装甲胖鼠
- `enemies/thief.png`：盗粮鼠
- `enemies/king.png`：鼠王
- `environment/battlefield.png`：粮仓战场

角色使用 `materials/chroma_key.gdshader` 在Godot中实时去除青幕背景。新增角色必须避开高饱和青色，避免材质误删角色细节。

