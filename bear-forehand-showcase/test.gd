extends SceneTree
## Author checks for D-20261102-002; engine input is not an OS mouse/keyboard test.
const EPS := 0.000001
const FRONT_MANIFEST_SHA := "93251e01e00168d6fb3a4bff13a7ac2a3f58d15694a59f78d031c054b56cce98"
const BACK_MANIFEST_SHA := "57fcd1ef9657f283cbd2d4d9779fa7d7d8b62c110414691c8928f83a721d1399"
const BOARD_SHA := "7b568eb54ad25d18efa7dab24adcce833a4528940fdd615ca053196cd6ad1ed6"
const AUDIO := {
	"front":{"path":"res://audio/source-track.wav","rate":44100,"samples":132280,
		"wav_sha":"aaaf61ca9f75ebb4f8c9657108ac0a47245f0ef00efa38bd6a95066803b9caf9",
		"pcm_sha":"7a2f42154eac131e6c940512574c485a3a89d009abf313d699462f4be0e56816"},
	"back":{"path":"res://audio/back-source-track.wav","rate":32000,"samples":115968,
		"wav_sha":"f22f557d3a4eac26ea8055b4cfe363374361d602e7eaf0d49c9f0718fc3bd2d3",
		"pcm_sha":"4a3c508d7c9aff8825ad2d87c0bf4b7c823a16439dbeb2a273fdfd43a99e2289"},
}
var checks := 0
var failures := 0
var failure_messages: Array[String] = []
var audio_restart_observations: Array[Dictionary] = []
var observed_frame_counts := {"front":0,"back":0}

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		failure_messages.append(message)
		push_error(message)

