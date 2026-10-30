extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.set_process(false)
	game.audio_feedback.enabled = false
	for i in [0,1,2]: game._on_shop_pressed(i)
	var cells = [Vector2i(2,2),Vector2i(1,3),Vector2i(3,3)]
	for i in range(3): game._place_hero_on_board(game.heroes[i],cells[i])
	game._start_battle()
	for tick in range(120*120):
		game.step(1.0/120)
		if game.state!=game.GameState.BATTLE_RUNNING: break
	if game.state!=game.GameState.PREPARING:
		push_error("Could not reach wave preparation")
		quit(1)
		return
	game.step(1.0)
	game._update_ui()
	for i in range(6): await process_frame
	var output := OS.get_environment("WAVE_PREVIEW_PATH")
	if output.is_empty(): output="user://wave-preparation.png"
	var error := root.get_texture().get_image().save_png(output)
	print("WAVE_PREVIEW: ",output," status=",error)
	quit(0 if error==OK else 1)
