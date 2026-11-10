extends SceneTree
## Prepared only on 2026-11-02. Run later only after the engine/test window is released.
## Author engine checks; no device listening, visual acceptance or OS input claim.
const EPS := 0.0000001
const MANIFEST_PATH := "res://art/c03/manifest.json"
const AUDIO_PATH := "res://art/c03/audio/feather-selected.wav"
const MANIFEST_SHA := "fd1ae8323bae9bbc24cef60a68fa715ed5228474bb7e9d11dfd4b13617f98b98"
const AUDIO_SHA := "d1310bdaa9ea6017c2bef9e9b159c73f9fa39e15f3d6e337b37250f65ca77cfb"
const PCM_SHA := "47bb9d09f6d9dc084fcc301573d75e389612bb96b57e79f9ba7badcd331c9a95"
const MEDIA_END_TICKS := 260250
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

func sha256(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()

func check_phase(scene, expected_phase: float, previous_playback, label: String) -> void:
	# Caller takes the driver lock BEFORE the production play call. Native WAV
	# start() pre-fills the resampler; a separately started same-WAV reference
	# includes the identical prefill without assuming a mixed-buffer tolerance.
	check(scene.sound_player.playing,label+": audio playing")
	check(scene.audio_event_handled,label+": pending event consumed")
	if not scene.sound_player.playing:
		return
	var actual: AudioStreamPlayback = scene.sound_player.get_stream_playback()
	check(actual!=previous_playback,label+": uses a new playback")
	var reference: AudioStreamPlayback = scene.sound_player.stream.instantiate_playback()
	check(reference!=null,label+": independent native reference exists")
	if reference==null:
		return
	reference.start(expected_phase)
	var actual_position: float = actual.get_playback_position()
	var reference_position: float = reference.get_playback_position()
	var tolerance: float = 2.0/float(scene.sound_player.stream.mix_rate)
	phase_observations.append({"case":label,"expected_submitted_phase":expected_phase,
		"actual_native_position":actual_position,"reference_native_position":reference_position,
		"difference":actual_position-reference_position,"sample_quantization_tolerance":tolerance})
	check(absf(actual_position-reference_position)<tolerance,label+": original WAV starts at current source phase")
	reference.stop()

func check_assets_and_timeline(scene) -> void:
	check(FileAccess.get_sha256(MANIFEST_PATH)==MANIFEST_SHA,"unchanged repository-mapped source manifest")
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	check(manifest is Dictionary,"source manifest parses")
	if not manifest is Dictionary:
		return
	check(manifest.schema=="c3-frozen-repository-mapping-v1","source manifest schema")
	check(manifest.frames.size()==98 and scene.frames.size()==98 and scene.frame_ticks.size()==98
		and scene.source_duration_ticks.size()==98,"all 98 source entries and loaded textures retained")
	check(manifest.time_base==[1.0,90000.0] and absf(scene.time_base-1.0/90000.0)<0.000000000001,"original tick time base")
	check(absf(scene.duration-float(MEDIA_END_TICKS)/90000.0)<0.000000000001,"exact video-media duration, no 2.985 second tail")
	check(scene.foot_reference==Vector2(475,760) and scene.world_foot==Vector2(720,441)
		and absf(scene.display_scale-0.21)<0.000000000001,"fixed trial scale and source/world foot reference")
	check(scene.source_to_world(scene.foot_reference).is_equal_approx(scene.world_foot),"source foot maps to world foot")
	for point in [Vector2.ZERO,Vector2(960,0),Vector2(0,960),Vector2(960,960)]:
		var expected: Vector2 = scene.world_foot+(point-scene.foot_reference)*scene.display_scale
		check(scene.source_to_world(point).is_equal_approx(expected),"fixed single-direction transform at "+str(point))
	var next_tick := 0
	for i in manifest.frames.size():
		var item: Dictionary = manifest.frames[i]
		var label := "source entry "+str(i)
		var tick := int(item.pts_ticks)
		var hold := int(item.source_duration_ticks)
		var at := float(tick)/90000.0
		check(int(item.index)==i and tick==next_tick,label+": original index and continuous nonuniform PTS")
		check(scene.frame_ticks[i]==tick and scene.source_duration_ticks[i]==hold,label+": source ticks unchanged")
		check(scene.frame_at(at)==i,label+": exact source start retained")
		if i>0:
			check(scene.frame_at(at-EPS)==i-1,label+": preceding instant keeps previous frame")
		var file: String = str(item.file)
		var path: String = MANIFEST_PATH.get_base_dir().path_join(file)
		check(file=="frames/frame_%06d.png" % i,label+": canonical relative source file")
		check(FileAccess.get_sha256(path)==str(item.sha256),label+": original PNG bytes")
		var image := Image.new()
		var loaded: bool = image.load(path)==OK
		check(loaded and image.get_size()==Vector2i(960,960),label+": full fixed source canvas")
		check(loaded and scene.frames[i].get_image().get_data()==image.get_data(),label+": actual loaded texture matches its source")
		if i<97:
			check(hold>0,label+": positive source interval")
			var end := float(tick+hold)/90000.0
			check(scene.frame_at((at+end)*0.5)==i and scene.frame_at(end-EPS)==i,label+": full original hold")
		else:
			check(tick==MEDIA_END_TICKS and hold==0,"last entry remains zero duration at exact media end")
		next_tick += hold
	check(next_tick==MEDIA_END_TICKS,"source sample durations end at exact T")
	check(scene.frame_at(scene.duration-EPS)==96 and scene.frame_at(scene.duration)==97
		and scene.frame_at(scene.duration+1.0)==97,"terminal entry is explicit static end pose, never a loop")
	check(FileAccess.get_sha256(AUDIO_PATH)==AUDIO_SHA,"selected WAV copied without processing")
	var stream: AudioStreamWAV = scene.sound_player.stream
	check(stream!=null,"selected WAV loaded directly")
	if stream==null:
		return
	check(stream.format==AudioStreamWAV.FORMAT_16_BITS and stream.stereo
		and stream.mix_rate==44100 and stream.data.size()==44100*4,"selected original 44.1kHz stereo 16-bit, 44100 sample frames")
	check(sha256(stream.data)==PCM_SHA,"all original PCM samples and channels")
	check(stream.get_length()==1.0 and stream.loop_mode==AudioStreamWAV.LOOP_DISABLED,"one-second WAV with no independent loop")
	check(absf(scene.audio_start_seconds-0.405)<0.000000000001,"waveform-only trial audio offset remains configurable baseline")
	check(scene.sound_player.max_polyphony==1,"single audio player polyphony")

func check_playback_boundaries(scene) -> void:
	check(scene.state=="ready" and scene.elapsed==0.0 and not scene.sound_player.playing,"default ready state is silent at source zero")
	scene._process(0.6)
	check(scene.state=="ready" and scene.elapsed==0.0 and not scene.sound_player.playing,"ready does not advance or trigger sound")
	scene.play_from_start()
	check(scene.state=="playing" and scene.elapsed==0.0 and not scene.audio_event_handled
		and not scene.sound_player.playing,"play resets to source zero with one pending sound event")
	scene._process(scene.audio_start_seconds-EPS)
	check(not scene.audio_event_handled and not scene.sound_player.playing,"instant before offset stays pending and silent")
	AudioServer.lock()
	scene._process(EPS*2.0)
	check_phase(scene,scene.elapsed-scene.audio_start_seconds,null,"small step crosses sound start")
	var first_playback = scene.sound_player.get_stream_playback()
	scene._process(0.1)
	check(scene.sound_player.get_stream_playback()==first_playback,"later steps cannot retrigger the consumed event")
	AudioServer.unlock()

	AudioServer.lock()
	scene.play_from_start()
	check(not scene.sound_player.playing and not scene.audio_event_handled and scene.elapsed==0.0,"replay stops previous sound and clears event state")
	scene._process(scene.audio_start_seconds)
	check_phase(scene,0.0,first_playback,"exact audio start boundary")
	var exact_playback = scene.sound_player.get_stream_playback()
	AudioServer.unlock()

	AudioServer.lock()
	scene.play_from_start()
	scene._process(scene.audio_start_seconds+0.2)
	check_phase(scene,0.2,exact_playback,"late frame seeks 0.2 seconds into WAV")
	AudioServer.unlock()

	scene.play_from_start()
	scene._process(scene.audio_start_seconds+scene.sound_player.stream.get_length())
	check(scene.state=="playing" and scene.audio_event_handled and not scene.sound_player.playing,"exact one-second audio tail consumes event without late start")
	scene._process(0.1)
	check(scene.audio_event_handled and not scene.sound_player.playing,"expired event cannot start on a subsequent frame")

	scene.play_from_start()
	scene._process(scene.duration)
	check(scene.state=="ended" and scene.elapsed==scene.duration and scene.frame_at(scene.elapsed)==97
		and scene.audio_event_handled and not scene.sound_player.playing,"jump directly to T ends silently at zero-duration terminal entry")
	scene._process(5.0)
	check(scene.state=="ended" and scene.elapsed==scene.duration and not scene.sound_player.playing,"ended pose never adds video time, loops or triggers sound")
	scene.play_from_start()
	scene._process(scene.duration+1.0)
	check(scene.state=="ended" and scene.elapsed==scene.duration and not scene.sound_player.playing,"large stall beyond T never补播 an old sound")

	AudioServer.lock()
	scene.play_from_start()
	scene._process(scene.audio_start_seconds+0.1)
	check(scene.sound_player.playing,"inspection case starts with an active sound")
	scene.inspect_frame(31)
	check(scene.state=="inspection" and not scene.sound_player.playing
		and scene.audio_event_handled and scene.current_frame_index()==31,"frame inspection stops old sound and cannot schedule a new event")
	scene._process(0.3)
	check(scene.state=="inspection" and not scene.sound_player.playing and scene.current_frame_index()==31,"inspection is static and silent")
	scene.inspect_frame(97)
	check(scene.state=="inspection" and scene.elapsed==scene.duration and not scene.sound_player.playing,"zero-duration endpoint can be inspected without sound")
	AudioServer.unlock()
	scene.play_from_start()
	check(scene.state=="playing" and scene.elapsed==0.0 and not scene.audio_event_handled and not scene.sound_player.playing,"replay from end inspection starts a clean playback")

func check_mirror(scene) -> void:
	# D-20261110-004: horizontal mirror reuses the same textures/PTS/WAV and world foot.
	check(scene.facing==1 and scene.original_button.button_pressed and not scene.mirrored_button.button_pressed,
		"default facing is the original single direction")
	var original_corners: Array[Vector2] = []
	var probe_points := [Vector2.ZERO,Vector2(960,0),Vector2(0,960),Vector2(960,960),Vector2(300,500),scene.foot_reference]
	for point in probe_points:
		original_corners.append(scene.source_to_world(point))
	var textures_before: Array = scene.frames.duplicate()
	var ticks_before: Array = scene.frame_ticks.duplicate()
	scene.mirrored_button.pressed.emit()
	check(scene.facing==-1 and scene.mirrored_button.button_pressed and not scene.original_button.button_pressed,
		"mirror button selects mirrored facing")
	check(scene.draw_scale()==Vector2(-scene.display_scale,scene.display_scale),"mirror is a pure negative X scale with unchanged trial scale")
	check(scene.source_to_world(scene.foot_reference).is_equal_approx(scene.world_foot),"mirrored source foot maps to the same world foot")
	for i in probe_points.size():
		var mirrored: Vector2 = scene.source_to_world(probe_points[i])
		var reflected := Vector2(2.0*scene.world_foot.x-original_corners[i].x,original_corners[i].y)
		check(mirrored.is_equal_approx(reflected),"mirrored point is the reflection about world foot x at "+str(probe_points[i]))
	check(scene.frames==textures_before and scene.frame_ticks==ticks_before,"mirror reuses identical texture objects and source ticks")
	for i in scene.frame_ticks.size():
		check(scene.frame_at(float(scene.frame_ticks[i])/90000.0)==i,"mirrored timeline keeps source start "+str(i))
	# Mirrored facing must pass the same full playback/audio boundaries.
	scene.play_from_start()
	scene.inspect_frame(0)
	check_playback_boundaries_from_any(scene,"mirrored")
	# Switching mid-play changes presentation only: time, state, event and live sound remain.
	AudioServer.lock()
	scene.play_from_start()
	scene._process(scene.audio_start_seconds+0.15)
	var live = scene.sound_player.get_stream_playback()
	var elapsed_before: float = scene.elapsed
	check(scene.sound_player.playing,"switch case starts with an active sound")
	scene.original_button.pressed.emit()
	check(scene.facing==1 and scene.state=="playing" and scene.elapsed==elapsed_before and scene.audio_event_handled
		and scene.sound_player.playing and scene.sound_player.get_stream_playback()==live,"switch to original keeps time, state and the same live WAV")
	scene.mirrored_button.pressed.emit()
	check(scene.facing==-1 and scene.state=="playing" and scene.elapsed==elapsed_before
		and scene.sound_player.get_stream_playback()==live,"switch to mirrored keeps time, state and the same live WAV")
	scene.mirrored_button.pressed.emit()
	check(scene.facing==-1 and scene.mirrored_button.button_pressed and scene.sound_player.get_stream_playback()==live,"same-direction selection is a no-op")
	AudioServer.unlock()
	scene.play_from_start()
	scene._process(scene.duration)
	scene.original_button.pressed.emit()
	check(scene.state=="ended" and scene.current_frame_index()==97 and not scene.sound_player.playing and scene.facing==1,
		"switching at Ended keeps the static terminal entry silent")
	scene.set_facing(0)
	scene.set_facing(5)
	check(scene.facing==1,"invalid facing values are rejected")
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_2
	scene._unhandled_key_input(key)
	check(scene.facing==-1,"key 2 selects mirrored")
	key.keycode = KEY_1
	scene._unhandled_key_input(key)
	check(scene.facing==1,"key 1 selects original")
	check(scene.state=="ended" and not scene.sound_player.playing,"keys only change facing")

func check_playback_boundaries_from_any(scene, label: String) -> void:
	# Reuse the original boundary suite from a clean Ready-equivalent start.
	scene.sound_player.stop()
	scene.state = "ready"
	scene.elapsed = 0.0
	scene.audio_event_handled = false
	var before_failures := failure_messages.size()
	check_playback_boundaries(scene)
	check(failure_messages.size()==before_failures,label+": complete original playback boundary suite passes")

func finish() -> void:
	var report := {"schema":"c3-single-direction-author-boundaries-v1","checks":checks,
		"failures":failure_messages.size(),"failure_messages":failure_messages,"phase_observations":phase_observations,
		"scope":"author source/timing/audio/transform checks; no GUI, OS input, listening or independent visual acceptance"}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			var path := argument.trim_prefix("--output=")
			var output := FileAccess.open(path,FileAccess.WRITE)
			if output==null:
				check(false,"cannot write report: "+path)
			else:
				output.store_string(JSON.stringify(report,"\t")+"\n")
	print("C3_SINGLE_DIRECTION ",checks," checks / ",failure_messages.size()," failures")
	quit(0 if failure_messages.is_empty() else 1)

func run() -> void:
	AudioServer.set_bus_mute(0,true)
	root.size = Vector2i(1440,810)
	var controller = load("res://showcase.gd")
	check(controller is Script and controller.can_instantiate(),"showcase script is available and can instantiate")
	if not controller is Script or not controller.can_instantiate():
		finish()
		return
	var scene = controller.new()
	root.add_child(scene)
	scene.set_process(false)
	check(scene.ready_to_play,"source assets and independent scene initialize")
	if scene.ready_to_play:
		check_assets_and_timeline(scene)
		check_playback_boundaries(scene)
		check_mirror(scene)
	scene.sound_player.stop()
	scene.queue_free()
	await process_frame
	finish()
