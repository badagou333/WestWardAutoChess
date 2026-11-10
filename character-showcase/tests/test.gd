extends SceneTree
## D-20261110-005 shared author engine checks, driven by each character.json.
##   --character=<id>|all (default all) --output=<abs.json>
## Covers app selection/return, resource pins, PTS/time lookup, foot and mirror
## mapping, and the loop / one_shot playback and audio contracts.
## No GUI acceptance, OS input or listening claim.
const EPS := 0.0000001
var checks := 0
var failures: Array[String] = []
var per_character := {}
var app

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func phase_ok(p, expected: float, label: String) -> void:
	# Caller holds AudioServer.lock around the production play call.
	check(p.sound_player.playing, label + ": audio playing")
	if not p.sound_player.playing: return
	var actual: AudioStreamPlayback = p.sound_player.get_stream_playback()
	var reference: AudioStreamPlayback = p.sound_player.stream.instantiate_playback()
	reference.start(expected)
	var tol: float = 2.0 / float(p.sound_player.stream.mix_rate)
	check(absf(actual.get_playback_position() - reference.get_playback_position()) < tol, label + ": WAV starts at expected phase")
	reference.stop()

func check_resources(p, id: String) -> void:
	var root := "res://characters/" + id
	check(FileAccess.get_sha256("res://shared/forest-board.png") == "7b568eb54ad25d18efa7dab24adcce833a4528940fdd615ca053196cd6ad1ed6", id + ": shared board bytes")
	for clip_id in p.config.clips:
		var settings: Dictionary = p.config.clips[clip_id]
		var path: String = root.path_join(str(settings.manifest))
		check(FileAccess.get_sha256(path) == str(settings.manifest_sha256), id + "/" + clip_id + ": manifest bytes")
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		var n := 0
		for item in manifest.frames:
			if item.has("sha256"):
				check(FileAccess.get_sha256(path.get_base_dir().path_join(str(item.file))) == str(item.sha256), id + "/" + clip_id + ": frame bytes " + str(item.file))
				n += 1
		check(n == manifest.frames.size(), id + "/" + clip_id + ": every frame has a pinned hash")
		var audio_path: String = root.path_join(str(settings.audio)) if settings.has("audio") else path.get_base_dir().path_join(str(manifest.audio.file))
		check(FileAccess.get_sha256(audio_path) == str(settings.audio_sha256), id + "/" + clip_id + ": audio bytes")

func check_mapping(p, id: String) -> void:
	for d in p.directions.size():
		if p.mode == "loop": p.select_direction((d + 1) % p.directions.size())
		p.select_direction(d)
		var label: String = id + "/" + str(p.directions[d].id)
		check(p.direction_index == d, label + ": selected")
		check(p.source_to_world(p.foot_reference).is_equal_approx(Vector2(720, 441)), label + ": source foot on world foot (720,441)")
		var sign_now: int = int(p.directions[d].sign)
		for point in [Vector2.ZERO, p.canvas, Vector2(p.canvas.x, 0)]:
			var expected: Vector2 = Vector2(720, 441) + (point - p.foot_reference) * Vector2(p.display_scale * sign_now, p.display_scale)
			check(p.source_to_world(point).is_equal_approx(expected), label + ": mirror sign " + str(sign_now) + " mapping")
		for i in p.frame_times.size():
			var t: float = p.frame_times[i]
			check(p.frame_at(t) == i, label + ": frame " + str(i) + " shown at its source time")
			if i > 0: check(p.frame_at(t - 0.00001) == i - 1, label + ": frame " + str(i - 1) + " held until next time")

func check_loop(p, id: String) -> void:
	AudioServer.lock()
	p.select_direction(1)
	p.select_direction(0)
	check(p.elapsed == 0.0, id + ": switch restarts at zero")
	phase_ok(p, 0.0, id + ": switch restarts WAV at zero")
	var first = p.sound_player.get_stream_playback()
	p.select_direction(0)
	check(p.sound_player.get_stream_playback() == first, id + ": same direction is a no-op")
	p._process(p.period() - 0.01)
	check(p.sound_player.get_stream_playback() == first, id + ": no retrigger inside a loop")
	p._process(0.06)
	check(p.sound_player.get_stream_playback() != first, id + ": new loop restarts WAV")
	phase_ok(p, fposmod(p.elapsed, p.period()), id + ": loop restart at current phase")
	check(p.frame_at(p.elapsed) == p.frame_at(fposmod(p.elapsed, p.period())), id + ": frames repeat every period")
	AudioServer.unlock()
	if p.loop_interval > 0:
		check(p.frame_at(p.duration + p.loop_interval * 0.5) == p.frames.size() - 1, id + ": interval holds the last frame")

