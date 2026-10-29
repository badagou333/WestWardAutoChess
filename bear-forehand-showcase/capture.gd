extends SceneTree
var output := "/tmp/bear-four-direction-render"
var all_frames := false
var scene

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg=="--all-frames": all_frames = true
	call_deferred("run")

func capture(path: String, at: float) -> bool:
	scene.elapsed = at
	scene.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image().save_png(path)==OK

func run() -> void:
	if DisplayServer.get_name()=="headless" or DirAccess.make_dir_recursive_absolute(output)!=OK:
		push_error("A graphical window and writable output directory are required")
		quit(1)
		return
	AudioServer.set_bus_mute(0,true)
	root.size = Vector2i(1440,810)
	scene = load("res://showcase.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	await process_frame
	if not scene.ready_to_play:
		push_error("Missing directional frames")
		quit(1)
		return
	var report := {"kind":"Godot graphical viewport samples; source animation paused at recorded times","samples":[]}
	for direction in range(4):
		# Use button Control input rather than assigning direction_index.
		var location: Vector2 = scene.direction_buttons[direction].get_global_rect().get_center()
		for pressed in [true,false]:
			var event := InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = pressed
			event.position = location
			Input.parse_input_event(event)
		await process_frame
		if scene.direction_index!=direction:
			push_error("Button input did not change direction")
			quit(1)
			return
		var times: Array[float] = []
		if all_frames: times.assign(scene.frame_times)
		else:
			times.assign([0.0,scene.duration*0.35,scene.duration*0.55,scene.duration-0.001])
		for i in times.size():
			var filename: String = "%s-%03d.png" % [scene.DIRECTIONS[direction].id,i]
			if not await capture(output.path_join(filename),times[i]+0.000001):
				push_error("Could not save capture")
				quit(1)
				return
			report.samples.append({"direction":scene.DIRECTIONS[direction].id,"time":times[i],"frame":scene.frame_at(times[i]+0.000001),"file":filename})
	var file := FileAccess.open(output.path_join("capture.json"),FileAccess.WRITE)
	if file!=null: file.store_string(JSON.stringify(report,"\t"))
	scene.sound_player.stop()
	scene.queue_free()
	await process_frame
	print("BEAR_FOUR_DIRECTION_CAPTURE ",report.samples.size()," samples in ",output)
	quit(0)
