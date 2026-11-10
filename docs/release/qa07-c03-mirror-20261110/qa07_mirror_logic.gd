extends SceneTree
## 07 independent logic probe for D-20261110-004 C3 horizontal mirror.
## Written by 07 (not the author suite). Drives the production scene with
## deterministic manual _process steps and real scene-tree input events.
## Scope: engine state/audio-object logic only. Dummy audio driver: no device
## listening; Input.parse_input_event is engine input, not OS mouse/keyboard.
var checks := 0
var failures: Array[String] = []
var log_lines: Array[String] = []
var scene

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, msg: String) -> void:
	checks += 1
	if not ok:
		failures.append(msg)
		push_error("QA07 FAIL: " + msg)

func note(s: String) -> void:
	log_lines.append(s)

func step(dt: float, n: int) -> void:
	for i in n:
		scene._process(dt)

func step_until(t: float, dt: float) -> void:
	while scene.state == scene.PLAYING and scene.elapsed + dt <= t:
		scene._process(dt)

func expected_index(seconds: float) -> int:
	if seconds >= scene.duration: return 97
	var cur := 0
	for i in scene.frame_ticks.size():
		if float(scene.frame_ticks[i]) / 90000.0 > maxf(seconds, 0.0): break
		cur = i
	return cur

func send_key(code: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = true
	Input.parse_input_event(ev)
	Input.flush_buffered_events()
	var up := ev.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
	Input.flush_buffered_events()

func run() -> void:
	var packed: PackedScene = load("res://main.tscn")
	scene = packed.instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_process(false) # deterministic stepping only
	check(scene.ready_to_play, "scene ready (" + str(scene.load_error) + ")")
	if not scene.ready_to_play:
		finish(); return
	check(scene.frames.size() == 98, "98 textures loaded")
	var tex_ids: Array[int] = []
	for t in scene.frames: tex_ids.append(t.get_instance_id())
	var stream_id: int = scene.sound_player.stream.get_instance_id()

	# --- geometry: shared world foot, reflection about x=720 ---
	for f: int in [1, -1]:
		scene.set_facing(f)
		check(scene.facing == f, "facing set %d" % f)
		check(scene.source_to_world(scene.foot_reference).is_equal_approx(Vector2(720, 441)), "foot maps to (720,441) facing %d" % f)
		check(scene.draw_scale().is_equal_approx(Vector2(0.21 * f, 0.21)), "draw scale facing %d" % f)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261110
	var corners := [Vector2(0, 0), Vector2(960, 0), Vector2(0, 960), Vector2(960, 960), Vector2(475, 760)]
	for i in 200: corners.append(Vector2(rng.randf_range(0, 960), rng.randf_range(0, 960)))
	var refl_ok := true
	for p in corners:
		scene.set_facing(1)
		var a: Vector2 = scene.source_to_world(p)
		scene.set_facing(-1)
		var b: Vector2 = scene.source_to_world(p)
		if not (is_equal_approx(a.x + b.x, 1440.0) and is_equal_approx(a.y, b.y)): refl_ok = false
	check(refl_ok, "205 source points: mirrored world x = 1440 - original x, same y")
	scene.set_facing(1)

	# --- controls ---
	check(scene.original_button.button_pressed and not scene.mirrored_button.button_pressed, "original button pressed state")
	check(not scene.original_button.disabled and not scene.mirrored_button.disabled, "facing buttons enabled when ready")
	check(scene.state == scene.READY, "starts READY")

	for f: int in [1, -1]:
		var tag := "orig" if f == 1 else "mirr"
		scene.set_facing(f)
		# --- full play #1 ---
		scene.play_from_start()
		check(scene.state == scene.PLAYING and scene.elapsed == 0.0, tag + ": play starts at 0")
		check(not scene.sound_player.playing, tag + ": silent before 0.405")
		var dt := 1.0 / 240.0
		var idx_ok := true
		var sound_start := -1.0
		var prev_idx := 0
		var monotonic := true
		while scene.state == scene.PLAYING:
			scene._process(dt)
			var ci: int = scene.current_frame_index()
			if ci != expected_index(scene.elapsed): idx_ok = false
			if ci < prev_idx: monotonic = false
			prev_idx = ci
			if sound_start < 0 and scene.sound_player.playing: sound_start = scene.elapsed
		check(idx_ok, tag + ": every step frame index == PTS lookup")
		check(monotonic, tag + ": index never goes backwards")
		check(sound_start >= 0.405 and sound_start < 0.405 + dt + 1e-9, tag + ": WAV starts at first step >= 0.405 (%f)" % sound_start)
		check(scene.state == scene.ENDED, tag + ": reaches ENDED")
		check(scene.current_frame_index() == 97, tag + ": ended shows index 97")
		check(is_equal_approx(scene.elapsed, scene.duration), tag + ": elapsed clamped at T")
		check(not scene.sound_player.playing, tag + ": silent at end")
		step(1.0 / 60.0, 120)
		check(scene.state == scene.ENDED and scene.current_frame_index() == 97 and not scene.sound_player.playing, tag + ": stays ended 2s (no loop)")
		check(scene.replay_button.disabled == false and scene.play_button.disabled, tag + ": replay enabled / play disabled when ended")
		# --- replay after end ---
		scene.replay_button.pressed.emit()
		check(scene.state == scene.PLAYING and scene.elapsed == 0.0 and not scene.sound_player.playing and not scene.audio_event_handled, tag + ": replay resets")
		step_until(0.6, 1.0 / 120.0)
		check(scene.sound_player.playing, tag + ": replay sound playing at 0.6")
		var pb1 = scene.sound_player.get_stream_playback()
		# --- replay while sound active: old playback replaced ---
		scene.play_from_start()
		check(not scene.sound_player.playing, tag + ": active replay stops old sound immediately")
		step_until(0.5, 1.0 / 120.0)
		var pb2 = scene.sound_player.get_stream_playback()
		check(scene.sound_player.playing and pb2 != pb1, tag + ": active replay uses new playback")
		# --- facing switch mid-play (both directions, via signal, key, and API) ---
		var other: int = -f
		for method in ["button", "key", "api"]:
			var e0: float = scene.elapsed
			var s0: String = scene.state
			var h0: bool = scene.audio_event_handled
			var p0 = scene.sound_player.get_stream_playback()
			var pos0: float = p0.get_playback_position() if p0 != null else -1.0
			var i0: int = scene.current_frame_index()
			var target: int = other if scene.facing == f else f
			if method == "button":
				(scene.mirrored_button if target == -1 else scene.original_button).pressed.emit()
			elif method == "key":
				send_key(KEY_2 if target == -1 else KEY_1)
			else:
				scene.set_facing(target)
			check(scene.facing == target, tag + ": switch via " + method + " applied")
			check(scene.elapsed == e0 and scene.state == s0 and scene.audio_event_handled == h0, tag + ": switch via " + method + " keeps elapsed/state/event")
			var p1 = scene.sound_player.get_stream_playback()
			check(scene.sound_player.playing and p1 == p0, tag + ": switch via " + method + " keeps same playing WAV playback")
			check(p1 == null or is_equal_approx(p1.get_playback_position(), pos0), tag + ": switch via " + method + " keeps WAV position")
			check(scene.current_frame_index() == i0, tag + ": switch via " + method + " keeps frame index")
			check(scene.original_button.button_pressed == (target == 1) and scene.mirrored_button.button_pressed == (target == -1), tag + ": toggle display matches after " + method)
			step(1.0 / 120.0, 6)
		# same facing re-select = no-op
		var e1: float = scene.elapsed
		var p2 = scene.sound_player.get_stream_playback()
		scene.set_facing(scene.facing)
		check(scene.elapsed == e1 and scene.sound_player.get_stream_playback() == p2 and scene.sound_player.playing, tag + ": same-facing reselect no-op")
		scene.set_facing(0)
		scene.set_facing(3)
		check(scene.facing == 1 or scene.facing == -1, tag + ": invalid facing values ignored")
		# finish this run in whatever facing, ensure end still 97
		scene.set_facing(f)
		while scene.state == scene.PLAYING: scene._process(1.0 / 60.0)
		check(scene.state == scene.ENDED and scene.current_frame_index() == 97 and not scene.sound_player.playing, tag + ": run with switches still ends at 97 silent")
		# switch while ended: no state change, no sound
		scene.set_facing(-f)
		check(scene.state == scene.ENDED and scene.current_frame_index() == 97 and not scene.sound_player.playing, tag + ": switch while ended keeps ended/silent")
		step(1.0 / 60.0, 30)
		check(not scene.sound_player.playing and scene.state == scene.ENDED, tag + ": no stale sound after ended switch")
		scene.set_facing(f)
		# switch during the pre-sound window must not emit/skip the sound event
		scene.play_from_start()
		step_until(0.2, 1.0 / 120.0)
		scene.set_facing(-f)
		check(not scene.sound_player.playing and not scene.audio_event_handled, tag + ": switch before 0.405 does not emit sound")
		step_until(0.5, 1.0 / 120.0)
		check(scene.sound_player.playing, tag + ": sound still starts after pre-sound switch")
		scene.set_facing(f)
		# inspection: silent, frame index fixed
		scene.inspect_frame(31)
		check(scene.state == scene.INSPECTION and scene.current_frame_index() == 31 and not scene.sound_player.playing, tag + ": inspection silent at 31")
		scene.set_facing(-f)
		check(scene.state == scene.INSPECTION and scene.current_frame_index() == 31 and not scene.sound_player.playing, tag + ": switch in inspection keeps 31 silent")
		scene.set_facing(f)

	# textures/WAV reused, never reloaded
	var same := true
	for i in 98:
		if scene.frames[i].get_instance_id() != tex_ids[i]: same = false
	check(same, "same 98 texture objects after all switches")
	check(scene.sound_player.stream.get_instance_id() == stream_id, "same WAV stream object")

	# exit clears sound
	scene.set_facing(-1)
	scene.play_from_start()
	step_until(0.7, 1.0 / 120.0)
	check(scene.sound_player.playing, "pre-exit sound playing (mirrored)")
	var player: AudioStreamPlayer = scene.sound_player
	root.remove_child(scene)
	check(not player.playing, "exit_tree stops WAV")
	scene.free()
	await process_frame
	finish()

func finish() -> void:
	var line := "QA07_C03_MIRROR_LOGIC %d checks / %d failures" % [checks, failures.size()]
	print(line)
	for f in failures: print("  FAIL ", f)
	quit(0 if failures.is_empty() else 1)
