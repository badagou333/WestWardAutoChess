class_name FoodProjectile
extends Node2D

signal impact(target, damage, splash, hit_position)

var target
var damage := 10.0
var speed := 520.0
var splash := 0.0
var projectile_type := "corn"

func setup(new_target, new_damage: float, new_type: String, new_splash: float) -> void:
	target = new_target
	damage = new_damage
	projectile_type = new_type
	splash = new_splash
	queue_redraw()

func _process(delta: float) -> void:
	if not is_instance_valid(target) or target.dead:
		queue_free()
		return
	var distance := global_position.distance_to(target.global_position)
	if distance < 18.0:
		impact.emit(target, damage, splash, global_position)
		queue_free()
		return
	global_position = global_position.move_toward(target.global_position, speed * delta)
	rotation = global_position.direction_to(target.global_position).angle()

func _draw() -> void:
	var color := Color("f4d34a")
	var radius := 7.0
	if projectile_type == "chili":
		color = Color("ff634f")
		radius = 11.0
	elif projectile_type == "coffee":
		color = Color("986045")
	# 简单的贴纸式拖尾让投射物在复杂背景上更容易被看见。
	for i in range(1, 4):
		draw_circle(Vector2(-8.0 * i, 0), radius * (0.72 - i * 0.14), Color(color.r, color.g, color.b, 0.42 - i * 0.09))
	if projectile_type == "chili":
		draw_colored_polygon(PackedVector2Array([Vector2(-22, 0), Vector2(-9, -8), Vector2(-7, 8)]), Color(1.0, 0.48, 0.12, 0.72))
	draw_circle(Vector2.ZERO, radius, color)
	draw_circle(Vector2(-3, -3), radius * 0.35, color.lightened(0.35))
