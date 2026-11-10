extends SceneTree
## D-20261110-004 B4: normal dedicated graphical playback observations. No OS input or listening.
const MANIFEST_SHA := "cefc1cec66ffdf3c0df817dd050f191a1dc96bf16b683e062e806e829d5afa84"
const WAV_LENGTH := 3.5
var output := ""
var scene
var errors: Array[String] = []
var runs: Array[Dictionary] = []
var resets: Array[Dictionary] = []
var stop_observations: Array[Dictionary] = []
var checks := 0

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	call_deferred("run")

func require(ok: bool, message: String) -> bool:
	checks += 1
	if not ok:
		errors.append(message)
		push_error(message)
	return ok

func playback_id() -> int:
	if not scene.sound_player.playing: return 0
	var playback: AudioStreamPlayback = scene.sound_player.get_stream_playback()
	return playback.get_instance_id() if playback != null else 0

func replay(label: String, button: Button) -> void:
	var previous_id := playback_id()
	# This uses the production button's connected signal, without OS input or
	# claiming a native mouse hit-test. Assert reset before a rendered frame.
	button.pressed.emit()
	var new_id := playback_id()
	var ok: bool = scene.state == "playing" and scene.elapsed == 0.0 and scene.current_frame_index() == 0 and scene.audio_event_handled and scene.sound_player.playing and new_id != previous_id
	require(ok, label + " restarts at frame 0 with a fresh WAV playback started together (offset 0)")
	resets.append({"case":label,"invocation":"programmatic Button.pressed signal; no OS input",
		"state_after_call":scene.state,"elapsed_after_call":scene.elapsed,
		"handled_after_call":scene.audio_event_handled,"audio_playing_after_call":scene.sound_player.playing,
		"previous_playback_id":previous_id,"new_playback_id":new_id,"reset_ok":ok})

func wait_mix_turns() -> Dictionary:
	var start_usec := Time.get_ticks_usec()
	var previous: float = AudioServer.get_time_since_last_mix()
	var rollovers := 0
	var observations: Array[Dictionary] = []
	while rollovers < 3 and Time.get_ticks_usec() - start_usec < 3000000:
		await process_frame
		var since: float = AudioServer.get_time_since_last_mix()
		if since < previous: rollovers += 1
		previous = since
		var item := {"wall_seconds":float(Time.get_ticks_usec()-start_usec)/1000000.0,
			"since_last_mix":since,"observed_mix_clock_rollovers":rollovers}
		if is_instance_valid(scene):
			item["scene_elapsed_seconds"] = scene.elapsed
			item["scene_frame_index"] = scene.current_frame_index()
			item["scene_state"] = scene.state
		observations.append(item)
	return {"rollovers":rollovers,"observations":observations}

func check_removed_from_mix(playback: AudioStreamPlayback, label: String) -> bool:
	if not require(playback != null, label + " retains the original native playback for observation"): return false
	var start_usec := Time.get_ticks_usec()
	var initial_position: float = playback.get_playback_position()
	# Player.stop marks the server node for fade-out/deletion. A retained native
	# WAV Ref can keep its own active flag true after that server node is removed.
	# Do not call playback.stop(), which would bypass the production stop path.
	var settling: Dictionary = await wait_mix_turns()
	require(int(settling.rollovers) >= 3, label + " observes real mix-clock turns after the stop request")
	var before: float = playback.get_playback_position()
	var observing: Dictionary = await wait_mix_turns()
	var after: float = playback.get_playback_position()
	var wall_seconds: float = float(Time.get_ticks_usec() - start_usec) / 1000000.0
	var before_natural_end: bool = before < WAV_LENGTH and after < WAV_LENGTH and wall_seconds < WAV_LENGTH - initial_position
	require(before_natural_end, label + " observation finishes before the original WAV could naturally end")
	var stable: bool = int(observing.rollovers) >= 3 and before == after
	require(stable, label + " old native cursor is strictly frozen across later real mix-clock turns")
	stop_observations.append({"case":label,"settling":settling,"observing":observing,
		"cursor_before":before,"cursor_after":after,"strictly_frozen":stable,
		"initial_cursor":initial_position,"wall_seconds":wall_seconds,"before_natural_end":before_natural_end,
		"retained_native_is_playing_diagnostic":playback.is_playing(),
		"native_stop_called_by_test":false})
	return stable and before_natural_end and int(settling.rollovers) >= 3

