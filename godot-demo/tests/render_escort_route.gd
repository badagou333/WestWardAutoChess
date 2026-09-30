extends SceneTree

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var game = load("res://scenes/escort_route.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	for index in range(3): game._on_shop_pressed(index)
	var cells := [Vector2i(7,1),Vector2i(9,1),Vector2i(9,2)]
	for i in range(3): game._place_hero_on_board(game.heroes[i],cells[i])
	game._start_battle()
	game.step(3.2)
	game._select_hero(game.heroes[0])
	game._command_move(game.heroes[0],Vector2i(5,2))
	game._update_ui()
	game.queue_redraw()
	for i in range(8): await process_frame
	var output := OS.get_environment("DEMO_PREVIEW_PATH")
	if output.is_empty(): output = "/tmp/escort-route-preview.png"
	var error := root.get_texture().get_image().save_png(output)
	print("ESCORT_PREVIEW: ",output," error=",error)
	game.free()
	quit(error)