func sha256(data: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(data)
	return context.finish().hex_encode()

func check_audio(clip: Dictionary, clip_id: String) -> void:
	var expected: Dictionary = AUDIO[clip_id]
	var stream: AudioStreamWAV = clip.stream
	check(FileAccess.get_sha256(expected.path)==expected.wav_sha,clip_id+" original WAV bytes")
	check(stream.format==AudioStreamWAV.FORMAT_16_BITS and stream.stereo,clip_id+" original stereo 16-bit PCM")
	check(stream.mix_rate==expected.rate and stream.data.size()==expected.samples*4,clip_id+" original rate and all sample frames")
	check(sha256(stream.data)==expected.pcm_sha,clip_id+" engine-loaded PCM retains both channels and original samples")
	check(absf(stream.get_length()-float(expected.samples)/float(expected.rate))<0.000000001,clip_id+" exact sample duration")
	check(stream.loop_mode==AudioStreamWAV.LOOP_DISABLED,clip_id+" audio does not loop independently")

func check_clip(scene, clip_id: String) -> void:
	var clip: Dictionary = scene.clips[clip_id]
	observed_frame_counts[clip_id] = clip.frames.size()
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(clip.manifest_path))
	check(FileAccess.get_sha256(clip.manifest_path)==(FRONT_MANIFEST_SHA if clip_id=="front" else BACK_MANIFEST_SHA),clip_id+" authoritative manifest bytes")
	var count := 84 if clip_id=="front" else 340
	check(clip.frames.size()==count and clip.times.size()==count and manifest.frames.size()==count,clip_id+" complete source timeline")
	check(clip.canvas==Vector2(400 if clip_id=="front" else 384,320),clip_id+" fixed canvas")
	check(clip.foot==Vector2(177,213) and clip.scale==0.75,clip_id+" unchanged foot and scale")
	check(absf(clip.duration-(3.0 if clip_id=="front" else 3.5416666666666665))<0.000000001,clip_id+" independent video duration")
	check(clip.interval==(0.0 if clip_id=="front" else 0.35),clip_id+" independent added loop hold")
	check_audio(clip,clip_id)
	scene.select_direction(0 if clip_id=="front" else 2)
	var texture_ids := {}
	var names := {}
	var image_hashes := {}
	var duration_ticks := {}
	var next_pts := 0
	for i in clip.times.size():
		var item: Dictionary = manifest.frames[i]
		var at: float = clip.times[i]
		var label := "%s frame %d" % [clip_id,i+1]
		check(absf(at-float(item.source_time_seconds))<0.000000001,label+" source timestamp")
		check(scene.frame_at(at)==i and scene.frame_at(at+EPS)==i,label+" exact start and following instant")
		if i>0: check(scene.frame_at(at-EPS)==i-1,label+" preceding instant remains previous frame")
		var end: float = clip.times[i+1] if i+1<clip.times.size() else clip.duration
		check(scene.frame_at((at+end)*0.5)==i and scene.frame_at(end-EPS)==i,label+" full source hold")
		check(clip.frames[i].get_size()==clip.canvas,label+" canvas retained")
		var path: String = clip.manifest_path.get_base_dir().path_join(str(item.file))
		check(FileAccess.get_sha256(path)==str(item.sha256),label+" original PNG bytes")
		var image := Image.new()
		var loaded: bool = image.load(path)==OK
		check(loaded and clip.frames[i].get_image().get_data()==image.get_data(),label+" actually loaded texture matches its numbered file")
		texture_ids[clip.frames[i].get_instance_id()] = true
		names[item.file] = true
		image_hashes[str(item.sha256)] = true
		if clip_id=="front":
			check(int(item.source_frame)==i+1 and int(item.original_source_frame)==i+10,label+" cropped/original numbering without omissions")
			check(int(item.source_pts)==next_pts and int(item.original_source_pts)==next_pts+5888,label+" continuous original PTS mapping")
			check(absf(at-float(item.source_pts)/15360.0)<0.000000001 and absf(at-float(item.output_time_seconds))<0.000000001,label+" exact nonuniform source/output time")
			check(absf((end-at)-float(item.duration_ticks)/15360.0)<0.000000001,label+" original duration, including short frames")
			duration_ticks[int(item.duration_ticks)] = true
			next_pts += int(item.duration_ticks)
			for cycle in [1,2,17]:
				check(scene.frame_at(float(cycle)*3.0+at)==i and scene.frame_at(float(cycle)*3.0+end-EPS)==i,label+" holds across cycle "+str(cycle))
	check(texture_ids.size()==names.size(),clip_id+" repeated image references reuse textures")
	check(clip.unique_textures==names.size(),clip_id+" texture cache follows unique filenames")
	check(image_hashes.size()==(84 if clip_id=="front" else 326),clip_id+" distinct PNG contents remain unchanged")
	check(scene.frame_at(clip.duration-EPS)==count-1,clip_id+" last frame covers the video end")
	var period: float = clip.duration+clip.interval
	check(scene.frame_at(period-EPS)==count-1 and scene.frame_at(period)==0 and scene.frame_at(period+EPS)==0,clip_id+" exact loop boundary")
	if clip_id=="front":
		check(next_pts==46080 and duration_ticks.size()==4 and duration_ticks.has(128) and duration_ticks.has(192) and duration_ticks.has(512) and duration_ticks.has(768),"front all four nonuniform source durations end at 3 seconds")
		check(clip.times[83]==2.95 and scene.frame_at(2.95)==83 and scene.frame_at(3.0-EPS)==83 and scene.frame_at(3.0)==0,"front final frame holds exactly 2.95–3.0 without added gap")
		for index in [42,43]:
			var item: Dictionary = manifest.frames[index]
			check(str(item.file)=="attack_%04d.png" % (index+1) and int(item.original_source_frame)==index+10 and int(item.repair.donor)==45,"repaired source frame "+str(index+1)+" remains in sequence")
	else:
		check(scene.frame_at(clip.duration)==339 and scene.frame_at(clip.duration+0.175)==339,"back retains its original 0.35 second final-frame hold")

func mix_observation() -> Dictionary:
	# Read before taking the driver lock; these observations are diagnostic only.
	var since: float = AudioServer.get_time_since_last_mix()
	var until: float = AudioServer.get_time_to_next_mix()
	return {"since_last_mix":since,"until_next_mix":until,"mix_interval":since+until,"mix_rate":AudioServer.get_mix_rate()}

