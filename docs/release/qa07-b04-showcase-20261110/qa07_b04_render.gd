extends SceneTree
## 07 independent real-Viewport probe for the B4 showcase (D-20261110-004).
## Args: --output=<dir> --mip=on|off. "off" rewrites res://showcase.json in a
## SCRATCH cold copy (mipmaps:false) and restores the original bytes at the end.
## Checks: Ready index 0, inspection 35 (light ball at the right canvas edge),
## real Ended 83 reached by the play path == inspection 83 pixels; pixels outside
## the expected canvas world rect never change between frames (placement);
## rough texture/static memory. No OS input, no listening, no visual verdict.
var output := ""
var mip := "on"
var scene
var checks := 0
var failures: Array[String] = []
var rep := {}

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--output="): output = a.trim_prefix("--output=")
		if a.begins_with("--mip="): mip = a.trim_prefix("--mip=")
	call_deferred("run")

func check(ok: bool, msg: String) -> void:
	checks += 1
	if not ok:
		failures.append(msg)
		push_error("QA07 FAIL: " + msg)

func shot() -> Image:
	scene.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img

func outside_diff(a: Image, b: Image, rect: Rect2i) -> Array:
	var da := a.get_data()
	var db := b.get_data()
	var outside := 0
	var inside := 0
	for y in range(140, 810):
		for x in 1440:
			var i := (y * 1440 + x) * 4
			if da[i] != db[i] or da[i + 1] != db[i + 1] or da[i + 2] != db[i + 2]:
				if rect.has_point(Vector2i(x, y)): inside += 1
				else: outside += 1
	return [outside, inside]

func run() -> void:
	var original := FileAccess.get_file_as_bytes("res://showcase.json")
	if mip == "off":
		var cfg: Dictionary = JSON.parse_string(original.get_string_from_utf8())
		cfg.presentation.mipmaps = false
		var f := FileAccess.open("res://showcase.json", FileAccess.WRITE)
		f.store_string(JSON.stringify(cfg, "  "))
		f.close()
	await process_frame
	var tex0 := Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)
	var mem0 := OS.get_static_memory_usage()
	scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	scene.set_process(false)
	check(scene.ready_to_play, "ready")
	check(scene.use_mipmaps == (mip == "on"), "mipmap config = " + mip)
	rep["renderer"] = RenderingServer.get_video_adapter_name() + " / " + RenderingServer.get_current_rendering_driver_name()
	var a0: Image = await shot()
	rep["texture_mem_mb"] = (Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) - tex0) / 1048576.0
	rep["static_mem_delta_mb"] = (OS.get_static_memory_usage() - mem0) / 1048576.0
	rep["static_mem_total_mb"] = OS.get_static_memory_usage() / 1048576.0
	rep["process_peak_static_mb"] = OS.get_static_memory_peak_usage() / 1048576.0
	# expected canvas world rect (with 2 px margin for filtering)
	var tl: Vector2 = scene.source_to_world(Vector2.ZERO)
	var br: Vector2 = scene.source_to_world(scene.canvas)
	var rect := Rect2i(Vector2i(floori(tl.x) - 2, floori(tl.y) - 2), Vector2i(ceili(br.x - tl.x) + 5, ceili(br.y - tl.y) + 5))
	rep["canvas_rect_checked"] = [rect.position.x, rect.position.y, rect.end.x, rect.end.y]
	check(scene.state == scene.READY and scene.current_frame_index() == 0, "Ready shows index 0")
	scene.inspect_frame(35)
	var a35: Image = await shot()
	var d35 := outside_diff(a0, a35, rect)
	rep["idx0_vs_35_outside_inside"] = d35
	check(d35[0] == 0 and d35[1] > 100, "0->35 changes only inside canvas rect (%s)" % str(d35))
	# real Ended 83 through the play path
	scene.play_button.pressed.emit()
	var steps := 0
	while scene.state == scene.PLAYING:
		scene._process(1.0 / 60.0)
		steps += 1
	check(scene.state == scene.ENDED and scene.current_frame_index() == 83 and not scene.sound_player.playing, "play path reached ENDED 83 silent")
	var e83: Image = await shot()
	scene.inspect_frame(83)
	var i83: Image = await shot()
	var d83 := outside_diff(e83, i83, Rect2i(0, 0, 0, 0))
	check(d83[0] == 0, "Ended 83 stage == inspection 83 stage (%d px)" % d83[0])
	var d0_83 := outside_diff(a0, e83, rect)
	check(d0_83[0] == 0, "0->Ended83 changes only inside canvas rect (%s)" % str(d0_83))
	# light ball at the right canvas edge: source alpha on last column, frame 35
	var src35: Image = scene.frames[35].get_image()
	if src35.has_mipmaps(): src35.clear_mipmaps()
	src35.decompress()
	var edge := 0
	for y in src35.get_height():
		if src35.get_pixel(src35.get_width() - 1, y).a > 0.0: edge += 1
	rep["frame35_alpha_px_on_right_canvas_column"] = edge
	# where does the canvas right edge land on screen
	rep["canvas_right_edge_world_x"] = br.x
	if output != "":
		DirAccess.make_dir_recursive_absolute(output)
		var crop := Rect2i(640, 300, 200, 180)
		a35.get_region(crop).save_png(output.path_join("mip-%s-index035-crop.png" % mip))
		e83.get_region(crop).save_png(output.path_join("mip-%s-ended083-crop.png" % mip))
	rep["checks"] = checks
	rep["failures"] = failures
	if mip == "off":
		var fr := FileAccess.open("res://showcase.json", FileAccess.WRITE)
		fr.store_buffer(original)
		fr.close()
		check(FileAccess.get_file_as_bytes("res://showcase.json") == original, "config restored")
	if output != "":
		var fo := FileAccess.open(output.path_join("render-mip-%s.json" % mip), FileAccess.WRITE)
		fo.store_string(JSON.stringify(rep, "  "))
		fo.close()
	print("QA07_B04_RENDER mip=%s %d checks / %d failures | %s" % [mip, checks, failures.size(), JSON.stringify(rep)])
	for f in failures: print("  FAIL ", f)
	quit(0 if failures.is_empty() else 1)
