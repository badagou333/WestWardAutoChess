extends SceneTree
## Dedicated graphical Viewport samples. No source/board compositing or OS input.
const SIZE := Vector2i(1440, 810)
const INDICES := [0, 29, 30, 31, 32, 33, 34, 96, 97]
const MANIFEST_PATH := "res://art/c03/manifest.json"
const MANIFEST_SHA := "fd1ae8323bae9bbc24cef60a68fa715ed5228474bb7e9d11dfd4b13617f98b98"
const MARGIN := 12
var output := "/tmp/c03-single-render"
var scene
var manifest: Dictionary = {}
var errors: Array[String] = []
var samples: Array[Dictionary] = []
var png_count := 0
var facing := 1

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg == "--facing=mirrored": facing = -1
	call_deferred("run")

func require(ok: bool, message: String) -> bool:
	if not ok:
		errors.append(message)
		push_error(message)
	return ok

func xy(point: Vector2) -> Array:
	return [point.x, point.y]

func save_png(picture: Image, filename: String) -> String:
	var path := output.path_join(filename)
	if not require(picture.save_png(path) == OK, "Could not save actual Viewport image: " + path): return ""
	png_count += 1
	var digest := FileAccess.get_sha256(path)
	if not require(digest.length() == 64, "Could not hash saved Viewport image"): return ""
	return digest

func sample_current(index: int, expected_state: String) -> Dictionary:
	scene.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	if not require(scene.current_frame_index() == index and scene.state == expected_state,
		"Source index or state differs from requested real render sample " + str(index)): return {}
	if not require(not scene.sound_player.playing, "Ready/inspection/Ended samples must remain silent"): return {}
	var item: Dictionary = manifest.frames[index]
	var source_path := MANIFEST_PATH.get_base_dir().path_join(str(item.file))
	var source_sha := FileAccess.get_sha256(source_path)
	if not require(source_sha == str(item.sha256), "Runtime source PNG differs from the frozen manifest"): return {}
	var actual_foot: Vector2 = scene.source_to_world(scene.foot_reference)
	if not require(actual_foot.is_equal_approx(Vector2(720, 441)), "World foot moved during sampling"): return {}
	var picture: Image = root.get_texture().get_image()
	if not require(picture != null and picture.get_size() == SIZE, "A real 1440x810 Viewport is required"): return {}
	var a: Vector2 = scene.source_to_world(Vector2.ZERO)
	var b: Vector2 = scene.source_to_world(scene.canvas)
	var crop_rect := Rect2i(floori(minf(a.x, b.x)) - MARGIN, floori(minf(a.y, b.y)) - MARGIN,
		ceili(maxf(a.x, b.x)) - floori(minf(a.x, b.x)) + MARGIN * 2,
		ceili(maxf(a.y, b.y)) - floori(minf(a.y, b.y)) + MARGIN * 2)
	if not require(Rect2i(Vector2i.ZERO, SIZE).encloses(crop_rect), "Full transformed canvas crop must remain in the actual Viewport"): return {}
	# The crop contains original pixels from this exact real Viewport image.
	var crop: Image = picture.get_region(crop_rect)
	var filename := "%s-index-%03d.png" % [expected_state, index]
	var crop_filename := "%s-index-%03d-character.png" % [expected_state, index]
	var screenshot_sha := save_png(picture, filename)
	var crop_sha := save_png(crop, crop_filename)
	if screenshot_sha.is_empty() or crop_sha.is_empty(): return {}
	return {"frame_index":index, "index_base":0, "state":scene.state,
		"elapsed_seconds":scene.elapsed, "source_pts_ticks":item.pts_ticks,
		"source_duration_ticks":item.source_duration_ticks, "time_base":manifest.time_base,
		"source_file":item.file, "source_manifest_frame":item.duplicate(true),
		"source_png_sha256":source_sha, "declared_source_png_sha256":item.sha256,
		"manifest_path":MANIFEST_PATH, "manifest_sha256":MANIFEST_SHA,
		"canvas":xy(scene.canvas), "foot_reference":xy(scene.foot_reference),
		"world_foot":xy(actual_foot), "display_scale":scene.display_scale,
		"canvas_world_corners":[xy(a),xy(b)], "mirrored":scene.facing == -1, "facing":scene.facing,
		"file":filename, "sha256":screenshot_sha, "viewport_size":[SIZE.x,SIZE.y],
		"character_file":crop_filename, "character_sha256":crop_sha,
		"character_viewport_rect":[crop_rect.position.x,crop_rect.position.y,crop_rect.size.x,crop_rect.size.y],
		"world_foot_in_character_crop":xy(actual_foot - Vector2(crop_rect.position)),
		"audio_event_handled":scene.audio_event_handled, "audio_playing":scene.sound_player.playing}

