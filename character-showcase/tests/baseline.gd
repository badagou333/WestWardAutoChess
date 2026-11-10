extends SceneTree
## D-20261110-005 merged-project behaviour fingerprint, same format as
## validation/20261110-merge/exporters/legacy_baseline.gd, produced through the
## real app scene (main.tscn -> open_character). Compare with tools/compare_fingerprints.py.
##   --character=bear|kingfisher|herb_boy --output=<abs.json> [--crops=<abs dir>]
## Must run in a real window (crop hashes). Muted, Dummy audio, no OS input.
const STEPS := [0.016667, 0.016667, 0.05, 0.006944, 0.1, 0.033333, 0.25]
const CROP := Rect2i(520, 200, 400, 360)
const LEGACY_KIND := {"bear":"bear", "kingfisher":"c03", "herb_boy":"b04"}
var kind := ""
var character := ""
var output := ""
var crop_dir := ""
var app
var scene

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--character="): character = arg.trim_prefix("--character=")
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--crops="): crop_dir = arg.trim_prefix("--crops=")
	kind = LEGACY_KIND.get(character, "")
	call_deferred("run")

func sha(bytes: PackedByteArray) -> String:
	var c := HashingContext.new()
	c.start(HashingContext.HASH_SHA256)
	c.update(bytes)
	return c.finish().hex_encode()

# ---- adapters over the shared player ----------------------------------------
func directions() -> Array:
	return scene.directions.map(func(d): return str(d.id))

func select(d: int) -> void:
	if scene.mode == "loop":
		scene.select_direction((d + 1) % scene.directions.size())
	scene.select_direction(d)

func period() -> float:
	return scene.period()

func frame_times() -> Array:
	return Array(scene.frame_times)

func canvas_size() -> Vector2:
	return scene.canvas

func foot_ref() -> Vector2:
	return scene.foot_reference

func state() -> String:
	return "loop" if scene.mode == "loop" else scene.state

func frame_now() -> int:
	return scene.current_frame_index()

# ---- fingerprint -------------------------------------------------------------
func timeline() -> Dictionary:
	var step := 0.001
	var span: float = period() * (2.0 if kind == "bear" else 1.0) + 0.2
	var count: int = int(span / step)
	var runs := []
	var last := -2
	for k in count:
		var i: int = scene.frame_at(k * step)
		if i != last:
			runs.append([k, i])
			last = i
	var edges := []
	for t in frame_times():
		for dt in [-0.0000001, 0.0, 0.0000001]:
			edges.append([t + dt, scene.frame_at(t + dt)])
	edges.append([scene.duration, scene.frame_at(scene.duration)])
	edges.append([scene.duration + 5.0, scene.frame_at(scene.duration + 5.0)])
	return {"step":step, "count":count, "runs":runs, "edges":edges}

func audio_row(i: int, previous) -> Array:
	var p = scene.sound_player.get_stream_playback() if scene.sound_player.playing else null
	var restarted: bool = p != null and p != previous
	var pos = p.get_playback_position() if restarted else null
	return [i, scene.elapsed, frame_now(), state(), scene.sound_player.playing, restarted, pos]

func audio_trace(d: int) -> Array:
	var rows := []
	AudioServer.lock()
	if kind == "bear":
		select(d)
	else:
		select(d)
		scene.play_from_start()
	var prev = null
	rows.append(audio_row(0, prev))
	prev = scene.sound_player.get_stream_playback() if scene.sound_player.playing else null
	var limit: float = period() * 2.5 if kind == "bear" else scene.duration + 0.3
	var i := 1
	var total := 0.0
	while total < limit:
		var dt: float = STEPS[(i - 1) % STEPS.size()]
		scene._process(dt)
		total += dt
		rows.append(audio_row(i, prev))
		if scene.sound_player.playing: prev = scene.sound_player.get_stream_playback()
		i += 1
	AudioServer.unlock()
	scene.sound_player.stop()
	return rows

