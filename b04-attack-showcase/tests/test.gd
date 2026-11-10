extends SceneTree
## D-20261110-004 B4 author engine checks: resources, PTS lookup, audio start,
## one-shot playback, terminal frame and replay. No GUI, OS input or listening.
const EPS := 0.0000001
const TB := 15360.0
const MANIFEST_PATH := "res://art/b04/manifest.json"
const AUDIO_PATH := "res://art/b04/audio/b04-attack-original.wav"
const LIST_PATH := "res://provenance/resource-list.json"
const MANIFEST_SHA := "cefc1cec66ffdf3c0df817dd050f191a1dc96bf16b683e062e806e829d5afa84"
const AUDIO_SHA := "66ee72af663a0c2eecdd4c7c6817b149cb3b232227ae337e3b85a2333b7d3418"
const MEDIA_END_TICKS := 53760
var checks := 0
var failure_messages: Array[String] = []
var phase_observations: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failure_messages.append(message)
		push_error(message)

func check_phase(scene, expected_phase: float, previous_playback, label: String) -> void:
	# Caller holds the AudioServer lock across the production play call, so the
	# native cursor can be compared with a same-WAV reference started at the
	# expected phase (both include the identical resampler prefill).
	check(scene.sound_player.playing, label + ": audio playing")
	check(scene.audio_event_handled, label + ": start event consumed")
	if not scene.sound_player.playing: return
	var actual: AudioStreamPlayback = scene.sound_player.get_stream_playback()
	check(actual != previous_playback, label + ": uses a new playback")
	var reference: AudioStreamPlayback = scene.sound_player.stream.instantiate_playback()
	reference.start(expected_phase)
	var a: float = actual.get_playback_position()
	var r: float = reference.get_playback_position()
	var tolerance: float = 2.0 / float(scene.sound_player.stream.mix_rate)
	phase_observations.append({"case":label, "expected_phase":expected_phase, "actual_native_position":a,
		"reference_native_position":r, "difference":a - r, "tolerance":tolerance})
	check(absf(a - r) < tolerance, label + ": original WAV starts at the expected phase")
	reference.stop()

func check_resources(scene) -> void:
	check(FileAccess.get_sha256(MANIFEST_PATH) == MANIFEST_SHA, "manifest bytes equal 05 delivery")
	var listing = JSON.parse_string(FileAccess.get_file_as_string(LIST_PATH))
	check(listing is Dictionary and listing.files.size() == 87, "provenance lists 84 PNG + WAV + manifest + board")
	if listing is Dictionary:
		for item in listing.files:
			var path: String = "res://" + str(item.runtime_path)
			check(FileAccess.get_sha256(path) == str(item.sha256), "resource bytes unchanged: " + str(item.runtime_path))
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	check(manifest is Dictionary and manifest.frames.size() == 84, "manifest has 84 frames")
	if not manifest is Dictionary: return
	check(scene.frames.size() == 84 and scene.frame_ticks.size() == 84 and scene.source_duration_ticks.size() == 84, "all 84 textures loaded")
	check(absf(scene.duration - 3.5) < 0.000000001, "media end T = 53760/15360 = 3.5 s")
	check(scene.foot_reference == Vector2(303, 684) and scene.world_foot == Vector2(720, 441)
		and absf(scene.display_scale - 0.16) < 0.000000001, "foot anchor [303,684], world foot (720,441), proposal scale 0.16")
	check(scene.source_to_world(scene.foot_reference).is_equal_approx(scene.world_foot), "source foot maps to world foot")
	var holds := {}
	var next_tick := 0
	for i in manifest.frames.size():
		var item: Dictionary = manifest.frames[i]
		var label := "frame " + str(i)
		var tick := int(item.pts)
		var at := float(tick) / TB
		var end_tick: int = MEDIA_END_TICKS if i == 83 else int(manifest.frames[i + 1].pts)
		var hold: int = end_tick - tick
		holds[hold] = int(holds.get(hold, 0)) + 1
		check(int(item.index) == i and tick == next_tick and scene.frame_ticks[i] == tick and scene.source_duration_ticks[i] == hold,
			label + ": PTS and hold equal manifest")
		check(hold == 512 or hold == 768, label + ": variable 0.0333/0.05 s interval")
		check(absf(float(item.duration_s) - hold / TB) < 0.000001, label + ": duration_s agrees with PTS")
		check(scene.frame_at(at) == i, label + ": shown exactly at its PTS")
		check(scene.frame_at((float(tick) + hold * 0.5) / TB) == i and scene.frame_at(float(end_tick) / TB - EPS) == i, label + ": held for its full interval")
		if i > 0: check(scene.frame_at(at - EPS) == i - 1, label + ": instant before keeps previous frame")
		var path: String = MANIFEST_PATH.get_base_dir().path_join(str(item.file))
		check(FileAccess.get_sha256(path) == str(item.sha256), label + ": PNG bytes")
		var image := Image.new()
		var ok: bool = image.load(path) == OK
		check(ok and image.get_size() == Vector2i(864, 760), label + ": 864x760 canvas")
		check(ok and scene.frames[i].get_image().get_size() == Vector2i(864, 760), label + ": loaded texture size")
		next_tick = end_tick
	check(next_tick == MEDIA_END_TICKS, "holds sum to T")
	check(int(holds.get(768, 0)) == 42 and int(holds.get(512, 0)) == 42, "42 x 768 and 42 x 512 ticks (last frame 512 to T)")
	# Fixed-FPS lookup would disagree: prove PTS lookup is not uniform 24 fps.
	var mismatches := 0
	for k in 840:
		var t: float = k * 3.5 / 840.0
		if scene.frame_at(t) != mini(floori(t * 24.0), 83): mismatches += 1
	check(mismatches > 0, "PTS lookup differs from a uniform 24 fps assumption")
	check(scene.frame_at(scene.duration - EPS) == 83 and scene.frame_at(scene.duration) == 83 and scene.frame_at(99.0) == 83, "after T stays on index 83")
	check(FileAccess.get_sha256(AUDIO_PATH) == AUDIO_SHA, "original WAV bytes")
	var stream: AudioStreamWAV = scene.sound_player.stream
	check(stream != null and stream.mix_rate == 44100 and stream.stereo and stream.format == AudioStreamWAV.FORMAT_16_BITS
		and stream.data.size() == 154350 * 4 and absf(stream.get_length() - 3.5) < 0.000001, "WAV 44.1kHz stereo 16-bit 154350 samples = 3.5 s")
	check(stream != null and stream.loop_mode == AudioStreamWAV.LOOP_DISABLED, "WAV does not loop")
	check(scene.audio_start_seconds == 0.0 and scene.sound_player.max_polyphony == 1, "offset 0, single player")

