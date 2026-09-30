extends RefCounted

# Four-wave playable-demo economy; tuning values, not chapter progression rules.
const STARTING_COINS := 3
const LEVEL_COSTS := [4,6,8,10,12,14,16]
const SHOP_SLOTS := 3
const WAVE_HEALTH_SCALE := [1.0,1.15,1.35,1.60]
const WAVE_DAMAGE_SCALE := [1.0,1.05,1.10,1.20]

# Legacy single-encounter waves; not chapter-one final level data.
const WAVES := [
	{"name": "灰鼠试探", "preview": "上方三路 · 灰鼠喽啰 ×3", "units": ["rat", "rat", "rat"], "entries": [Vector2i(0, 1), Vector2i(0, 3), Vector2i(0, 5)]},
	{"name": "左右夹攻", "preview": "左右两翼 · 灰鼠 ×2 / 山猪 ×2", "units": ["rat", "boar", "rat", "boar"], "entries": [Vector2i(1, 0), Vector2i(1, 6), Vector2i(3, 0), Vector2i(3, 6)]},
	{"name": "山林围攻", "preview": "四角包围 · 山猪 ×2 / 山狼 ×2", "units": ["boar", "wolf", "boar", "wolf"], "entries": [Vector2i(0, 0), Vector2i(0, 6), Vector2i(4, 0), Vector2i(4, 6)]},
	{"name": "熊山君", "preview": "最终波 · 熊山君 Boss / 灰鼠护卫", "units": ["rat", "bear_lord"], "entries": [Vector2i(0, 3), Vector2i(4, 3)]}
]