func switch_trace() -> Array:
	var rows := []
	if kind == "b04": return rows
	AudioServer.lock()
	select(0)
	if kind != "bear": scene.play_from_start()
	for k in 4:
		scene._process(0.15)
	var prev = scene.sound_player.get_stream_playback() if scene.sound_player.playing else null
	rows.append(["before", scene.elapsed, frame_now(), state(), scene.sound_player.playing])
	scene.select_direction(2 if kind == "bear" else 1)
	var now = scene.sound_player.get_stream_playback() if scene.sound_player.playing else null
	rows.append(["after_switch", scene.elapsed, frame_now(), state(), scene.sound_player.playing, now != prev,
		now.get_playback_position() if now != null and now != prev else null])
	scene._process(0.2)
	rows.append(["after_step", scene.elapsed, frame_now(), state(), scene.sound_player.playing])
	AudioServer.unlock()
	scene.sound_player.stop()
	return rows

func crop_plan() -> Array:
	match kind:
		"bear":
			var out := []
			for k in 9: out.append({"time": period() * k / 9.0})
			return out
		"c03": return [0, 29, 30, 31, 32, 33, 34, 96, 97].map(func(x): return {"index":x})
		_: return [0, 30, 31, 33, 34, 35, 36, 37, 60, 82, 83].map(func(x): return {"index":x})

func crops(d: int, tag: String) -> Array:
	var out := []
	for item in crop_plan():
		select(d)
		var label := ""
		if kind == "bear":
			scene.elapsed = float(item.time)
			label = "t%.4f" % float(item.time)
		elif int(item.index) == scene.frames.size() - 1:
			scene.play_from_start()
			scene._process(scene.duration)
			label = "ended-%03d" % int(item.index)
		else:
			scene.inspect_frame(int(item.index))
			label = "index-%03d" % int(item.index)
		scene.sound_player.stop()
		scene.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var img: Image = root.get_texture().get_image().get_region(CROP)
		var h: String = sha(img.get_data())
		if crop_dir != "": img.save_png(crop_dir.path_join("%s-%s-%s.png" % [kind, tag, label]))
		out.append({"label":label, "frame":frame_now(), "sha256_rgba":h})
	return out

func run() -> void:
	AudioServer.set_bus_mute(0, true)
	root.size = Vector2i(1440, 810)
	app = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(app)
	await process_frame
	app.open_character(character)
	scene = app.player
	if scene == null or not scene.ready_to_play:
		push_error("character did not load: " + character)
		quit(1)
		return
	scene.set_process(false)
	if crop_dir != "": DirAccess.make_dir_recursive_absolute(crop_dir)
	var result := {"schema":"character-behaviour-fingerprint-v1", "source":"merged-" + character,
		"display_server":DisplayServer.get_name(), "engine":Engine.get_version_info().string, "directions":{}}
	var names := directions()
	for d in names.size():
		select(d)
		var tex := []
		for t in scene.frames: tex.append(sha(t.get_image().get_data()))
		var c := canvas_size()
		var f := foot_ref()
		var fm := []
		for p in [Vector2.ZERO, Vector2(c.x, 0), Vector2(0, c.y), c, f]:
			var w: Vector2 = scene.source_to_world(p)
			fm.append([w.x, w.y])
		var entry := {"frame_count":scene.frames.size(), "duration":scene.duration, "period":period(),
			"frame_times":frame_times(), "texture_sha256":tex, "foot_map":fm, "timeline":timeline(),
			"audio_trace":audio_trace(d)}
		entry["crops"] = await crops(d, names[d])
		result.directions[names[d]] = entry
	result["switch_trace"] = switch_trace()
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t", true, true) + "\n")
	file.close()
	scene.sound_player.stop()
	app.queue_free()
	await process_frame
	print("FINGERPRINT ", character, " ", names.size(), " directions")
	quit(0)