func check_restart(scene, expected_phase: float, prior_playback, message: String, mix_before: Dictionary) -> void:
	# Caller holds the audio driver lock from BEFORE the production play call.
	# Native WAV.start() pre-fills its resampler, advancing the decoder cursor.
	# A separate native playback of the same WAV gives that exact prefill offset
	# without assuming a buffer size or allowing a real mixer tick between reads.
	check(scene.sound_player.playing,message+" audio is playing")
	if scene.sound_player.playing:
		var actual: AudioStreamPlayback = scene.sound_player.get_stream_playback()
		check(actual!=prior_playback,message+" replaces previous playback")
		var reference: AudioStreamPlayback = scene.sound_player.stream.instantiate_playback()
		check(reference!=null,message+" independent native reference instantiates")
		if reference!=null:
			reference.start(expected_phase)
			var player_position: float = scene.sound_player.get_playback_position()
			var native_position: float = actual.get_playback_position()
			var reference_position: float = reference.get_playback_position()
			var tolerance: float = 2.0/float(scene.sound_player.stream.mix_rate)
			audio_restart_observations.append({"case":message,"direction":scene.direction_index,"expected_submitted_phase":expected_phase,
				"player_position":player_position,"native_position":native_position,"native_reference_position":reference_position,
				"native_minus_reference":native_position-reference_position,"source_rate":scene.sound_player.stream.mix_rate,
				"sample_quantization_tolerance":tolerance,"mix_before_lock":mix_before})
			check(absf(native_position-reference_position)<tolerance,message+" actual source phase matches native reference after identical resampler prefill")
			reference.stop()

func click_direction(scene, direction: int) -> void:
	var location: Vector2 = scene.direction_buttons[direction].get_global_rect().get_center()
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = location
		Input.parse_input_event(event)

