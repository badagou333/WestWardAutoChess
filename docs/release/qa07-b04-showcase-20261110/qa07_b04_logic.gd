extends SceneTree
## 07 independent logic probe for the B4 herb boy single showcase (D-20261110-004).
## Deterministic manual _process stepping on the production scene. Dummy audio:
## engine playback objects only, no device listening; no OS input.
## Also rewrites res://showcase.json in a SCRATCH cold copy to test the
## configurable presentation, then restores the original bytes.
const TB := 15360.0
var checks := 0
var failures: Array[String] = []
var scene
var notes := {}

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, msg: String) -> void:
	checks += 1
	if not ok:
		failures.append(msg)
		push_error("QA07 FAIL: " + msg)

## Native WAV start() pre-fills the resampler (observed 128 samples); compare
## against an independent playback of the same stream started at phase 0.
func ref_start_pos() -> float:
	var r: AudioStreamPlayback = scene.sound_player.stream.instantiate_playback()
	r.start(0.0)
	var p := r.get_playback_position()
	r.stop()
	return p

func make_scene():
	var s = load("res://main.tscn").instantiate()
	root.add_child(s)
	s.set_process(false)
	return s

func drop_scene(s) -> void:
	root.remove_child(s)
	s.free()

func run() -> void:
	scene = make_scene()
	await process_frame
	check(scene.ready_to_play, "ready (" + str(scene.load_error) + ")")
	if not scene.ready_to_play:
		finish(); return
	# ---- manifest PTS table read independently ----
	var man: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/b04/manifest.json"))
	var pts: Array[int] = []
	for f in man.frames: pts.append(int(f.pts))
	check(pts.size() == 84 and scene.frame_ticks == pts, "scene uses manifest PTS for 84 frames")
	var holds := {}
	for i in 84:
		var nxt := 53760 if i == 83 else pts[i + 1]
		holds[nxt - pts[i]] = int(holds.get(nxt - pts[i], 0)) + 1
	check(holds == {768: 42, 512: 42}, "holds 42x768 + 42x512 (%s)" % str(holds))
	check(is_equal_approx(scene.duration, 3.5), "T = 3.5 s")
	# boundary exactness: at PTS -> i, just before -> i-1
	var bound_ok := true
	for i in 84:
		var t := float(pts[i]) / TB
		if scene.frame_at(t) != i: bound_ok = false
		if i > 0 and scene.frame_at(t - 1e-6) != i - 1: bound_ok = false
		if i > 0 and scene.frame_at((float(pts[i - 1]) + float(pts[i])) * 0.5 / TB) != i - 1: bound_ok = false
	check(bound_ok, "every PTS boundary exact (at, 1us before, mid-hold)")
	check(scene.frame_at(3.5) == 83 and scene.frame_at(99.0) == 83, "t>=T -> 83")
	# not a fixed-FPS lookup
	var fixed_diff := 0
	for k in 3500:
		var t := k / 1000.0
		if scene.frame_at(t) != mini(int(floor(t * 24.0)), 83): fixed_diff += 1
	notes["ms_samples_differing_from_fixed_24fps"] = fixed_diff
	check(fixed_diff > 100, "differs from fixed 24 FPS lookup (%d/3500 ms samples)" % fixed_diff)

	# ---- full play: offset 0, PTS lookup each step, end at 83 silent ----
	scene.play_button.pressed.emit()
	check(scene.state == scene.PLAYING and scene.elapsed == 0.0, "play via button signal starts at 0")
	check(scene.current_frame_index() == 0, "frame 0 at press")
	check(scene.sound_player.playing, "WAV starts together with frame 0 (offset 0)")
	var pb0 = scene.sound_player.get_stream_playback()
	check(pb0 != null and absf(pb0.get_playback_position() - ref_start_pos()) < 1.0 / 44100.0, "WAV start position == independent same-WAV reference started at 0 (%s vs %s)" % [str(pb0.get_playback_position() if pb0 else -1), str(ref_start_pos())])
	var seen := {}
	var ok_idx := true
	var mono := true
	var prev := 0
	var single_pb := true
	while scene.state == scene.PLAYING:
		scene._process(1.0 / 1000.0)
		var ci: int = scene.current_frame_index()
		seen[ci] = true
		if ci != scene.frame_at(scene.elapsed): ok_idx = false
		var exp := 83
		if scene.elapsed < 3.5:
			exp = 0
			for i in 84:
				if float(pts[i]) / TB <= scene.elapsed: exp = i
		if ci != exp: ok_idx = false
		if ci < prev: mono = false
		prev = ci
		if scene.state == scene.PLAYING and (not scene.sound_player.playing or scene.sound_player.get_stream_playback() != pb0): single_pb = false
	check(ok_idx, "1 ms steps: index == independent PTS lookup")
	check(mono, "index monotonic")
	check(seen.size() == 84, "all 84 frames visited at 1 ms steps (%d)" % seen.size())
	check(single_pb, "one WAV playback object, playing throughout 0..T")
	check(scene.state == scene.ENDED and scene.current_frame_index() == 83 and not scene.sound_player.playing, "T: ENDED, index 83, silent")
	check(is_equal_approx(scene.elapsed, 3.5), "elapsed clamped to T")
	for k in 120: scene._process(1.0 / 60.0)
	check(scene.state == scene.ENDED and scene.current_frame_index() == 83 and not scene.sound_player.playing, "stays ENDED 2 s, no loop")
	check(scene.play_button.disabled and not scene.replay_button.disabled, "ended: play disabled / replay enabled")
	# ---- replay after end ----
	scene.replay_button.pressed.emit()
	var pb1 = scene.sound_player.get_stream_playback()
	check(scene.state == scene.PLAYING and scene.elapsed == 0.0 and scene.sound_player.playing and pb1 != pb0, "replay after end restarts from 0 with new playback")
	for k in 60: scene._process(1.0 / 60.0)
	# ---- replay while sound active ----
	var pos_before: float = pb1.get_playback_position()
	scene.play_from_start()
	var pb2 = scene.sound_player.get_stream_playback()
	check(pb2 != pb1 and scene.sound_player.playing and scene.elapsed == 0.0, "active replay: old playback replaced, restart at 0")
	check(absf(pb2.get_playback_position() - ref_start_pos()) < 1.0 / 44100.0, "active replay WAV position == reference start at 0 (before %f)" % pos_before)
	check(not scene.sound_player.stream.instantiate_playback() == pb1, "sanity")
	# ---- large stall across T ----
	scene._process(10.0)
	check(scene.state == scene.ENDED and scene.current_frame_index() == 83 and not scene.sound_player.playing, "10 s stall -> ENDED 83 silent")
	# ---- inspection silent ----
	scene.play_from_start()
	scene._process(0.5)
	scene.inspect_frame(35)
	check(scene.state == scene.INSPECTION and scene.current_frame_index() == 35 and not scene.sound_player.playing, "inspection 35 silent")
	for k in 30: scene._process(1.0 / 60.0)
	check(not scene.sound_player.playing and scene.current_frame_index() == 35, "inspection stays silent/still")
	scene.inspect_frame(84)
	scene.inspect_frame(-1)
	check(scene.current_frame_index() == 35, "out-of-range inspection ignored")
	# ---- geometry ----
	check(scene.source_to_world(scene.foot_reference).is_equal_approx(Vector2(720, 441)), "foot -> (720,441)")
	check(is_equal_approx(scene.display_scale, 0.16) and scene.use_mipmaps, "default config scale 0.16 / mipmaps on")
	check(scene.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, "mipmap filter on")
	check(scene.frames[0].get_image().has_mipmaps(), "textures carry mipmaps")
	var tl: Vector2 = scene.source_to_world(Vector2.ZERO)
	var br: Vector2 = scene.source_to_world(scene.canvas)
	notes["canvas_world_rect"] = [tl.x, tl.y, br.x, br.y]
	check(tl.is_equal_approx(Vector2(671.52, 331.56)) and br.is_equal_approx(Vector2(809.76, 453.16)), "canvas world rect")
	# ---- exit clears sound ----
	scene.play_from_start()
	scene._process(0.3)
	var player: AudioStreamPlayer = scene.sound_player
	check(player.playing, "pre-exit playing")
	root.remove_child(scene)
	check(not player.playing, "exit_tree stops WAV")
	scene.free()
	await process_frame

	# ---- configurable presentation (scratch copy only) ----
	var original := FileAccess.get_file_as_bytes("res://showcase.json")
	var cfg: Dictionary = JSON.parse_string(original.get_string_from_utf8())
	var variants := [
		{"name": "scale0.25_foot600,400_mip_off", "scale": 0.25, "foot": [600, 400], "mip": false, "ok": true},
		{"name": "scale0.16_mip_off", "scale": 0.16, "foot": [720, 441], "mip": false, "ok": true},
		{"name": "scale0_invalid", "scale": 0.0, "foot": [720, 441], "mip": true, "ok": false},
		{"name": "scale1.5_invalid", "scale": 1.5, "foot": [720, 441], "mip": true, "ok": false},
	]
	for v in variants:
		var c := cfg.duplicate(true)
		c.presentation.display_scale = v.scale
		c.presentation.world_foot = v.foot
		c.presentation.mipmaps = v.mip
		var fw := FileAccess.open("res://showcase.json", FileAccess.WRITE)
		fw.store_string(JSON.stringify(c, "  "))
		fw.close()
		var s = make_scene()
		await process_frame
		if v.ok:
			check(s.ready_to_play, v.name + ": ready")
			check(is_equal_approx(s.display_scale, v.scale) and s.use_mipmaps == v.mip, v.name + ": config applied")
			check(s.source_to_world(s.foot_reference).is_equal_approx(Vector2(v.foot[0], v.foot[1])), v.name + ": foot follows config")
			check(s.source_to_world(s.foot_reference + Vector2(100, 0)).is_equal_approx(Vector2(v.foot[0] + 100.0 * v.scale, v.foot[1])), v.name + ": scale applied")
			check(s.frames[0].get_image().has_mipmaps() == v.mip, v.name + ": texture mipmaps match")
			check((s.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS) == v.mip, v.name + ": filter matches")
			s.play_from_start()
			while s.state == s.PLAYING: s._process(1.0 / 60.0)
			check(s.current_frame_index() == 83 and not s.sound_player.playing, v.name + ": plays to 83 silent")
		else:
			check(not s.ready_to_play and s.load_error != "", v.name + ": rejected (" + str(s.load_error) + ")")
			check(s.play_button.disabled and s.replay_button.disabled, v.name + ": controls disabled")
		drop_scene(s)
	var fr := FileAccess.open("res://showcase.json", FileAccess.WRITE)
	fr.store_buffer(original)
	fr.close()
	check(FileAccess.get_file_as_bytes("res://showcase.json") == original, "showcase.json restored byte-exact")
	finish()

func finish() -> void:
	print("QA07_B04_LOGIC %d checks / %d failures | %s" % [checks, failures.size(), JSON.stringify(notes)])
	for f in failures: print("  FAIL ", f)
	quit(0 if failures.is_empty() else 1)
