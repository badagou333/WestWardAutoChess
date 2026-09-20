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
var move_interval := 0.65
var attack_cooldown := 0.0
var move_cooldown := 0.0
var reward := 1
var dead := false
var portrait: Sprite2D
var presentation
const Presentation = preload("res://scripts/presentation/character_presentation.gd")
var idle_phase := 0.0

const ENEMY_ATLAS = preload("res://art/demo/enemy_atlas_keyed.png")
const ATLAS_REGIONS := {
	"rat": Rect2(0, 0, 768, 512),
	# The tiger's tall plume crosses the atlas guide; trim the boar cell to avoid bleed.
	"boar": Rect2(768, 0, 768, 470),
	"wolf": Rect2(0, 512, 768, 512),
	"tiger": Rect2(768, 512, 768, 512)
}
const ENEMY_DATA := {
	"rat": {"name": "灰鼠喽啰", "hp": 52.0, "damage": 7.0, "interval": 0.95, "move": 0.58, "reward": 1, "scale": 0.29},
	"boar": {"name": "山猪喽啰", "hp": 96.0, "damage": 10.0, "interval": 1.1, "move": 0.7, "reward": 1, "scale": 0.30},
	"wolf": {"name": "黑狼精英", "hp": 155.0, "damage": 14.0, "interval": 0.9, "move": 0.52, "reward": 2, "scale": 0.32},
	"tiger": {"name": "虎先锋", "hp": 240.0, "damage": 16.0, "interval": 1.1, "move": 0.75, "reward": 6, "scale": 0.38}
}

func setup(new_type: String) -> void:
	enemy_type = new_type
	var data: Dictionary = ENEMY_DATA[enemy_type]
	display_name = data.name
	max_health = data.hp
	health = max_health
	damage = data.damage
	attack_interval = data.interval
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
	if enemy_type == "tiger":
		presentation = Presentation.new()
		presentation.setup_visual("bear_lord")
		presentation.show_anchor = false
		presentation.show_status = false
		presentation.z_index = -1
		add_child(presentation)
		portrait.hide()
	idle_phase = randf_range(0.0, TAU)
	queue_redraw()

func _process(delta: float) -> void:
	if presentation != null:
		var game = get_parent()
		if game != null and game.get("battle_paused") == true:
			return
		var speed = game.get("battle_speed") if game != null else null
		presentation.tick(delta * (float(speed) if speed != null else 1.0))
		presentation.z_index = -1
		if dead and presentation.visual_alpha <= 0:
			queue_free()
	idle_phase += delta * 2.4
	if is_instance_valid(portrait) and not dead:
		portrait.position.y = -18.0 - abs(sin(idle_phase)) * 2.0

func play_attack() -> void:
	if presentation != null:
		presentation.play_attack()
		return
	if not is_instance_valid(portrait):
		return
	var rest_scale := portrait.scale
	var tween := create_tween()
	tween.tween_property(portrait, "scale", rest_scale * 1.1, 0.07)
	tween.tween_property(portrait, "scale", rest_scale, 0.12).set_trans(Tween.TRANS_BACK)

func take_damage(amount: float) -> void:
	if dead:
		return
	health = max(0.0, health - amount)
	if presentation != null:
		presentation.play_hit()
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1.7, 1.7, 1.7), 0.05)
	tween.tween_property(self, "modulate", Color.WHITE, 0.08)
	if health <= 0.0:
		dead = true
		defeated.emit(self)
	queue_redraw()

func play_death() -> void:
	if presentation != null:
		presentation.play_retreat()
		return
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.22)
	tween.tween_property(self, "modulate:a", 0.0, 0.22)
	tween.chain().tween_callback(queue_free)

func _draw() -> void:
	var width := 88.0 if enemy_type == "tiger" else 66.0
	draw_rect(Rect2(-width * 0.5, -72, width, 8), Color("45242d"), true)
	draw_rect(Rect2(-width * 0.5 + 2, -70, (width - 4) * health / max_health, 4), Color("f05f67"), true)
