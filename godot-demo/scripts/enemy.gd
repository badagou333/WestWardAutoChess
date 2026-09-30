class_name JourneyEnemy
extends Node2D

signal defeated(enemy)

var enemy_type := "rat"
var display_name := "灰鼠喽啰"
var battle_cell := Vector2i(-1, -1)
var max_health := 55.0
var health := 55.0
var damage := 10.0
var attack_interval := 0.9
var attack_range_cells := 1
var move_interval := 0.65
var attack_cooldown := 0.0
var move_cooldown := 0.0
var reward := 1
var dead := false
var portrait: Sprite2D
var presentation
const Presentation = preload("res://scripts/presentation/character_presentation.gd")
var idle_phase := 0.0
var hit_time := 0.0
var death_time := 0.0
var attack_time := 0.0

const ENEMY_ATLAS = preload("res://art/demo/enemy_atlas_keyed.png")
const ATLAS_REGIONS := {
	"rat": Rect2(0, 0, 768, 512),
	# The tiger's tall plume crosses the atlas guide; trim the boar cell to avoid bleed.
	"boar": Rect2(768, 0, 768, 470),
	"wolf": Rect2(0, 512, 768, 512),
	"bear_lord": Rect2(768, 512, 768, 512)
}
const ENEMY_DATA := {
	"rat": {"name": "灰鼠喽啰", "hp": 52.0, "damage": 7.0, "interval": 0.95, "move": 0.58, "reward": 1, "scale": 0.29},
	"boar": {"name": "山猪喽啰", "hp": 96.0, "damage": 10.0, "interval": 1.1, "move": 0.7, "reward": 1, "scale": 0.30},
	# Preserve prototype combat values; this visual replacement is not a balance approval.
	"wolf": {"name": "山狼", "hp": 155.0, "damage": 14.0, "interval": 0.9, "move": 0.52, "reward": 2, "scale": 0.32},
	"bear_lord": {"name": "熊山君", "hp": 400.0, "damage": 22.0, "interval": 1.1, "move": 0.75, "reward": 6, "scale": 0.38}
}

func setup(new_type: String) -> void:
	enemy_type = new_type
	var data: Dictionary = ENEMY_DATA[enemy_type]
	display_name = data.name
	max_health = data.hp
	health = max_health
	damage = data.damage
	attack_interval = data.interval
	attack_range_cells = 3 if enemy_type == "rat" else 1 # Trial sling range.
	move_interval = data.move
	reward = data.reward
	var atlas_texture := AtlasTexture.new()
	atlas_texture.atlas = ENEMY_ATLAS
	atlas_texture.region = ATLAS_REGIONS[enemy_type]
	atlas_texture.filter_clip = true
	portrait = Sprite2D.new()
	portrait.texture = atlas_texture
	portrait.centered = true
	portrait.position = Vector2(0, -18)
	portrait.scale = Vector2.ONE * data.scale
	portrait.z_index = -1
	add_child(portrait)
	if enemy_type in ["bear_lord", "wolf", "boar", "rat"]:
		presentation = Presentation.new()
		presentation.setup_visual({"wolf":"mountain_wolf","rat":"gray_rat"}.get(enemy_type,enemy_type),"nine_sols_v1")
		presentation.foot_anchor = Vector2.ZERO
		presentation.show_anchor = false
		presentation.show_status = false
		presentation.z_index = -1
		add_child(presentation)
		portrait.hide()
	idle_phase = randf_range(0.0, TAU)
	queue_redraw()

func tick_visual(delta: float) -> void:
	if presentation != null:
		presentation.tick(delta)
		presentation.z_index = -1
		if dead and presentation.visual_alpha <= 0: queue_free()
	else:
		idle_phase += delta * 2.4
		hit_time = maxf(0,hit_time-delta)
		attack_time = maxf(0,attack_time-delta)
		portrait.position.y = -18 - absf(sin(idle_phase))*2
		portrait.modulate = Color(1.6,1.4,1.2) if hit_time > 0 else Color.WHITE
		portrait.scale = Vector2.ONE * float(ENEMY_DATA[enemy_type].scale) * (1.1 if attack_time > 0 else 1.0)
		if dead:
			death_time += delta
			modulate.a = maxf(0,1-death_time/0.4)
			if death_time >= 0.4: queue_free()
	queue_redraw()

func play_attack() -> void:
	if presentation != null: presentation.play_attack()
	else: attack_time = 0.12

func take_damage(amount: float) -> void:
	if dead: return
	health = maxf(0,health-amount)
	if health == 0:
		dead = true
		defeated.emit(self)
	elif presentation != null:
		presentation.play_hit()
	else:
		hit_time = 0.1
	queue_redraw()

func play_death() -> void:
	if presentation != null: presentation.play_retreat()

func _draw() -> void:
	var width := 88.0 if enemy_type == "bear_lord" else 66.0
	var height := -150 if enemy_type == "bear_lord" else -110
	if enemy_type == "wolf": height = -82
	if enemy_type == "rat": height = -82
	draw_rect(Rect2(-width * 0.5, height, width, 8), Color("45242d"), true)
	draw_rect(Rect2(-width * 0.5 + 2, height + 2, (width - 4) * health / max_health, 4), Color("f05f67"), true)
