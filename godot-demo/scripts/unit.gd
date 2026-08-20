class_name FoodUnit
extends Node2D

var unit_type := "corn"
var display_name := "玉米射手"
var star := 1
var lane := -1
var column := -1
var bench_slot := -1
var cost := 30
var max_health := 100.0
var health := 100.0
var damage := 12.0
var attack_interval := 1.0
var attack_range := 720.0
var cooldown := 0.0
var is_blocker := false
var selected := false
var dragging := false
var portrait: Sprite2D
var idle_phase := 0.0

const CHROMA_SHADER = preload("res://materials/chroma_key.gdshader")
const UNIT_TEXTURES := {
	"corn": preload("res://art/units/corn.png"),
	"chili": preload("res://art/units/chili.png"),
	"potato": preload("res://art/units/potato.png"),
	"coffee": preload("res://art/units/coffee.png")
}

const UNIT_DATA := {
	"corn": {"name": "玉米射手", "cost": 30, "hp": 90.0, "damage": 13.0, "interval": 0.9, "range": 720.0},
	"chili": {"name": "辣椒炮手", "cost": 45, "hp": 85.0, "damage": 24.0, "interval": 1.65, "range": 720.0},
	"potato": {"name": "土豆盾卫", "cost": 25, "hp": 330.0, "damage": 8.0, "interval": 1.15, "range": 78.0},
	"coffee": {"name": "咖啡豆", "cost": 40, "hp": 105.0, "damage": 7.0, "interval": 1.2, "range": 620.0}
}

func setup(new_type: String, new_star := 1) -> void:
	unit_type = new_type
	star = new_star
	_apply_stats(true)
	_create_portrait()
	queue_redraw()

func _create_portrait() -> void:
	if is_instance_valid(portrait):
		portrait.queue_free()
	portrait = Sprite2D.new()
	portrait.texture = UNIT_TEXTURES[unit_type]
	portrait.centered = true
	portrait.position = Vector2(0, -5)
	portrait.scale = Vector2(0.082, 0.082)
	portrait.z_index = -1
	var chroma_material := ShaderMaterial.new()
	chroma_material.shader = CHROMA_SHADER
	portrait.material = chroma_material
	add_child(portrait)
	idle_phase = randf_range(0.0, TAU)

func _process(delta: float) -> void:
	idle_phase += delta * (2.1 if unit_type == "coffee" else 1.65)
	if is_instance_valid(portrait) and not dragging:
		portrait.position.y = -5.0 + sin(idle_phase) * 2.0

func set_bench_mode(on_bench: bool) -> void:
	if not is_instance_valid(portrait):
		return
	var base_scale := 0.056 if on_bench else 0.082
	portrait.scale = Vector2.ONE * base_scale * (1.0 + 0.06 * float(star - 1))
	queue_redraw()

func play_attack() -> void:
	if not is_instance_valid(portrait):
		return
	var rest_scale := portrait.scale
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(portrait, "scale", Vector2(rest_scale.x * 0.90, rest_scale.y * 1.08), 0.07)
	tween.tween_property(portrait, "scale", rest_scale, 0.14)

func _apply_stats(full_heal: bool) -> void:
	var data: Dictionary = UNIT_DATA[unit_type]
	display_name = data.name
	cost = data.cost
	var multiplier: float = [1.0, 1.8, 3.2][star - 1]
	max_health = data.hp * multiplier
	damage = data.damage * multiplier
	attack_interval = data.interval / (1.0 + 0.12 * float(star - 1))
	attack_range = data.range
	is_blocker = unit_type == "potato"
	if full_heal:
		health = max_health
	else:
		health = min(health, max_health)

func upgrade() -> void:
	if star >= 3:
		return
	star += 1
	_apply_stats(true)
	scale = Vector2(1.35, 1.35)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, 0.35)
	queue_redraw()

func take_damage(amount: float) -> bool:
	health = max(0.0, health - amount)
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1.0, 0.45, 0.45), 0.06)
	tween.tween_property(self, "modulate", Color.WHITE, 0.1)
	queue_redraw()
	return health <= 0.0

func _draw() -> void:
	# 阴影、血条和星级由程序绘制，角色本体由统一的贴纸素材表现。
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_ellipse(Vector2(0, 35), 34.0, 9.0, Color(0.16, 0.09, 0.03, 0.28))
	if lane >= 0:
		draw_rect(Rect2(-38, -54, 76, 8), Color("472822"), true)
		draw_rect(Rect2(-36, -52, 72 * health / max_health, 4), Color("76d56b"), true)
	var star_text := "★".repeat(star)
	draw_string(ThemeDB.fallback_font, Vector2(-15 * star, 55), star_text, HORIZONTAL_ALIGNMENT_CENTER, 30 * star, 19, Color("ffe36e"))
	if selected:
		draw_arc(Vector2(0, -2), 49, 0, TAU, 48, Color("fff1a6"), 4)
