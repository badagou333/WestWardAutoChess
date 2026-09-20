class_name EscortHero
extends Node2D

var unit_type := "rabbit"
var display_name := "玉兔枪兵"
var quality := "white"
var star := 1
var board_row := -1
var board_col := -1
var bench_slot := -1
var battle_cell := Vector2i(-1, -1)
var home_cell := Vector2i(-1, -1)
var cost := 1
var max_health := 100.0
var health := 100.0
var damage := 12.0
var attack_interval := 1.0
var attack_range_cells := 1
var move_interval := 0.55
var cooldown := 0.0
var move_cooldown := 0.0
var mana := 0.0
var max_mana := 100.0
var active_in_battle := false
var battle_dead := false
var selected := false
var dragging := false
var merge_locked := false
var home_position := Vector2.ZERO
var haste_time := 0.0
var skill_casts := 0
var portrait: Sprite2D
var presentation
const Presentation = preload("res://scripts/presentation/character_presentation.gd")
const RoleVisuals = preload("res://scripts/presentation/role_visuals.gd")
var idle_phase := 0.0

const HERO_ATLAS = preload("res://art/demo/hero_atlas_keyed.png")
const ATLAS_REGIONS := {
	"rabbit": Rect2(512, 0, 512, 512),
	"crane": Rect2(1024, 0, 512, 512),
	"deer": Rect2(0, 512, 512, 512),
	"ox": Rect2(512, 512, 512, 512),
	"fox": Rect2(1024, 512, 512, 512)
}

const QUALITY_DATA := {
	"white": {"name": "白色", "color": Color("e9e5db"), "cost": 1},
	"green": {"name": "绿色", "color": Color("72d681"), "cost": 2},
	"blue": {"name": "蓝色", "color": Color("69b8ff"), "cost": 3},
	"purple": {"name": "紫色", "color": Color("bd82ff"), "cost": 4},
	"gold": {"name": "金色", "color": Color("ffd45f"), "cost": 5}
}

const UNIT_DATA := {
	"rabbit": {"name": "玉兔枪兵", "quality": "white", "hp": 115.0, "damage": 14.0, "interval": 0.85, "range": 1, "move": 0.48, "skill1": "月牙突刺", "skill2": "迅捷步法", "skill3": "月影连环"},
	"crane": {"name": "青羽弓手", "quality": "white", "hp": 82.0, "damage": 12.0, "interval": 0.92, "range": 3, "move": 0.58, "skill1": "穿云箭", "skill2": "鹰眼", "skill3": "箭雨"},
	"deer": {"name": "山鹿刀客", "quality": "green", "hp": 145.0, "damage": 19.0, "interval": 0.95, "range": 1, "move": 0.48, "skill1": "回风斩", "skill2": "乘风", "skill3": "逐影八方"},
	"ox": {"name": "铁角护卫", "quality": "green", "hp": 310.0, "damage": 10.0, "interval": 1.15, "range": 1, "move": 0.68, "skill1": "震地", "skill2": "铁壁", "skill3": "不动如山"},
	"fox": {"name": "灵狐术士", "quality": "blue", "hp": 96.0, "damage": 24.0, "interval": 1.25, "range": 3, "move": 0.62, "skill1": "灵火", "skill2": "聚灵", "skill3": "狐火燎原"}
}

func setup(new_type: String, new_star := 1) -> void:
	unit_type = new_type
	star = new_star
	_apply_stats(true)
	_create_portrait()
	presentation = Presentation.new()
	presentation.setup_visual(RoleVisuals.LEGACY_HEROES[unit_type])
	presentation.show_anchor = false
	presentation.show_status = false
	presentation.z_index = -1
	add_child(presentation)
	portrait.hide()
	queue_redraw()

func _create_portrait() -> void:
	if is_instance_valid(portrait):
		portrait.queue_free()
	var atlas_texture := AtlasTexture.new()
	atlas_texture.atlas = HERO_ATLAS
	atlas_texture.region = ATLAS_REGIONS[unit_type]
	atlas_texture.filter_clip = true
	portrait = Sprite2D.new()
	portrait.texture = atlas_texture
	portrait.centered = true
	portrait.position = Vector2(0, -18)
	portrait.scale = Vector2.ONE * 0.33
	portrait.z_index = -1
	add_child(portrait)
	idle_phase = randf_range(0.0, TAU)

func _process(delta: float) -> void:
	if presentation != null:
		var game = get_parent()
		if game != null and game.get("battle_paused") == true:
			return
		var speed = game.get("battle_speed") if game != null else null
		presentation.tick(delta * (float(speed) if speed != null else 1.0))
		presentation.z_index = -1
	idle_phase += delta * 1.8
	if haste_time > 0.0:
		haste_time = max(0.0, haste_time - delta)
	if is_instance_valid(portrait) and not dragging and not battle_dead:
		portrait.position.y = -18.0 + sin(idle_phase) * 2.0

