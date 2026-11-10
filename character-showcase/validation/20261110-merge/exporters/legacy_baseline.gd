extends SceneTree
## D-20261110-005 pre-merge behaviour fingerprint. Runs inside a copy of one of
## the three OLD standalone projects (commit d19a97f) without modifying it:
##   --kind=bear|c03|b04 --output=<abs.json> [--crops=<abs dir>]
## Must run in a real window (crop hashes). Muted, Dummy audio, no OS input.
## The merged project produces the same format with tests/baseline.gd.
const STEPS := [0.016667, 0.016667, 0.05, 0.006944, 0.1, 0.033333, 0.25]
const CROP := Rect2i(520, 200, 400, 360)
var kind := ""
var output := ""
var crop_dir := ""
var scene

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--kind="): kind = arg.trim_prefix("--kind=")
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--crops="): crop_dir = arg.trim_prefix("--crops=")
	call_deferred("run")

func sha(bytes: PackedByteArray) -> String:
	var c := HashingContext.new()
	c.start(HashingContext.HASH_SHA256)
	c.update(bytes)
	return c.finish().hex_encode()

# ---- adapters over the three old APIs --------------------------------------
func directions() -> Array:
	match kind:
		"bear": return ["front_right", "front_left", "back_right", "back_left"]
		"c03": return ["original", "mirrored"]
		_: return ["original"]

func select(d: int) -> void:
	if kind == "bear":
		# Old select_direction ignores the current index: force a real switch.
		scene.select_direction((d + 1) % 4)
		scene.select_direction(d)
	elif kind == "c03":
		scene.set_facing(1 if d == 0 else -1)

func period() -> float:
	return scene.duration + scene.loop_interval if kind == "bear" else scene.duration

func frame_times() -> Array:
	if kind == "bear": return scene.frame_times.duplicate()
	var tb := 90000.0 if kind == "c03" else 15360.0
	var out := []
	for t in scene.frame_ticks: out.append(float(t) / tb)
	return out

func canvas_size() -> Vector2:
	return scene.canvas

func foot_ref() -> Vector2:
	return scene.frame_foot if kind == "bear" else scene.foot_reference

func state() -> String:
	return "loop" if kind == "bear" else scene.state

func frame_now() -> int:
	return scene.frame_at(scene.elapsed) if kind == "bear" else scene.current_frame_index()

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
	if kind == "bear": scene.select_direction(2)
	else: scene.set_facing(-1)
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
	var packed: PackedScene = load("res://showcase.tscn" if kind == "bear" else "res://main.tscn")
	scene = packed.instantiate()
	root.add_child(scene)
	scene.set_process(false)
	if crop_dir != "": DirAccess.make_dir_recursive_absolute(crop_dir)
	var result := {"schema":"character-behaviour-fingerprint-v1", "source":"legacy-" + kind,
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
	scene.queue_free()
	await process_frame
	print("FINGERPRINT ", kind, " ", names.size(), " directions")
	quit(0)
