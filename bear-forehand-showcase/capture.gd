extends SceneTree
var output := "/tmp/bear-showcase-render"
var scene

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	call_deferred("run")

func capture(index: int, at: float) -> bool:
	scene.elapsed = at
	scene.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	return picture.save_png(output.path_join("frame-%02d.png" % index))==OK

func run() -> void:
	if DisplayServer.get_name()=="headless" or DirAccess.make_dir_recursive_absolute(output)!=OK:
		push_error("A graphical window and writable output directory are required")
		quit(1)
		return
	root.size = Vector2i(1440,810)
	scene = load("res://showcase.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	if not scene.ready_to_play:
		push_error("Missing candidate frames")
		quit(1)
		return
	for i in scene.frame_times.size():
		if not await capture(i,scene.HOLD+scene.frame_times[i]+0.0001):
			push_error("Could not save frame %d" % i)
			quit(1)
			return
	print("BEAR_SHOWCASE_CAPTURE ",scene.frame_times.size()," frames in ",output)
	quit(0)
