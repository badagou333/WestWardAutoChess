extends SceneTree
var out := "/tmp/qa07-c3-single-20261102/render"
var game
var checks := 0
var failures := []
var shots := []
var trace := []
var phases := []
var stops := []
var inputs := []
func ck(ok: bool, label: String):
	checks+=1
	if not ok: failures.append(label);push_error(label)
func _initialize():call_deferred("run")
func click(button: Button, label: String):
	var point:Vector2=button.get_global_rect().get_center()
	var motion=InputEventMouseMotion.new();motion.position=point;motion.global_position=point
	Input.parse_input_event(motion)
	for down in [true,false]:
		var e=InputEventMouseButton.new();e.position=point;e.global_position=point;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down
		Input.parse_input_event(e)
	Input.flush_buffered_events()
	inputs.append({"case":label,"point":[point.x,point.y],"state":game.state,"elapsed":game.elapsed,"handled":game.audio_event_handled,"sound_playing":game.sound_player.playing,"method":"Input.parse_input_event mouse motion and button down/up; no signal emit or OS mouse"})
	ck(game.state=="playing" and game.elapsed==0.0 and not game.audio_event_handled and not game.sound_player.playing,"input resets "+label)
func capture(label: String):
	var pic:Image=root.get_texture().get_image()
	var idx:int=game.current_frame_index()
	shots.append({"file":label+".png","index":idx,"elapsed":game.elapsed,"state":game.state,"pts":game.frame_ticks[idx],"source_sha256":FileAccess.get_sha256("res://art/c03/frames/frame_%06d.png"%idx),"rect":[608,269,226,226],"image":pic.get_region(Rect2i(608,269,226,226))})
	if idx==32:shots.append({"file":"viewport-normal-32.png","index":idx,"elapsed":game.elapsed,"state":game.state,"image":pic})
func mix_turns(n: int):
	var previous:float=AudioServer.get_time_since_last_mix()
	var turns:=0
	var start:=Time.get_ticks_usec()
	var rows:=[]
	while turns<n and Time.get_ticks_usec()-start<1500000:
		await process_frame
		var now:float=AudioServer.get_time_since_last_mix()
		if now<previous:turns+=1
		previous=now
		rows.append({"wall":(Time.get_ticks_usec()-start)/1000000.0,"mix_clock":now,"turns":turns})
	return {"turns":turns,"rows":rows}
func stop_test(label: String, exiting: bool):
	# Observe a genuinely advancing old cursor before requesting production stop.
	click(game.replay_button,"start "+label)
	var until:=Time.get_ticks_usec()+3000000
	while not game.sound_player.playing and Time.get_ticks_usec()<until:await process_frame
	ck(game.sound_player.playing,"active sound "+label)
	if not game.sound_player.playing:return
	var old=game.sound_player.get_stream_playback()
	var first:float=old.get_playback_position()
	until=Time.get_ticks_usec()+200000
	while old.get_playback_position()<=first and Time.get_ticks_usec()<until:await process_frame
	var advancing:float=old.get_playback_position()
	ck(advancing>first,"old cursor actually advanced "+label)
	var player_weak=weakref(game.sound_player)
	var started:=Time.get_ticks_usec()
	if exiting:
		game.queue_free();await process_frame
	else:
		click(game.replay_button,"interrupt "+label)
	var settling:Dictionary=await mix_turns(2)
	var before:float=old.get_playback_position()
	var observing:Dictionary=await mix_turns(3)
	var after:float=old.get_playback_position()
	var wall:float=(Time.get_ticks_usec()-started)/1000000.0
	ck(settling.turns==2 and observing.turns==3,"real mixer progress "+label)
	ck(before==after and after<1.0,"old cursor frozen "+label)
	ck(wall<1.0-advancing,"before natural WAV end "+label)
	if exiting:ck(player_weak.get_ref()==null,"player actually freed")
	stops.append({"case":label,"pre_first":first,"pre_advanced":advancing,"settling":settling,"observing":observing,"before":before,"after":after,"wall":wall,"remaining_at_stop":1.0-advancing,"old_is_playing_diagnostic":old.is_playing(),"old_stop_mix_seek_called":false,"player_freed":player_weak.get_ref()==null})
