extends SceneTree

func _init() -> void:
	call_deferred("_render")

func _render() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame

	# 构造一组便于检查布局的演示阵容。
	var demo_types := ["corn", "potato", "chili", "coffee"]
	for i in range(demo_types.size()):
		var unit = game.FoodUnitScene.new()
		unit.setup(demo_types[i], 2 if i == 0 else 1)
		unit.lane = i % 3
		unit.column = 1 + i
		game.add_child(unit)
		game.units.append(unit)
		game._move_unit_visual(unit)
	game.current_wave = 4
	for i in range(5):
		game.spawned_this_wave = i
		game.enemies_to_spawn = 8
		game._spawn_enemy()
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	if image == null:
		push_error("PREVIEW_FAILED: 当前显示驱动不支持读取画面")
		quit(1)
		return
	var error := image.save_png("res://preview.png")
	if error != OK:
		push_error("PREVIEW_FAILED: %s" % error_string(error))
		quit(1)
		return
	print("PREVIEW_OK: res://preview.png")
	quit(0)
