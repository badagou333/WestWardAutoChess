class_name RatEnemy
extends Node2D

signal defeated(enemy)
signal reached_base(enemy)

var enemy_type := "small"
var display_name := "小老鼠"
var lane := 0
var max_health := 55.0
var health := 55.0
var speed := 44.0
var damage := 12.0
var attack_interval := 0.85
var attack_cooldown := 0.0
var reward := 5
var base_damage := 1
var dead := false
var wave_scale := 1.0
var portrait: Sprite2D
var idle_phase := 0.0

const CHROMA_SHADER = preload("res://materials/chroma_key.gdshader")
const ENEMY_TEXTURES := {
	"small": preload("res://art/enemies/small.png"),
	"fat": preload("res://art/enemies/fat.png"),
	"thief": preload("res://art/enemies/thief.png"),
	"king": preload("res://art/enemies/king.png")
}

const ENEMY_DATA := {
	"small": {"name": "小老鼠", "hp": 52.0, "speed": 48.0, "damage": 10.0, "interval": 0.9, "reward": 5, "base_damage": 1},
	"fat": {"name": "胖老鼠", "hp": 145.0, "speed": 27.0, "damage": 16.0, "interval": 1.2, "reward": 10, "base_damage": 2},
	"thief": {"name": "偷粮鼠", "hp": 90.0, "speed": 40.0, "damage": 20.0, "interval": 0.7, "reward": 15, "base_damage": 2},
	"king": {"name": "鼠王", "hp": 650.0, "speed": 20.0, "damage": 28.0, "interval": 0.75, "reward": 60, "base_damage": 4}
}

func setup(new_type: String, new_lane: int, difficulty: float) -> void:
	enemy_type = new_type
	lane = new_lane
	wave_scale = difficulty
	var data: Dictionary = ENEMY_DATA[enemy_type]
	display_name = data.name
	max_health = data.hp * difficulty
	health = max_health
	speed = data.speed
	damage = data.damage * (0.85 + difficulty * 0.15)
	attack_interval = data.interval
	reward = data.reward
	base_damage = data.base_damage
	_create_portrait()
	queue_redraw()

func _create_portrait() -> void:
	portrait = Sprite2D.new()
	portrait.texture = ENEMY_TEXTURES[enemy_type]
	portrait.centered = true
	portrait.position = Vector2(0, -3)
	var sprite_scale := 0.065
	if enemy_type == "fat":
		sprite_scale = 0.074
	elif enemy_type == "thief":
		sprite_scale = 0.068
	elif enemy_type == "king":
		sprite_scale = 0.102
	portrait.scale = Vector2.ONE * sprite_scale
	portrait.z_index = -1
	var chroma_material := ShaderMaterial.new()
	chroma_material.shader = CHROMA_SHADER
	portrait.material = chroma_material
	add_child(portrait)
	idle_phase = randf_range(0.0, TAU)

func _process(delta: float) -> void:
	idle_phase += delta * (4.6 if enemy_type == "small" else 2.6)
	if is_instance_valid(portrait) and not dead:
		portrait.position.y = -3.0 + abs(sin(idle_phase)) * -2.5

func play_attack() -> void:
	if not is_instance_valid(portrait):
		return
	var rest_position := portrait.position
	var tween := create_tween()
	tween.tween_property(portrait, "position:x", rest_position.x - 8.0, 0.07)
	tween.tween_property(portrait, "position:x", rest_position.x, 0.12).set_trans(Tween.TRANS_BACK)

func take_damage(amount: float) -> void:
	if dead:
		return
	health = max(0.0, health - amount)
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color.WHITE * 1.8, 0.05)
	tween.tween_property(self, "modulate", Color.WHITE, 0.08)
	queue_redraw()
	if health <= 0.0:
		dead = true
		defeated.emit(self)

func play_death() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.22)
	tween.tween_property(self, "modulate:a", 0.0, 0.22)
	tween.chain().tween_callback(queue_free)

func _draw() -> void:
	var bar_width := 86.0 if enemy_type == "king" else 64.0
	var bar_y := -67.0 if enemy_type == "king" else -49.0
	draw_rect(Rect2(-bar_width * 0.5, bar_y, bar_width, 8), Color("43262a"), true)
	draw_rect(Rect2(-bar_width * 0.5 + 2, bar_y + 2, (bar_width - 4) * health / max_health, 4), Color("ef6b63"), true)