func finish() -> void:
	var complete: bool = samples.size() == INDICES.size() and png_count == INDICES.size() * 2
	require(complete, "Capture must contain all nine source samples and eighteen PNGs")
	var report := {"schema":"c03-single-author-graphical-capture-v1", "task":"D-20261101-002",
		"scope":"Real dedicated Godot Viewport; Ready/paused inspection and actual Ended state. Not normal continuous playback or listening acceptance.",
		"facing":facing, "display_server":DisplayServer.get_name(), "engine_version":Engine.get_version_info(),
		"window_title":root.title, "viewport_size":[SIZE.x,SIZE.y], "audio_driver":AudioServer.get_driver_name(),
		"master_muted":true, "os_input":false, "device_listening":false,
		"crop_method":"Image.get_region of the same actual Viewport screenshot; no offline compositing",
		"expected_indices":INDICES, "index_base":0, "sample_count":samples.size(),
		"saved_png_count":png_count, "samples":samples, "success":complete and errors.is_empty(), "errors":errors.duplicate()}
	var file := FileAccess.open(output.path_join("capture.json"), FileAccess.WRITE)
	var written: bool = file != null
	if written:
		file.store_string(JSON.stringify(report, "\t") + "\n")
		file.flush()
		written = file.get_error() == OK
		file.close()
	if is_instance_valid(scene):
		if is_instance_valid(scene.sound_player): scene.sound_player.stop()
		scene.queue_free()
		await process_frame
	if not written: push_error("Could not write complete capture report")
	print("C3_SINGLE_CAPTURE ", samples.size(), " samples / ", png_count, " PNGs / ", errors.size(), " errors")
	quit(0 if written and complete and errors.is_empty() else 1)

func run() -> void:
	if not require(DisplayServer.get_name() != "headless", "Graphical capture refuses headless execution"):
		quit(1)
		return
	if not require(output.is_absolute_path() and DirAccess.make_dir_recursive_absolute(output) == OK, "A writable absolute output directory is required"):
		quit(1)
		return
	AudioServer.set_bus_mute(0, true)
	root.title = "D-20261101-002 C3 Single Capture (Muted)"
	root.size = SIZE
	var packed = load("res://main.tscn")
	if not require(packed is PackedScene, "Standalone C3 scene must load"):
		await finish()
		return
	scene = packed.instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene.set_facing(facing)
	if not require(scene.ready_to_play and scene.state == "ready" and scene.facing == facing, "Standalone source assets must initialize in silent Ready"):
		await finish()
		return
	var raw = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if not require(raw is Dictionary and FileAccess.get_sha256(MANIFEST_PATH) == MANIFEST_SHA, "Frozen C3 manifest must match"):
		await finish()
		return
	manifest = raw
	for index in INDICES:
		var expected_state := "inspection"
		if index == 0:
			expected_state = "ready"
		elif index == 97:
			# Exercise the actual terminal state, not an inspection labelled Ended.
			scene.play_from_start()
			scene._process(scene.duration)
			expected_state = "ended"
		else:
			scene.inspect_frame(index)
		var sample := await sample_current(index, expected_state)
		if sample.is_empty(): break
		samples.append(sample)
	await finish()