func observe(label: String, stop_on_sound: bool = false) -> Dictionary:
	var start_usec := Time.get_ticks_usec()
	var previous_index := -1
	var previous_handled := false
	var seen := {}
	var audio_instances := {}
	var events: Array[Dictionary] = []
	var samples := 0
	var handled_transitions := 0
	while scene.state == "playing" and Time.get_ticks_usec() - start_usec < 10000000:
		# scene._process runs normally. No manual clock increments or image I/O
		# occur here, so saved frames cannot manufacture continuous playback.
		await RenderingServer.frame_post_draw
		var index: int = scene.current_frame_index()
		var current_id := playback_id()
		seen[index] = true
		if current_id != 0: audio_instances[current_id] = true
		var handled: bool = scene.audio_event_handled
		if handled and not previous_handled: handled_transitions += 1
		if index != previous_index or handled != previous_handled:
			events.append({"elapsed_seconds":scene.elapsed,"frame_index":index,"state":scene.state,
				"pts":scene.frame_ticks[index],"audio_event_handled":handled,
				"audio_playing":scene.sound_player.playing,"audio_playback_id":current_id,
				"raw_audio_position":scene.sound_player.get_playback_position() if scene.sound_player.playing else null})
		previous_index = index
		previous_handled = handled
		samples += 1
		if stop_on_sound and scene.sound_player.playing: break
	var ended: bool = scene.state == "ended"
	if stop_on_sound:
		require(scene.state == "playing" and scene.sound_player.playing, label + " reaches a live sound before timeout")
	else:
		require(ended and scene.elapsed == scene.duration and scene.current_frame_index() == 83,
			label + " reaches exact T and stops on index 83")
		require(not scene.sound_player.playing, label + " terminal state has stopped sound")
	# Observation starts from "not handled"; the offset-0 event was already consumed
	# by the press, so exactly one transition is seen on the first sample.
	require(handled_transitions == 1 and audio_instances.size() == 1, label + " plays exactly one WAV playback started at frame 0, never retriggered")
	require(scene.sound_player.max_polyphony == 1, label + " keeps one-player polyphony")
	var result := {"case":label,"normal_process":true,"wall_seconds":float(Time.get_ticks_usec()-start_usec)/1000000.0,
		"end_state":scene.state,"end_elapsed_seconds":scene.elapsed,"end_frame_index":scene.current_frame_index(),
		"sample_count":samples,"observed_source_indices":seen.keys(),"distinct_frames_observed":seen.size(),
		"audio_event_transitions":handled_transitions,"distinct_audio_playback_ids":audio_instances.keys(),"events":events}
	runs.append(result)
	return result

func finish(exit_stopped: bool) -> void:
	var report := {"schema":"b04-single-author-normal-graphical-v1","task":"D-20261110-004",
		"scope":"Normal dedicated graphical automatic playback and programmatic button-signal replay; not human continuous visual or device listening acceptance.",
		"display_server":DisplayServer.get_name(),"engine_version":Engine.get_version_info(),
		"viewport_size":[root.size.x,root.size.y],"audio_driver":AudioServer.get_driver_name(),
		"master_muted":true,"os_input":false,"device_listening":false,
		"manifest_sha256":MANIFEST_SHA,"frame_index_base":0,"runs":runs,"resets":resets,
		"stop_observations":stop_observations,"exit_playback_removed_from_mix":exit_stopped,
		"stop_observation_limit":"Retained native WAV is_playing is diagnostic; removal is checked by an unchanged native cursor across observed real mix-clock turns, without calling native stop.",
		"checks":checks,"errors":errors.duplicate(),"success":errors.is_empty(),
		"audio_position_limit":"Raw mixer/prebuffer positions are diagnostic, not exact play arguments or device delay measurements."}
	var file := FileAccess.open(output, FileAccess.WRITE)
	var written: bool = file != null
	if written:
		file.store_string(JSON.stringify(report,"\t")+"\n")
		file.flush()
		written = file.get_error() == OK
		file.close()
	if is_instance_valid(scene): scene.free()
	if not written: push_error("Could not save real-time report")
	print("B4_SINGLE_REALTIME ",runs.size()," runs / ",checks," checks / ",errors.size()," errors")
	quit(0 if written and errors.is_empty() else 1)

func run() -> void:
	if not require(DisplayServer.get_name() != "headless", "Normal graphical playback refuses headless"):
		quit(1)
		return
	if not require(output.is_absolute_path() and DirAccess.make_dir_recursive_absolute(output.get_base_dir()) == OK, "Absolute writable report path required"):
		quit(1)
		return
	AudioServer.set_bus_mute(0,true)
	root.title = "D-20261110-004 B4 Single Realtime (Muted)"
	root.size = Vector2i(1440,810)
	var packed = load("res://main.tscn")
	if not require(packed is PackedScene, "Standalone scene loads"):
		await finish(false)
		return
	scene = packed.instantiate()
	root.add_child(scene)
	if not require(scene.ready_to_play and scene.state == "ready" and not scene.sound_player.playing,
		"Standalone starts silent and Ready with all frozen resources"):
		await finish(false)
		return
	require(FileAccess.get_sha256("res://art/b04/manifest.json") == MANIFEST_SHA, "B4 manifest unchanged")
	await RenderingServer.frame_post_draw
	replay("initial play", scene.play_button)
	await observe("first complete playback")
	var at_end: float = scene.elapsed
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	require(scene.state == "ended" and scene.elapsed == at_end and not scene.sound_player.playing,
		"Normal Ended frames do not loop, advance time or restart sound")
	replay("replay after Ended", scene.replay_button)
	await observe("replay until live sound", true)
	var previous_live: AudioStreamPlayback = scene.sound_player.get_stream_playback()
	replay("replay while old sound active", scene.replay_button)
	await check_removed_from_mix(previous_live, "replay while old sound active")
	await observe("second complete playback")
	# Exercise actual tree exit while sound is active, not a pre-stopped fixture.
	replay("play for exit cleanup", scene.replay_button)
	await observe("active sound before actual exit", true)
	var exiting_playback: AudioStreamPlayback = scene.sound_player.get_stream_playback()
	var exiting_player: AudioStreamPlayer = scene.sound_player
	scene.free()
	require(not is_instance_valid(scene) and not is_instance_valid(exiting_player), "Actual tree exit releases the production scene and its only player")
	var exit_stopped: bool = await check_removed_from_mix(exiting_playback, "actual tree exit")
	await finish(exit_stopped)
