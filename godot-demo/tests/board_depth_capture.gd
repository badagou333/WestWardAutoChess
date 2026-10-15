extends SceneTree
## Deterministic screenshots of actual production viewport; no image compositing.
var game
var output := "/tmp/board-depth-preview"
func _initialize() -> void: call_deferred("run")
func snap(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/"+name+".png")
func run() -> void:
	var video:=OS.get_cmdline_user_args().has("--video")
	if video: output="/tmp/board-depth-video"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output=argument.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(1440,810)
	game=load("res://scenes/board_trial.tscn").instantiate()
	root.add_child(game)
	game.audio_feedback.enabled=false
	game.set_process(false)
	for i in range(4): await process_frame
	if video:
		for i in range(300):
			if i==15: game.start_battle()
			if i>=15: game.step(1.0/15.0)
			else:
				for actor in game.actors: actor.node.tick_visual(1.0/15.0)
			game._update_ui()
			# The result remains part of the genuine running Demo footage.
			await snap("frame-%04d"%i)
		print("DEPTH_VIDEO_FRAMES_DONE ",output)
		quit()
		return
	await snap("formation")
	game.select("guard_monk")
	game._update_ui()
	await snap("selected")
	game.start_battle()
	for i in range(8):
		game.step(.5)
		game._update_ui()
		await snap("battle-%02d"%i)
	print("DEPTH_CAPTURE_DONE ",output)
	quit()
