extends SceneTree

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://art/reviews/six-role-battle/battle.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	var output := "res://art/reviews/six-role-battle/.capture"
	DirAccess.make_dir_recursive_absolute(output)
	for index in 192:
		for tick in 5: scene.step(1.0 / 120)
		await process_frame
		await RenderingServer.frame_post_draw
		var picture := root.get_texture().get_image()
		if picture == null or picture.is_empty():
			push_error("Cannot render motion preview"); quit(1); return
		# Actual engine render, focused on the combatants; run at 1440x810.
		picture.get_region(Rect2i(620, 220, 590, 365)).save_png(output + "/%03d.png" % index)
	print("MOTION_RENDER_OK: 192 frames / 8 seconds / 24 fps")
	quit()