func check_playback(scene) -> void:
	check(scene.state == "ready" and scene.current_frame_index() == 0 and not scene.sound_player.playing, "Ready shows frame 0 silently")
	scene._process(1.0)
	check(scene.state == "ready" and scene.elapsed == 0.0 and not scene.sound_player.playing, "Ready does not advance")
	check(not scene.play_button.disabled and scene.replay_button.disabled, "Ready: play enabled, replay disabled")
	AudioServer.lock()
	scene.play_button.pressed.emit()
	check(scene.state == "playing" and scene.elapsed == 0.0 and scene.current_frame_index() == 0, "play starts at frame 0")
	check_phase(scene, 0.0, null, "sound starts together with frame 0")
	var first = scene.sound_player.get_stream_playback()
	scene._process(0.5)
	check(scene.sound_player.get_stream_playback() == first, "later steps do not retrigger sound")
	AudioServer.unlock()
	check(scene.play_button.disabled and not scene.replay_button.disabled, "Playing: replay enabled")
	scene._process(1.467 - 0.5)
	check(scene.current_frame_index() == 35 or scene.current_frame_index() == 34, "orb exit region reached near 1.467 s")
	AudioServer.lock()
	scene.replay_button.pressed.emit()
	check(scene.state == "playing" and scene.elapsed == 0.0 and scene.current_frame_index() == 0, "replay mid-play restarts at frame 0")
	check_phase(scene, 0.0, first, "replay restarts WAV from 0")
	AudioServer.unlock()
	# Late first update (window stall): sound seeks to current phase, never from 0.
	scene.sound_player.stop()
	scene.state = "playing"
	scene.elapsed = 0.0
	scene.audio_event_handled = false
	AudioServer.lock()
	scene._process(0.75)
	check_phase(scene, 0.75, null, "stalled start seeks WAV to current phase")
	AudioServer.unlock()
	scene.play_from_start()
	scene._process(scene.duration - 0.01)
	check(scene.state == "playing" and scene.current_frame_index() == 83, "last frame shown in its own interval before T")
	scene._process(0.02)
	check(scene.state == "ended" and scene.elapsed == scene.duration and scene.current_frame_index() == 83
		and not scene.sound_player.playing, "reaching T ends on index 83 with sound stopped")
	scene._process(5.0)
	check(scene.state == "ended" and scene.elapsed == scene.duration and scene.current_frame_index() == 83
		and not scene.sound_player.playing, "Ended never loops, advances or restarts sound")
	check(scene.play_button.disabled and not scene.replay_button.disabled, "Ended: replay enabled")
	scene.play_from_start()
	scene._process(scene.duration + 3.0)
	check(scene.state == "ended" and not scene.sound_player.playing, "large stall past T ends silently")
	AudioServer.lock()
	scene.replay_button.pressed.emit()
	check(scene.state == "playing" and scene.current_frame_index() == 0, "replay after Ended restarts")
	check(scene.sound_player.playing, "replay after Ended plays sound")
	scene.inspect_frame(35)
	check(scene.state == "inspection" and scene.current_frame_index() == 35 and not scene.sound_player.playing, "inspection is static and silent")
	AudioServer.unlock()
	scene._process(0.3)
	check(scene.current_frame_index() == 35 and not scene.sound_player.playing, "inspection does not advance")

func finish() -> void:
	var report := {"schema":"b04-single-author-boundaries-v1", "task":"D-20261110-004", "checks":checks,
		"failures":failure_messages.size(), "failure_messages":failure_messages, "phase_observations":phase_observations,
		"scope":"author engine checks; no GUI, OS input, listening or independent acceptance"}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			var output := FileAccess.open(argument.trim_prefix("--output="), FileAccess.WRITE)
			if output != null: output.store_string(JSON.stringify(report, "\t") + "\n")
	print("B4_SINGLE ", checks, " checks / ", failure_messages.size(), " failures")
	quit(0 if failure_messages.is_empty() else 1)

func run() -> void:
	AudioServer.set_bus_mute(0, true)
	root.size = Vector2i(1440, 810)
	var scene = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	scene.set_process(false)
	check(scene.ready_to_play, "assets initialize: " + str(scene.load_error))
	if scene.ready_to_play:
		check_resources(scene)
		check_playback(scene)
	var player: AudioStreamPlayer = scene.sound_player
	scene.play_from_start()
	check(player.playing, "exit case starts with live sound")
	scene.free()
	check(not is_instance_valid(player), "tree exit frees the only player")
	await process_frame
	finish()
