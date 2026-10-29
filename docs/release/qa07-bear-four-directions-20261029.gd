extends SceneTree
## Independent QA: drive the real scene tree's input; no author test helpers.
var checks := 0
var failures: Array[String] = []
var scene
var output := "/tmp/qa07-bear-four-direction-runtime.json"

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)

func close(a: float, b: float) -> bool:
	return absf(a-b)<0.00001

func send_key(code: int, pressed: bool=true, echo: bool=false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo
	Input.parse_input_event(event)

func click_button(index: int) -> void:
	var p: Vector2 = scene.direction_buttons[index].get_global_rect().get_center()
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = p
		event.global_position = p
		event.pressed = pressed
		Input.parse_input_event(event)

func independent_expected(times: Array, time: float, period: float) -> int:
	var phase := fposmod(time,period)
	for i in range(times.size()-1,-1,-1):
		if phase>=float(times[i])-0.000000001: return i
	return 0

func run() -> void:
	root.size = Vector2i(1440,810)
	scene = load("res://showcase.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	await process_frame
	check(scene.ready_to_play,"clean first start loads all clips")
	if not scene.ready_to_play:
		finish()
		return
	check(scene.direction_index==0,"default front-right")
	check(scene.direction_buttons.size()==4,"four direction controls")
	check(scene.clips.size()==2,"two independent source clips")
	var audio_nodes := 0
	for child in scene.get_children():
		if child is AudioStreamPlayer: audio_nodes += 1
	check(audio_nodes==1 and scene.sound_player.max_polyphony==1,"one monophonic player prevents overlapping old voices")
	check(not scene.has_method("resolve_combat") and not scene.has_method("start_battle"),"standalone scene has no battle entry")
	check(scene.board.get_size()==Vector2(1672,941),"approved forest board dimensions")
	var manifests := [JSON.parse_string(FileAccess.get_file_as_string("res://art/attack/manifest.json")),
		JSON.parse_string(FileAccess.get_file_as_string("res://art/back/manifest.json"))]
	var expected_counts := [20,340]
	var expected_durations := [3.5,340.0/96.0]
	var clip_records := []
	for clip_i in range(2):
		var d := clip_i*2
		click_button(d)
		await process_frame
		check(scene.direction_index==d,"mouse event selects source %d" % d)
		check(scene.frames.size()==expected_counts[clip_i],"source frame count %d" % d)
		check(close(scene.duration,expected_durations[clip_i]) and close(scene.loop_interval,.35),"clip-specific period %d" % d)
		check(scene.frame_foot==Vector2(177,213) and close(scene.display_scale,.75),"approved alignment and height %d" % d)
		check(scene.source_to_world(scene.frame_foot)==Vector2(720,441),"source foot stays on board foot %d" % d)
		check(scene.sound_player.stream==scene.clips["front" if clip_i==0 else "back"].stream,"selected clip owns its original stream %d" % d)
		check(scene.sound_player.stream.get_length()<scene.duration+.35,"audio completes before next loop %d" % d)
		var entries: Array = manifests[clip_i].frames
		var times: Array = entries.map(func(e): return e.source_time_seconds)
		var period: float = scene.duration+.35
		var texture_ids := []
		for i in entries.size():
			var t: float = times[i]
			check(scene.frame_at(t+0.0000001)==i,"source %d frame %d boundary" % [d,i])
			if i>0: check(scene.frame_at(t-0.000001)==i-1,"source %d frame %d pre-boundary" % [d,i])
			var end: float = times[i+1] if i+1<times.size() else period
			check(scene.frame_at((t+end)/2)==i,"source %d frame %d duration midpoint" % [d,i])
			texture_ids.append(scene.frames[i].get_instance_id())
		check(scene.frame_at(period-.00001)==entries.size()-1,"last frame tail hold %d" % d)
		check(scene.frame_at(period+.00001)==0,"next loop first frame %d" % d)
		for fps in [30,60,120]:
			var good := true
			for tick in range(ceili(period*2*fps)):
				var time: float = float(tick)/fps
				if scene.frame_at(time)!=independent_expected(times,time,period): good=false
			check(good,"source %d two loops at %d FPS select original timing" % [d,fps])
		var points := [Vector2.ZERO,Vector2(384,0),Vector2(0,320),Vector2(384,320),Vector2(177,213),Vector2(471,711)]
		var original_points := []
		for p in points: original_points.append(scene.source_to_world(p))
		click_button(d+1)
		await process_frame
		check(scene.direction_index==d+1 and scene.mirrored,"mouse event selects horizontal mirror %d" % d)
		check(close(scene.elapsed,0) and scene.sound_player.playing,"mirror starts picture and source audio together %d" % d)
		for i in points.size():
			var actual: Vector2 = scene.source_to_world(points[i])
			check(actual.is_equal_approx(Vector2(1440-original_points[i].x,original_points[i].y)),"mirror preserves world foot %d point %d" % [d,i])
		for i in texture_ids.size():
			check(scene.frames[i].get_instance_id()==texture_ids[i],"mirror reuses original forward-time image %d/%d" % [d,i])
		check(scene.sound_player.stream==scene.clips["front" if clip_i==0 else "back"].stream,"mirror keeps original audio %d" % d)
		for phase in [0.025,1.0,period-.01]:
			scene.elapsed = period-.01
			scene._process(period*2+.01+phase)
			await process_frame
			check(close(fposmod(scene.elapsed,period),phase),"large delta final visual phase %d/%s" % [d,phase])
			if phase<scene.sound_player.stream.get_length():
				check(scene.sound_player.playing,"new loop audio starts only latest cycle %d/%s" % [d,phase])
				check(absf(scene.sound_player.get_playback_position()-phase)<.12,"new loop audio seeks correct phase %d/%s" % [d,phase])
			else: check(not scene.sound_player.playing,"post-audio silent interval stays silent %d" % d)
		clip_records.append({"source":clip_i,"frames":entries.size(),"period":period,"audio_length":scene.sound_player.stream.get_length()})
	for index in [0,3,1,2,0,2,3,1]:
		scene.elapsed = 1.25
		send_key(KEY_1+index)
		await process_frame
		check(scene.direction_index==index,"keyboard real input selects %d" % index)
		check(close(scene.elapsed,0),"keyboard switch resets elapsed %d" % index)
		check(scene.sound_player.playing and scene.sound_player.get_playback_position()<.12,"keyboard switch resets source audio %d" % index)
		var selected := 0
		for b in scene.direction_buttons:
			if b.button_pressed: selected+=1
		check(selected==1 and scene.direction_buttons[index].button_pressed,"exactly one active button %d" % index)
		send_key(KEY_1+index,false)
	scene.elapsed = .5
	send_key(KEY_4,true,true)
	send_key(KEY_4,false)
	send_key(KEY_A)
	await process_frame
	check(scene.direction_index==1 and close(scene.elapsed,.5),"echo/release/unmapped key do not restart or switch")
	scene.select_direction(-1)
	scene.select_direction(4)
	check(scene.direction_index==1 and close(scene.elapsed,.5),"invalid direction rejected")
	for i in 20:
		click_button(i%4)
	await process_frame
	audio_nodes = 0
	for child in scene.get_children():
		if child is AudioStreamPlayer: audio_nodes += 1
	check(audio_nodes==1 and scene.sound_player.max_polyphony==1,"rapid switches keep a single non-polyphonic voice")
	scene.ready_to_play=false
	check(scene.frame_at(0)==-1,"unready assets never index old animation")
	scene.sound_player.stop()
	finish(clip_records)

func finish(records: Array=[]) -> void:
	var report := {"checks":checks,"failures":failures,"clips":records,
		"mode":"Godot headless + Dummy; scene-tree mouse/key input, no OS input or device listening"}
	var f := FileAccess.open(output,FileAccess.WRITE)
	if f!=null: f.store_string(JSON.stringify(report,"\t"))
	print("QA07_BEAR_FOUR_DIRECTION ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
