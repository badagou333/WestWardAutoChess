class_name EscortTarget
extends Node2D

var max_health := 300.0
var health := 300.0
var dead := false
var portrait: Sprite2D
var pulse := 0.0
var hit_time := 0.0

const HERO_ATLAS = preload("res://art/demo/hero_atlas_keyed.png")

func _ready() -> void:
	portrait = Sprite2D.new()
	portrait.texture = preload("res://scripts/presentation/character_presentation.gd")._texture("res://art/production/tangseng/nine_sols_v1/idle.png")
	portrait.centered = true
	portrait.position = Vector2(0, -90)
	portrait.z_index = -1
	add_child(portrait)
	queue_redraw()

func _process(delta: float) -> void:
	pulse += delta
	hit_time = maxf(0,hit_time-delta)
	modulate = Color(1.0,0.45,0.45) if hit_time > 0 else Color.WHITE
	if is_instance_valid(portrait):
		portrait.position.y = -90.0
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
	hit_time = 0.16
	if health <= 0.0:
		dead = true
	queue_redraw()
	return dead

func heal(amount: float) -> void:
	if not dead:
		health = minf(max_health, health + amount)
		queue_redraw()

func _draw() -> void:
	var glow := 48.0 + sin(pulse * 2.0) * 3.0
	draw_circle(Vector2.ZERO, glow, Color(1.0, 0.72, 0.16, 0.16))
	draw_rect(Rect2(-35, -120, 70, 7), Color("45242d"), true)
	draw_rect(Rect2(-33, -118, 66 * health / max_health, 3), Color("6fe283"), true)
	draw_string(ThemeDB.fallback_font, Vector2(-40, 64), "唐僧", HORIZONTAL_ALIGNMENT_CENTER, 80, 18, Color("fff0aa"))
