extends SceneTree

func _init() -> void:
	call_deferred("_render")

func _render() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame

	var demo_types := ["guard_monk", "wild_hunter", "herbal_spirit_child"]
	var demo_cells := [Vector2i(2, 2), Vector2i(1, 3), Vector2i(3, 3)]
	for i in range(demo_types.size()):
		var hero = game.HeroScene.new()
		hero.setup(demo_types[i], 2 if i == 0 else 1)
		hero.board_row = demo_cells[i].x
		hero.board_col = demo_cells[i].y
		hero.bench_slot = -1
		hero.position = game._cell_center(demo_cells[i])
		hero.set_bench_mode(false)
		game.add_child(hero)
		game.heroes.append(hero)
		hero.begin_battle()
	game.state = game.GameState.BATTLE_RUNNING
	game.wave_index = 3
	game.intermission = 0.0
	game.pending_loot = 13
	game._spawn_enemy("bear_lord", Vector2i(0, 3))
	game._spawn_enemy("wolf", Vector2i(1, 1))
	game._spawn_enemy("boar", Vector2i(3, 5))
	game.battle_paused = true
	game._update_ui()
	game.queue_redraw()
	for i in range(10):
		await process_frame
	var image := root.get_texture().get_image()
	if image == null:
		push_error("PREVIEW_FAILED: 当前显示驱动不支持读取画面")
		quit(1)
		return
	var output := OS.get_environment("DEMO_PREVIEW_PATH")
	if output.is_empty(): output = "user://demo-preview.png"
	var error := image.save_png(output)
	if error != OK:
		push_error("PREVIEW_FAILED: %s" % error_string(error))
		quit(1)
		return
	print("PREVIEW_OK: ", output)
	quit(0)