func set_bench_mode(on_bench: bool) -> void:
	if presentation != null:
		presentation.scale = Vector2.ONE * (0.48 if on_bench else 1.0)
	if not is_instance_valid(portrait):
		return
	var base_scale := 0.22 if on_bench else 0.30
	portrait.scale = Vector2.ONE * base_scale * (1.0 + 0.06 * float(star - 1))
	queue_redraw()

func _apply_stats(full_heal: bool) -> void:
	var data: Dictionary = UNIT_DATA[unit_type]
	display_name = data.name
	quality = data.quality
	cost = QUALITY_DATA[quality].cost
	var multiplier: float = [1.0, 1.8, 3.2][star - 1]
	max_health = data.hp * multiplier
	damage = data.damage * multiplier
	attack_interval = data.interval / (1.0 + 0.12 * float(star - 1))
	attack_range_cells = data.range
	move_interval = data.move
	if star >= 2:
		match unit_type:
			"rabbit": attack_interval *= 0.82
			"crane": attack_range_cells += 1
			"deer": damage *= 1.18
			"ox": max_health *= 1.2
			"fox": max_mana = 82.0
	if full_heal:
		health = max_health
	else:
		health = min(health, max_health)

func upgrade() -> void:
	if star >= 3:
		return
	star += 1
	_apply_stats(true)
	if is_instance_valid(portrait):
		portrait.modulate = Color("fff1a5") if star == 2 else Color("ffd27b")
	scale = Vector2(1.3, 1.3)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, 0.35)
	queue_redraw()

func begin_battle() -> void:
	if presentation != null:
		presentation.reset_visual()
	home_position = position
	home_cell = Vector2i(board_row, board_col)
	battle_cell = home_cell
	health = max_health
	mana = 0.0
	cooldown = randf_range(0.0, 0.2)
	move_cooldown = 0.0
	skill_casts = 0
	active_in_battle = board_row >= 0
	battle_dead = false
	visible = true
	modulate = Color.WHITE
	queue_redraw()

func end_battle() -> void:
	if presentation != null:
		presentation.reset_visual()
	active_in_battle = false
	battle_dead = false
	health = max_health
	mana = 0.0
	battle_cell = Vector2i(board_row, board_col)
	visible = true
	position = home_position
	modulate = Color.WHITE
	queue_redraw()

func effective_interval() -> float:
	return attack_interval * (0.7 if haste_time > 0.0 else 1.0)

func add_mana(amount: float) -> void:
	mana = min(max_mana, mana + amount)
	queue_redraw()

func play_attack() -> void:
	if presentation != null:
		presentation.play_attack()
		return
	if not is_instance_valid(portrait):
		return
	var rest_scale := portrait.scale
	var tween := create_tween()
	tween.tween_property(portrait, "scale", Vector2(rest_scale.x * 1.08, rest_scale.y * 0.94), 0.07)
	tween.tween_property(portrait, "scale", rest_scale, 0.13).set_trans(Tween.TRANS_BACK)

func take_damage(amount: float) -> bool:
	if battle_dead:
		return true
	health = max(0.0, health - amount)
	add_mana(amount * 0.3)
	if presentation != null:
		presentation.play_hit()
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1.0, 0.45, 0.45), 0.06)
	tween.tween_property(self, "modulate", Color.WHITE, 0.1)
	if health <= 0.0:
		battle_dead = true
		active_in_battle = false
		if presentation != null:
			presentation.play_retreat()
		else:
			visible = false
	queue_redraw()
	return battle_dead

func heal(amount: float) -> void:
	health = min(max_health, health + amount)
	queue_redraw()

func skill_data() -> Dictionary:
	return UNIT_DATA[unit_type]

func quality_data() -> Dictionary:
	return QUALITY_DATA[quality]

func _draw() -> void:
	if board_row >= 0 and not battle_dead:
		_draw_ellipse_custom(Vector2(0, 34), 38.0, 10.0, Color(0.12, 0.07, 0.02, 0.25))
		draw_rect(Rect2(-38, -69, 76, 8), Color("40262b"), true)
		draw_rect(Rect2(-36, -67, 72 * health / max_health, 4), Color("66dc75"), true)
		draw_rect(Rect2(-38, -58, 76, 5), Color("24344d"), true)
		draw_rect(Rect2(-36, -57, 72 * mana / max_mana, 3), Color("62c7ff"), true)
	var stars := "★".repeat(star)
	draw_string(ThemeDB.fallback_font, Vector2(-15 * star, 60), stars, HORIZONTAL_ALIGNMENT_CENTER, 30 * star, 19, Color("ffe56f"))
	if merge_locked:
		draw_string(ThemeDB.fallback_font, Vector2(22, -54), "🔒", HORIZONTAL_ALIGNMENT_LEFT, 26, 18, Color.WHITE)
	if selected:
		draw_arc(Vector2.ZERO, 48, 0, TAU, 48, Color("fff2a3"), 4)

func _draw_ellipse_custom(center: Vector2, radius_x: float, radius_y: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(25):
		var angle := TAU * float(i) / 24.0
		points.append(center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	draw_colored_polygon(points, color)
