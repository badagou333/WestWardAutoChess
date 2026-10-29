extends SceneTree
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

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
		print("BEAR_FOUR_DIRECTION ",checks," checks / ",failures," failures")
		quit(1)
		return
	check(scene.direction_index==0 and not scene.mirrored,"default remains right-front")
	check(scene.direction_buttons.size()==4,"four direction controls exist")
	check(scene.FOOT==Vector2(720,441) and scene.GRID_HALF==Vector2(72,36),"same forest board grid")
	check(scene.board!=null and scene.board.get_size()==Vector2(1672,941),"same reference forest board loads")
	check(scene.clips.front.frames.size()==20 and is_equal_approx(scene.clips.front.duration,3.5),"front twenty-frame video timing is retained")
	check(scene.clips.front.foot==Vector2(177,213) and is_equal_approx(scene.clips.front.scale,0.75),"front scale and source foot are retained")
	check(scene.clips.front.stream.stereo and scene.clips.back.stream.stereo,"original stereo tracks remain stereo")
	var audio_nodes := 0
	for child in scene.get_children():
		if child is AudioStreamPlayer: audio_nodes += 1
	check(audio_nodes==1,"one shared audio player prevents multiple voices")
	check(not scene.has_method("_attack") and not scene.has_method("_resolve"),"no combat or damage methods")
	var anchors := []
	var pairs := {}
	for direction in range(4):
		scene.select_direction(direction)
		check(scene.direction_index==direction and scene.elapsed==0.0,"direction switch restarts its timeline")
		check(scene.sound_player.playing,"source audio starts with its first frame")
		check(scene.sound_player.get_playback_position()<0.1,"direction switch restarts audio at the beginning")
		check(scene.source_to_world(scene.frame_foot)==scene.FOOT,"source foot maps to same world foot")
		check(scene.direction_buttons[direction].button_pressed,"selected direction button tracks state")
		var pressed_count := 0
		for button in scene.direction_buttons:
			if button.button_pressed: pressed_count += 1
		check(pressed_count==1,"exactly one direction is selected")
		var clip_id: String = scene.DIRECTIONS[direction].clip
		var clip: Dictionary = scene.clips[clip_id]
		check(scene.sound_player.stream==clip.stream,"direction uses its own source track")
		check(scene.mirrored==(int(scene.DIRECTIONS[direction].sign)!=int(clip.source_sign)),"only opposite horizontal direction is mirrored")
		check(scene.sound_player.stream.get_length()<=scene.duration+scene.loop_interval+0.001,"audio ends within the loop")
		var manifest = JSON.parse_string(FileAccess.get_file_as_string(clip.manifest_path))
		check(scene.frames.size()==manifest.frames.size(),"every manifest timestamp remains represented")
		var texture_ids := {}
		var names := {}
		for i in scene.frame_times.size():
			var at: float = scene.frame_times[i]
			check(is_equal_approx(at,float(manifest.frames[i].source_time_seconds)),"source frame timestamp matches")
			check(scene.frame_at(at+0.000001)==i,"frame begins at source timestamp")
			if i>0: check(scene.frame_at(at-0.000001)==i-1,"frame does not appear before source timestamp")
			check(scene.frames[i].get_size()==scene.canvas,"fixed canvas for each frame")
			texture_ids[scene.frames[i].get_instance_id()] = true
			names[manifest.frames[i].file] = true
		check(texture_ids.size()==names.size(),"repeated source-image references reuse one texture")
		check(scene.frame_at(scene.duration-0.00001)==scene.frames.size()-1,"last frame covers video end")
		check(scene.frame_at(scene.duration+scene.loop_interval-0.00001)==scene.frames.size()-1,"last frame covers loop gap")
		check(scene.frame_at(scene.duration+scene.loop_interval+0.00001)==0,"loop restarts from the first frame")
		var off: Vector2 = scene.source_to_world(scene.frame_foot+Vector2(13,9))-scene.FOOT
		if not pairs.has(clip_id): pairs[clip_id] = {"offset":off,"frames":scene.frames,"stream":scene.sound_player.stream}
		else:
			check(is_equal_approx(off.x,-pairs[clip_id].offset.x) and is_equal_approx(off.y,pairs[clip_id].offset.y),"mirror is horizontal around the foot, with no vertical drift")
			check(scene.frames[0]==pairs[clip_id].frames[0] and scene.sound_player.stream==pairs[clip_id].stream,"mirror reuses original texture and unaltered audio")
		var period: float = scene.duration+scene.loop_interval
		scene.elapsed = period-0.01
		scene._process(0.02)
		check(scene.sound_player.playing and scene.frame_at(scene.elapsed)==0,"loop boundary restarts sound and first frame")
		if scene.sound_player.stream.get_length()<period-0.01:
			scene.elapsed = period-0.01
			scene._process(scene.sound_player.stream.get_length()+0.02)
			check(not scene.sound_player.playing,"time jump into silent tail does not play a late duplicate track")
		# Choosing the already selected button is a no-op, not an extra audio trigger.
		var prior: float = scene.elapsed
		scene.select_direction(direction)
		check(scene.elapsed==prior,"reselecting same direction does not interrupt playback")
	# Exercise actual Control input dispatch in the SceneTree; no OS mouse is moved.
	for direction in [3,1,2,0]:
		var location: Vector2 = scene.direction_buttons[direction].get_global_rect().get_center()
		var down := InputEventMouseButton.new()
		down.button_index = MOUSE_BUTTON_LEFT
		down.pressed = true
		down.position = location
		Input.parse_input_event(down)
		var up := InputEventMouseButton.new()
		up.button_index = MOUSE_BUTTON_LEFT
		up.pressed = false
		up.position = location
		Input.parse_input_event(up)
		await process_frame
		check(scene.direction_index==direction,"direction button responds to pointer input")
	for direction in [2,3,0,1]:
		var key := InputEventKey.new()
		key.keycode = [KEY_1,KEY_2,KEY_3,KEY_4][direction]
		key.pressed = true
		Input.parse_input_event(key)
		await process_frame
		check(scene.direction_index==direction,"number key changes direction")
		key.pressed = false
		Input.parse_input_event(key)
	check(not scene.local_resource("../outside.png") and not scene.local_resource("/outside.png"),"clip paths stay within project")
	var invalid: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(scene.CLIPS_FILE)).clips.front.duplicate(true)
	invalid.video_duration_seconds = 0
	check(scene.load_clip(invalid,"front").is_empty(),"invalid clip duration is rejected")
	scene.ready_to_play = false
	check(scene.frame_at(0)==-1,"unavailable resources do not report a valid frame")
	scene.sound_player.stop()
	scene.queue_free()
	await process_frame
	print("BEAR_FOUR_DIRECTION ",checks," checks / ",failures," failures")
	quit(1 if failures else 0)
