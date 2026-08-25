class_name EscortTarget
extends Node2D

var max_health := 300.0
var health := 300.0
var dead := false
var portrait: Sprite2D
var pulse := 0.0

const HERO_ATLAS = preload("res://art/demo/hero_atlas_keyed.png")

func _ready() -> void:
	var atlas_texture := AtlasTexture.new()
	atlas_texture.atlas = HERO_ATLAS
	atlas_texture.region = Rect2(0, 0, 512, 512)
	atlas_texture.filter_clip = true
	portrait = Sprite2D.new()
	portrait.texture = atlas_texture
	portrait.centered = true
	portrait.position = Vector2(0, -19)
	portrait.scale = Vector2.ONE * 0.31
	portrait.z_index = -1
	add_child(portrait)
	queue_redraw()

func _process(delta: float) -> void:
	pulse += delta
	if is_instance_valid(portrait):
		portrait.position.y = -19.0 + sin(pulse * 1.7) * 1.5
	queue_redraw()

func reset() -> void:
	health = max_health
	dead = false
	modulate = Color.WHITE
	queue_redraw()

func take_damage(amount: float) -> bool:
	if dead:
		return true
	health = max(0.0, health - amount)
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1.0, 0.45, 0.45), 0.06)
	tween.tween_property(self, "modulate", Color.WHITE, 0.12)
	if health <= 0.0:
		dead = true
	queue_redraw()
	return dead

func _draw() -> void:
	var glow := 48.0 + sin(pulse * 2.0) * 3.0
	draw_circle(Vector2.ZERO, glow, Color(1.0, 0.72, 0.16, 0.16))
	draw_rect(Rect2(-44, -76, 88, 9), Color("45242d"), true)
	draw_rect(Rect2(-42, -74, 84 * health / max_health, 5), Color("6fe283"), true)
	draw_string(ThemeDB.fallback_font, Vector2(-40, 64), "唐僧", HORIZONTAL_ALIGNMENT_CENTER, 80, 18, Color("fff0aa"))
