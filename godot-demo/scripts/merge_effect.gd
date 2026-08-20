class_name MergeEffect
extends Node2D

var elapsed := 0.0

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()
	if elapsed >= 0.75:
		queue_free()

func _draw() -> void:
	var progress := elapsed / 0.75
	var alpha := 1.0 - progress
	draw_arc(Vector2.ZERO, 18 + progress * 58, 0, TAU, 40, Color(1.0, 0.89, 0.25, alpha), 5)
	for i in range(8):
		var angle := TAU * float(i) / 8.0 + elapsed * 2.0
		var point := Vector2.from_angle(angle) * (25 + progress * 42)
		draw_circle(point, 5 * alpha + 1, Color(1.0, 0.96, 0.55, alpha))