func check_one_shot(p, id: String) -> void:
	var last: int = p.frames.size() - 1
	p.select_direction(0)
	p.sound_player.stop()
	p.state = "ready"
	p.elapsed = 0.0
	p.audio_event_handled = false
	p._update_controls()
	check(p.current_frame_index() == 0 and not p.sound_player.playing, id + ": Ready silent on frame 0")
	p._process(0.5)
	check(p.state == "ready" and p.elapsed == 0.0, id + ": Ready does not advance")
	check(not p.play_button.disabled and p.replay_button.disabled, id + ": Ready buttons")
	AudioServer.lock()
	p.play_button.pressed.emit()
	check(p.state == "playing" and p.elapsed == 0.0, id + ": play starts at zero")
	if p.audio_start_seconds > 0.0:
		check(not p.sound_player.playing and not p.audio_event_handled, id + ": silent before audio offset")
		p._process(p.audio_start_seconds - EPS)
		check(not p.sound_player.playing, id + ": still silent just before offset")
		p._process(EPS * 2.0)
		phase_ok(p, p.elapsed - p.audio_start_seconds, id + ": WAV starts when offset is crossed")
	else:
		phase_ok(p, 0.0, id + ": WAV starts together with frame 0")
	var live = p.sound_player.get_stream_playback()
	p._process(0.1)
	check(p.sound_player.get_stream_playback() == live, id + ": no retrigger")
	if p.directions.size() > 1:
		var before: float = p.elapsed
		p.direction_buttons[1].pressed.emit()
		check(p.direction_index == 1 and p.elapsed == before and p.state == "playing" and p.sound_player.get_stream_playback() == live,
			id + ": direction switch is display only")
		p.direction_buttons[0].pressed.emit()
	p.replay_button.pressed.emit()
	check(p.state == "playing" and p.elapsed == 0.0 and (p.audio_start_seconds > 0.0 or p.sound_player.get_stream_playback() != live), id + ": replay restarts")
	AudioServer.unlock()
	p.sound_player.stop()
	p.state = "playing"
	p.elapsed = 0.0
	p.audio_event_handled = false
	AudioServer.lock()
	p._process(p.audio_start_seconds + 0.2)
	phase_ok(p, 0.2, id + ": stalled first update seeks to current phase")
	AudioServer.unlock()
	p.play_from_start()
	p._process(p.audio_start_seconds + p.sound_player.stream.get_length())
	check(not p.sound_player.playing and p.audio_event_handled or p.state == "ended", id + ": expired event never starts late")
	p.play_from_start()
	p._process(p.duration)
	check(p.state == "ended" and p.current_frame_index() == last and not p.sound_player.playing, id + ": ends on last frame " + str(last) + " silent")
	p._process(5.0)
	check(p.state == "ended" and p.elapsed == p.duration and p.current_frame_index() == last, id + ": Ended never loops")
	p.inspect_frame(1)
	check(p.state == "inspection" and p.current_frame_index() == 1 and not p.sound_player.playing, id + ": inspection silent")

func check_app() -> void:
	check(app.selector.visible and app.player == null, "app starts on the selector")
	check(app.character_ids() == ["bear", "kingfisher", "herb_boy"], "selector lists three characters in order")
	for id in app.character_ids():
		var button: Button = app.selector.find_child("Character_" + id, true, false)
		check(button != null, id + ": selector button exists")
		if button == null: continue
		button.pressed.emit()
		check(app.player != null and app.player.character_id == id and not app.selector.visible, id + ": selector opens the character")
		var player = app.player
		var sound: AudioStreamPlayer = player.sound_player
		if player.mode == "one_shot":
			player.play_from_start()
			player._process(player.audio_start_seconds + 0.01)
		check(sound.playing, id + ": sound active before return")
		player.back_button.pressed.emit()
		await process_frame
		check(app.player == null and app.selector.visible and not is_instance_valid(sound), id + ": return frees player and its sound")
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_2
	app._unhandled_key_input(key)
	check(app.player != null and app.player.character_id == "kingfisher", "key 2 opens the second character")
	var esc := InputEventKey.new()
	esc.pressed = true
	esc.keycode = KEY_ESCAPE
	app.player._unhandled_key_input(esc)
	await process_frame
	check(app.player == null and app.selector.visible, "Esc returns to selector")

func run() -> void:
	AudioServer.set_bus_mute(0, true)
	root.size = Vector2i(1440, 810)
	var wanted := "all"
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--character="): wanted = arg.trim_prefix("--character=")
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	app = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(app)
	await process_frame
	await check_app()
	var ids: Array = app.character_ids() if wanted == "all" else [wanted]
	for id in ids:
		var before := checks
		var before_fail := failures.size()
		app.open_character(id)
		var p = app.player
		p.set_process(false)
		check(p.ready_to_play, id + ": loads (" + str(p.load_error) + ")")
		if p.ready_to_play:
			check_resources(p, id)
			check_mapping(p, id)
			if p.mode == "loop": check_loop(p, id)
			else: check_one_shot(p, id)
		app.close_character()
		per_character[id] = {"checks":checks - before, "failures":failures.size() - before_fail}
	var report := {"schema":"character-showcase-author-checks-v1", "task":"D-20261110-005", "checks":checks,
		"failures":failures.size(), "failure_messages":failures, "per_character":per_character,
		"scope":"author engine checks; no GUI acceptance, OS input or listening"}
	if output != "":
		var f := FileAccess.open(output, FileAccess.WRITE)
		f.store_string(JSON.stringify(report, "\t") + "\n")
		f.close()
	app.queue_free()
	await process_frame
	print("CHARACTER_SHOWCASE ", checks, " checks / ", failures.size(), " failures ", per_character)
	quit(0 if failures.is_empty() else 1)
