extends SceneTree

func _init() -> void:
	call_deferred("run")

func save_frame(file: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	if picture == null or picture.is_empty():
		push_error("Cannot capture render"); quit(1); return
	picture.save_png("res://art/reviews/six-role-battle/" + file)

func run() -> void:
	var scene = load("res://art/reviews/six-role-battle/battle.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	await save_frame("board-start.png")
	for i in 370: scene.step(1.0 / 60)
	await save_frame("board-combat.png")
	scene.retreat_check()
	for i in 34: scene.step(1.0 / 60)
	await save_frame("board-retreat.png")
	print("SIX_ROLE_RENDER_OK: three engine screenshots")
	quit()
