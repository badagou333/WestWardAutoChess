extends SceneTree
## D-20261110-004 mirror check in a real dedicated Godot Viewport.
## For every source index 0..97 render original and mirrored facing on a plain
## background (board/cell overlay hidden; review-only flag) and compare pixel
## (x, y) of the original with pixel (1439 - x, y) of the mirror, i.e. the
## reflection about the shared world foot x = 720. Also saves a few on-board
## samples of both facings. No OS input, no listening, no offline compositing.
const SIZE := Vector2i(1440, 810)
const MANIFEST_SHA := "fd1ae8323bae9bbc24cef60a68fa715ed5228474bb7e9d11dfd4b13617f98b98"
const SAVED_INDICES := [0, 31, 97]
const REGION := Rect2i(560, 260, 320, 240) # symmetric about x=720: 560..879
var output := ""
var scene
var errors: Array[String] = []
var results: Array[Dictionary] = []
var saved: Array[Dictionary] = []

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	call_deferred("run")

func require(ok: bool, message: String) -> bool:
	if not ok:
		errors.append(message)
		push_error(message)
	return ok

func render() -> Image:
	scene.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func save(picture: Image, name: String, meta: Dictionary) -> void:
	var path := output.path_join(name)
	if require(picture.save_png(path) == OK, "Could not save " + path):
		meta["file"] = name
		meta["sha256"] = FileAccess.get_sha256(path)
		saved.append(meta)

func compare(a: Image, b: Image) -> Dictionary:
	var max_diff := 0.0
	var differing := 0
	var nontrivial := 0
	var opaque_like := 0
	var background := Color("102323")
	for y in range(REGION.position.y, REGION.end.y):
		for x in range(REGION.position.x, REGION.end.x):
			var pa := a.get_pixel(x, y)
			var pb := b.get_pixel(SIZE.x - 1 - x, y)
			var d := maxf(maxf(absf(pa.r - pb.r), absf(pa.g - pb.g)), absf(pa.b - pb.b))
			if d > 0.0: differing += 1
			max_diff = maxf(max_diff, d)
			if not pa.is_equal_approx(b.get_pixel(x, y)): nontrivial += 1
			if not pa.is_equal_approx(background): opaque_like += 1
	return {"max_channel_diff":max_diff, "max_channel_diff_8bit":roundi(max_diff * 255.0),
		"pixels_not_bit_identical_to_reflection":differing,
		"pixels_differing_from_unreflected_mirror":nontrivial, "character_pixels_in_region":opaque_like}

func finish() -> void:
	var worst := 0
	var exact := 0
	for r in results:
		worst = maxi(worst, int(r.max_channel_diff_8bit))
		if int(r.pixels_not_bit_identical_to_reflection) == 0: exact += 1
	var complete := results.size() == 98
	require(complete, "All 98 source indices must be compared")
	var report := {"schema":"c03-mirror-symmetry-v1", "task":"D-20261110-004",
		"scope":"Real dedicated Viewport, plain background, original vs mirrored facing reflected about world foot x=720. Not human visual acceptance.",
		"display_server":DisplayServer.get_name(), "engine_version":Engine.get_version_info(),
		"rendering_driver":RenderingServer.get_current_rendering_driver_name(),
		"video_adapter":RenderingServer.get_video_adapter_name(),
		"viewport_size":[SIZE.x, SIZE.y], "compare_region":[REGION.position.x, REGION.position.y, REGION.size.x, REGION.size.y],
		"reflection":"original(x,y) vs mirrored(1439-x,y)", "os_input":false, "master_muted":true,
		"indices_compared":results.size(), "indices_bit_identical":exact, "worst_max_channel_diff_8bit":worst,
		"per_index":results, "saved_samples":saved, "errors":errors.duplicate(),
		"success":complete and errors.is_empty() and worst == 0}
	var file := FileAccess.open(output.path_join("mirror-symmetry.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t") + "\n")
		file.close()
	if is_instance_valid(scene):
		scene.sound_player.stop()
		scene.queue_free()
		await process_frame
	print("C3_MIRROR_SYMMETRY ", results.size(), " indices / ", exact, " bit-identical / worst ", worst, "/255 / ", errors.size(), " errors")
	quit(0 if file != null and report.success else 1)

func run() -> void:
	if not require(DisplayServer.get_name() != "headless", "Symmetry capture refuses headless"):
		quit(1)
		return
	if not require(output.is_absolute_path() and DirAccess.make_dir_recursive_absolute(output) == OK, "Absolute writable output directory required"):
		quit(1)
		return
	AudioServer.set_bus_mute(0, true)
	root.title = "D-20261110-004 C3 Mirror Symmetry (Muted)"
	root.size = SIZE
	scene = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	scene.set_process(false)
	if not require(scene.ready_to_play and FileAccess.get_sha256("res://art/c03/manifest.json") == MANIFEST_SHA, "Frozen assets must initialize"):
		await finish()
		return
	# On-board samples of both facings (actual Ended for 97).
	for index in SAVED_INDICES:
		for f in [1, -1]:
			scene.set_facing(f)
			if index == 97:
				scene.play_from_start()
				scene._process(scene.duration)
			else:
				scene.inspect_frame(index)
			var picture: Image = await render()
			var tag := "original" if f == 1 else "mirrored"
			require(not scene.sound_player.playing, "Samples remain silent")
			save(picture, "board-%s-index-%03d.png" % [tag, index], {"index":index, "facing":f, "state":scene.state,
				"world_foot":[scene.source_to_world(scene.foot_reference).x, scene.source_to_world(scene.foot_reference).y]})
	scene.review_plain_background = true
	for index in 98:
		scene.inspect_frame(index)
		scene.set_facing(1)
		var a: Image = await render()
		scene.set_facing(-1)
		var b: Image = await render()
		var r := compare(a, b)
		r["index"] = index
		r["source_pts_ticks"] = scene.frame_ticks[index]
		results.append(r)
		if index in SAVED_INDICES:
			save(a.get_region(REGION), "plain-original-index-%03d-region.png" % index, {"index":index, "facing":1})
			save(b.get_region(REGION), "plain-mirrored-index-%03d-region.png" % index, {"index":index, "facing":-1})
	await finish()