func run():
	if DisplayServer.get_name()=="headless":quit(2);return
	DirAccess.make_dir_recursive_absolute(out)
	root.size=Vector2i(1440,810);AudioServer.set_bus_mute(0,true)
	game=load("res://showcase.tscn").instantiate();root.add_child(game);game.set_process(false)
	ck(game.ready_to_play,"cold ready")
	ck(game.state=="ready" and not game.sound_player.playing,"ready silent")
	game._process(10.0);ck(game.elapsed==0.0 and game.state=="ready" and not game.sound_player.playing,"ready ignores time")
	ck(game.frames.size()==98 and game.canvas==Vector2(960,960) and game.foot_reference==Vector2(475,760),"count geometry")
	ck(game.display_scale==0.21 and game.world_foot==Vector2(720,441) and game.source_to_world(game.foot_reference)==Vector2(720,441),"scale world foot")
	for i in 98:
		var pic=Image.load_from_file("res://art/c03/frames/frame_%06d.png"%i)
		ck(game.frames[i].get_image().get_data()==pic.get_data(),"loaded RGBA %d"%i)
		var start:float=game.frame_ticks[i]/90000.0
		ck(game.frame_at(start)==i,"source boundary %d"%i)
		if i<97:
			var end:float=(game.frame_ticks[i]+game.source_duration_ticks[i])/90000.0
			ck(game.frame_at((start+end)*0.5)==i and game.frame_at(end-1e-9)==i,"source interval %d"%i)
	ck(game.duration==260250.0/90000.0 and game.source_duration_ticks[97]==0,"exact terminal duration")
	for t in [0.405,0.405001,0.605,1.404]:
		AudioServer.lock()
		game.play_from_start();game._process(t)
		var actual=game.sound_player.get_stream_playback()
		var ref=game.sound_player.stream.instantiate_playback();ref.start(t-0.405)
		var diff:float=absf(actual.get_playback_position()-ref.get_playback_position())
		ck(game.sound_player.playing and diff<=2.0/44100.0,"phase %s"%t)
		phases.append({"time":t,"requested_phase":t-0.405,"native_difference_seconds":diff,"tolerance":2.0/44100.0});ref.stop()
		AudioServer.unlock()
	for t in [0.404999,1.405,1.6,game.duration,2.985,10.0]:
		game.play_from_start();game._process(t)
		ck(not game.sound_player.playing,"silent boundary %s"%t)
		if t>=game.duration:ck(game.state=="ended" and game.elapsed==game.duration and game.current_frame_index()==97,"Ended exact %s"%t)
	game.play_from_start();game._process(game.duration-1e-9)
	ck(game.current_frame_index()==96 and game.state=="playing","T epsilon is 96")
	game._process(1e-9);game._process(10.0)
	ck(game.state=="ended" and game.elapsed==game.duration and game.current_frame_index()==97,"terminal stable no loop")
	for i in [0,30,31,32,97]:
		game.inspect_frame(i);game._process(10.0)
		ck(game.state=="inspection" and game.current_frame_index()==i and not game.sound_player.playing and game.audio_event_handled,"inspection silent %d"%i)
	game.queue_free();await process_frame
	# Fresh scene: normal process with engine input; no elapsed changes inside playback.
	game=load("res://showcase.tscn").instantiate();root.add_child(game)
	await process_frame;await RenderingServer.frame_post_draw
	capture("ready-0")
	click(game.play_button,"normal play")
	var seen:={}
	var last:=-1
	var audio_ids:={}
	var deadline:=Time.get_ticks_usec()+10000000
	while game.state=="playing" and Time.get_ticks_usec()<deadline:
		await RenderingServer.frame_post_draw
		var idx:int=game.current_frame_index()
		if game.sound_player.playing:audio_ids[game.sound_player.get_stream_playback().get_instance_id()]=true
		if idx!=last:trace.append({"index":idx,"elapsed":game.elapsed,"state":game.state});last=idx
		if idx in [29,30,31,32,33,34,96,97] and not seen.has(idx):capture("normal-%d"%idx)
		seen[idx]=true
	ck(game.state=="ended" and game.elapsed==game.duration and game.current_frame_index()==97,"normal Ended")
	ck(audio_ids.size()==1,"normal one sound instance")
	for i in range(29,35):ck(seen.has(i),"normal observed %d"%i)
	for i in range(29,34):
		var found:=false
		for j in range(1,trace.size()):
			if trace[j-1].index==i and trace[j].index==i+1:found=true
		ck(found,"normal adjacent %d to %d"%[i,i+1])
	await create_timer(0.15).timeout
	ck(game.state=="ended" and game.elapsed==game.duration and not game.sound_player.playing,"normal terminal stays silent")
	await stop_test("replay",false)
	# Observe reset run progressing; repeat through actual exit of an active new sound.
	await stop_test("tree-exit",true)
	for row in shots:
		ck(row.image.save_png(out.path_join(row.file))==OK,"save "+row.file);row.erase("image");row.sha256=FileAccess.get_sha256(out.path_join(row.file))
	var result={"checks":checks,"failures":failures,"phases":phases,"stops":stops,"inputs":inputs,"trace":trace,"observed_unique_indices":seen.size(),"captures":shots,"display":DisplayServer.get_name(),"adapter":RenderingServer.get_video_adapter_name(),"audio_driver":AudioServer.get_driver_name(),"master_muted":true,"os_input":false,"index_base":0}
	FileAccess.open(out.path_join("results.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("QA07_C3 checks=",checks," failures=",failures.size()," captures=",shots.size())
	quit(1 if failures.size() else 0)