func send_number_key(direction: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = [KEY_1,KEY_2,KEY_3,KEY_4][direction]
	event.pressed = pressed
	Input.parse_input_event(event)

func finish() -> void:
	var report := {"schema":"bear-front-v2-author-engine-checks","checks":checks,"failures":failures,"failure_messages":failure_messages,
		"audio_restart_observations":audio_restart_observations,
		"front_frames":observed_frame_counts.front,"back_source_times":observed_frame_counts.back,"scope":"author engine checks; no OS input, device listening or independent visual acceptance"}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			var path := argument.trim_prefix("--output=")
			var output := FileAccess.open(path,FileAccess.WRITE)
			if output==null:
				check(false,"cannot write requested report: "+path)
			else:
				output.store_string(JSON.stringify(report,"\t")+"\n")
	print("BEAR_FOUR_DIRECTION ",checks," checks / ",failures," failures")
	quit(1 if failures else 0)

func run() -> void:
	root.size = Vector2i(1440,810)
	var scene = load("res://showcase.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	await process_frame
	check(scene.ready_to_play and scene.clips.size()==2,"both actual source views load")
	if not scene.ready_to_play:
		scene.queue_free()
		await process_frame
		finish()
		return
	check(scene.direction_index==0 and not scene.mirrored,"default remains right-front")
	check(scene.direction_buttons.size()==4,"four direction controls exist")
	check(scene.FOOT==Vector2(720,441) and scene.GRID_HALF==Vector2(72,36),"same forest board grid and world foot")
	check(scene.board!=null and scene.board.get_size()==Vector2(1672,941) and FileAccess.get_sha256("res://art/forest-board.png")==BOARD_SHA,"original forest board bytes and size")
	var audio_nodes := 0
	for child in scene.get_children():
		if child is AudioStreamPlayer: audio_nodes += 1
	check(audio_nodes==1,"one shared audio player prevents overlapping old/new voices")
	check(not scene.has_method("_attack") and not scene.has_method("_resolve"),"no combat or damage methods")
	check_clip(scene,"front")
	check_clip(scene,"back")
	var pairs := {}
	# Start with a different direction; every iteration must exercise a real switch.
	for direction in [1,2,3,0]:
		var previous_playback = scene.sound_player.get_stream_playback() if scene.sound_player.playing else null
		scene.elapsed = 0.625
		var mix_before: Dictionary = mix_observation()
		AudioServer.lock()
		scene.select_direction(direction)
		check_restart(scene,0.0,previous_playback,"direction "+str(direction)+" switch",mix_before)
		AudioServer.unlock()
		check(scene.direction_index==direction and scene.elapsed==0.0,"direction switch restarts its timeline")
		check(scene.source_to_world(scene.frame_foot)==scene.FOOT,"source foot maps to same world foot")
		var pressed_count := 0
		for button in scene.direction_buttons:
			if button.button_pressed: pressed_count += 1
		check(pressed_count==1 and scene.direction_buttons[direction].button_pressed,"exactly the selected direction button is pressed")
		var clip_id: String = scene.DIRECTIONS[direction].clip
		var clip: Dictionary = scene.clips[clip_id]
		check(scene.sound_player.stream==clip.stream,"direction uses its own original source track")
		check(scene.mirrored==(int(scene.DIRECTIONS[direction].sign)!=int(clip.source_sign)),"only opposite horizontal direction is mirrored")
		check(scene.sound_player.stream.get_length()<scene.duration+scene.loop_interval,"source audio ends before its loop")
		var off: Vector2 = scene.source_to_world(scene.frame_foot+Vector2(13,9))-scene.FOOT
		if not pairs.has(clip_id): pairs[clip_id] = {"offset":off,"frames":scene.frames,"stream":scene.sound_player.stream}
		else:
			check(off.x==-pairs[clip_id].offset.x and off.y==pairs[clip_id].offset.y,"mirror is horizontal around the foot with no vertical drift")
			var all_shared: bool = scene.frames.size()==pairs[clip_id].frames.size()
			for i in scene.frames.size(): all_shared = all_shared and scene.frames[i]==pairs[clip_id].frames[i]
			check(all_shared and scene.sound_player.stream==pairs[clip_id].stream,"mirror reuses every original texture and unaltered audio")
		var period: float = scene.duration+scene.loop_interval
		previous_playback = scene.sound_player.get_stream_playback()
		scene.elapsed = period-0.01
		mix_before = mix_observation()
		AudioServer.lock()
		scene._process(0.01)
		check_restart(scene,0.0,previous_playback,"exact loop boundary",mix_before)
		AudioServer.unlock()
		check(scene.frame_at(scene.elapsed)==0,"exact loop boundary selects first frame")
		previous_playback = scene.sound_player.get_stream_playback()
		mix_before = mix_observation()
		AudioServer.lock()
		scene._process(period*3.0+0.0075)
		check_restart(scene,0.0075,previous_playback,"multi-loop nonzero-phase jump",mix_before)
		AudioServer.unlock()
		check(scene.frame_at(scene.elapsed)==0,"multi-loop jump selects the current first-frame phase")
		# Also cover front's 0.454ms tail, much shorter than the old 10ms guard.
		var silent_phase: float = (scene.sound_player.stream.get_length()+period)*0.5
		scene.elapsed = period-0.01
		scene._process(0.01+period*2.0+silent_phase)
		check(not scene.sound_player.playing,"multi-loop jump into "+clip_id+" silent tail stops old audio and does not start a late track")
		check(scene.frame_at(scene.elapsed)==scene.frames.size()-1,"silent audio tail retains final source frame")
		scene.sound_player.play(0.625)
		scene.elapsed = 0.625
		previous_playback = scene.sound_player.get_stream_playback()
		var position_before: float = scene.sound_player.get_playback_position()
		scene.select_direction(direction)
		check(scene.elapsed==0.625 and scene.sound_player.get_stream_playback()==previous_playback and scene.sound_player.get_playback_position()>=position_before-EPS,"same direction is a timeline and audio no-op")
	check(audio_restart_observations.size()==12,"all four switches and eight exact/nonzero-phase loop restarts were observed")
	# Actual Control dispatch in the SceneTree; no OS mouse is moved.
	for direction in [3,1,2,0]:
		click_direction(scene,direction)
		await process_frame
		check(scene.direction_index==direction and scene.elapsed==0.0,"direction button responds to pointer input and restarts timeline")
		var unchanged_playback = scene.sound_player.get_stream_playback()
		scene.elapsed = 0.625
		click_direction(scene,direction)
		await process_frame
		check(scene.elapsed==0.625 and scene.sound_player.get_stream_playback()==unchanged_playback,"same direction button does not restart animation or audio")
	for direction in [2,3,0,1]:
		send_number_key(direction,true)
		await process_frame
		check(scene.direction_index==direction and scene.elapsed==0.0,"number key changes direction and restarts timeline")
		send_number_key(direction,false)
		var unchanged_playback = scene.sound_player.get_stream_playback()
		scene.elapsed = 0.625
		send_number_key(direction,true)
		await process_frame
		check(scene.elapsed==0.625 and scene.sound_player.get_stream_playback()==unchanged_playback,"same number key preserves timeline and audio")
		send_number_key(direction,false)
	check(not scene.local_resource("../outside.png") and not scene.local_resource("/outside.png"),"clip paths stay within project")
	var invalid: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(scene.CLIPS_FILE)).clips.front.duplicate(true)
	invalid.video_duration_seconds = 0
	check(scene.load_clip(invalid,"front").is_empty(),"invalid clip duration is rejected")
	scene.ready_to_play = false
	check(scene.frame_at(0)==-1,"unavailable resources do not report a valid frame")
	scene.sound_player.stop()
	scene.queue_free()
	await process_frame
	finish()
