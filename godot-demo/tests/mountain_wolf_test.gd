extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var enemy = preload("res://scripts/enemy.gd").new()
	root.add_child(enemy)
	enemy.setup("wolf")
	var visual = enemy.presentation
	assert(visual.role == "mountain_wolf")
	assert(not enemy.portrait.visible)
	for direction in [-1.0, 1.0]:
		visual.face(Vector2(direction * 200, 0))
		# The nose lies left of the source anchor; it must face the target.
		var nose = visual.visual_transform() * Vector2(-65, -65)
		assert(signf(nose.x) == direction)
		visual.play_attack()
		visual.tick(visual.impact_delay())
		assert(visual.frame_index == 2)
		assert(signf(visual.ground_offset().x) == direction)
		visual.reset_visual()
	visual.move_to(Vector2.ZERO)
	visual.tick(0.1)
	assert(visual.frame_index == 1)
	visual.reset_visual()
	enemy.take_damage(1)
	assert(visual.frame_index == 3)
	enemy.take_damage(1000)
	enemy.play_death()
	visual.tick(0.71)
	assert(visual.frame_index == 4 and visual.visual_alpha == 0)
	enemy.free()
	print("MOUNTAIN_WOLF_OK: facing, attack, move, hit and retreat")
	quit()
