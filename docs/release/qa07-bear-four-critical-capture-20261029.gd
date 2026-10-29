extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	root.size=Vector2i(1440,810)
	var scene=load("res://showcase.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	await process_frame
	if not scene.ready_to_play: quit(1); return
	for direction in [2,3]:
		var p:Vector2=scene.direction_buttons[direction].get_global_rect().get_center()
		for down in [true,false]:
			var event=InputEventMouseButton.new()
			event.button_index=MOUSE_BUTTON_LEFT
			event.position=p
			event.pressed=down
			Input.parse_input_event(event)
		await process_frame
		if scene.direction_index!=direction: quit(2); return
		scene.sound_player.stop()
		scene.elapsed=1.625
		scene.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var path="/private/tmp/qa07-bear-back-%d-at-1.625.png" % direction
		var error=root.get_texture().get_image().save_png(path)
		print("QA07_CRITICAL_CAPTURE ",direction," frame=",scene.frame_at(1.625)+1," path=",path," error=",error)
		if error!=OK: quit(3); return
	scene.queue_free()
	await process_frame
	quit(0)
