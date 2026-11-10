extends SceneTree
## D-20261110-005 normal graphical playback through the app, engine-driven
## _process (no manual clock). Muted, Dummy audio, no OS input or listening.
##   --output=<abs.json> [--character=<id>]
## loop: each direction for 1.3 periods, WAV restarted once per loop boundary.
## one_shot: each direction plays to Ended on the last frame with one WAV
## playback, replay while sound is active, then return-to-selector frees sound.
var output := ""
var wanted := "all"
var app
var runs: Array = []
var errors: Array[String] = []
var checks := 0

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--character="): wanted = arg.trim_prefix("--character=")
	call_deferred("run")

func require(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		errors.append(message)
		push_error(message)

func pid(p) -> int:
	if not p.sound_player.playing: return 0
	var s: AudioStreamPlayback = p.sound_player.get_stream_playback()
	return s.get_instance_id() if s != null else 0

func watch(p, label: String, seconds: float, until_end: bool) -> Dictionary:
	var start := Time.get_ticks_usec()
	var seen := {}
	var ids := {}
	var last_id := 0
	var restarts := 0
	while Time.get_ticks_usec() - start < int(seconds * 1000000.0):
		await RenderingServer.frame_post_draw
		seen[p.current_frame_index()] = true
		var now := pid(p)
		if now != 0:
			ids[now] = true
			if now != last_id: restarts += 1
			last_id = now
		if until_end and p.state == "ended": break
	var result := {"case":label, "wall_seconds":float(Time.get_ticks_usec() - start) / 1000000.0,
		"elapsed":p.elapsed, "state":p.state if p.mode != "loop" else "loop", "end_frame":p.current_frame_index(),
		"distinct_frames_observed":seen.size(), "frame_count":p.frames.size(), "audio_playbacks":ids.size(), "restarts_seen":restarts}
	runs.append(result)
	return result

func run() -> void:
	if DisplayServer.get_name() == "headless" or not output.is_absolute_path():
		push_error("realtime probe needs a real window and an absolute --output")
		quit(1)
		return
	AudioServer.set_bus_mute(0, true)
	root.title = "D-20261110-005 Character Showcase Realtime (Muted)"
	root.size = Vector2i(1440, 810)
	app = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(app)
	await process_frame
	var ids: Array = app.character_ids() if wanted == "all" else [wanted]
	for id in ids:
		app.open_character(id)
		var p = app.player
		require(p.ready_to_play, id + " loads")
		if not p.ready_to_play: continue
		for d in p.directions.size():
			var label: String = id + "/" + str(p.directions[d].id)
			if p.mode == "loop":
				p.select_direction((d + 1) % p.directions.size())
				p.select_direction(d)
				var r := await watch(p, label + " 1.3 loops", p.period() * 1.3, false)
				require(int(r.restarts_seen) == 2 and int(r.audio_playbacks) == 2, label + ": one WAV start plus exactly one loop restart")
				require(float(r.elapsed) >= p.period(), label + ": crossed a loop boundary")
			else:
				p.select_direction(d)
				p.play_from_start()
				var r := await watch(p, label + " complete playback", p.duration + 2.0, true)
				require(r.state == "ended" and int(r.end_frame) == p.frames.size() - 1 and not p.sound_player.playing,
					label + ": reaches Ended on the last frame with sound stopped")
				require(int(r.audio_playbacks) == 1, label + ": exactly one WAV playback")
				var end_elapsed: float = p.elapsed
				await RenderingServer.frame_post_draw
				await RenderingServer.frame_post_draw
				require(p.state == "ended" and p.elapsed == end_elapsed and not p.sound_player.playing, label + ": Ended does not loop")
				p.replay_button.pressed.emit()
				var wait_start := Time.get_ticks_usec()
				while not p.sound_player.playing and Time.get_ticks_usec() - wait_start < 3000000:
					await RenderingServer.frame_post_draw
				var old := pid(p)
				require(old != 0, label + ": replay produces sound")
				p.replay_button.pressed.emit()
				require(p.elapsed == 0.0 and p.state == "playing" and (pid(p) != old), label + ": replay with live sound restarts cleanly")
		var player_sound: AudioStreamPlayer = p.sound_player
		if p.mode == "one_shot" and not player_sound.playing:
			p.play_from_start()
			p._process(p.audio_start_seconds + 0.01)
		require(player_sound.playing, id + ": sound live before return")
		p.back_button.pressed.emit()
		await process_frame
		await process_frame
		require(app.player == null and app.selector.visible and not is_instance_valid(player_sound), id + ": return frees the player and its sound")
	var report := {"schema":"character-showcase-realtime-v1", "task":"D-20261110-005", "display_server":DisplayServer.get_name(),
		"audio_driver":AudioServer.get_driver_name(), "master_muted":true, "os_input":false, "device_listening":false,
		"runs":runs, "checks":checks, "errors":errors, "success":errors.is_empty(),
		"limit":"Screen refresh does not guarantee every source frame is displayed; not human continuous viewing or listening."}
	var f := FileAccess.open(output, FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "\t") + "\n")
	f.close()
	app.queue_free()
	await process_frame
	print("CHARACTER_REALTIME ", runs.size(), " runs / ", checks, " checks / ", errors.size(), " errors")
	quit(0 if errors.is_empty() else 1)
