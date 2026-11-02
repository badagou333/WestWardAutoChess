extends SceneTree
var checks:=0
var failures:Array[String]=[]
var cases:=[]
var output:="/tmp/qa07-bear-front-v2-20261102/own-runtime.json"
var oracle_path:="/tmp/qa07-bear-front-v2-20261102/oracle.json"
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
	checks+=1
	if not ok and failures.size()<30:failures.append(label)
func compare_audio(scene,phase:float,previous,label:String):
	check(scene.sound_player.playing,label+" currently plays")
	if not scene.sound_player.playing:return
	var actual=scene.sound_player.get_stream_playback()
	var reference=scene.sound_player.stream.instantiate_playback()
	reference.start(phase)
	var delta:float=actual.get_playback_position()-reference.get_playback_position()
	check(actual!=previous,label+" old playback replaced")
	check(absf(delta)<=2.0/scene.sound_player.stream.mix_rate,label+" native equal-phase quantization")
	cases.append({"case":label,"phase":phase,"actual":actual.get_playback_position(),"reference":reference.get_playback_position(),"delta":delta,"rate":scene.sound_player.stream.mix_rate})
	reference.stop()
func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	root.size=Vector2i(1440,810)
	var scene=load("res://showcase.tscn").instantiate();root.add_child(scene);scene.set_process(false)
	var oracle=JSON.parse_string(FileAccess.get_file_as_string(oracle_path))
	check(scene.ready_to_play and oracle.frames.size()==84,"real cold scene and independently decoded oracle available")
	if not scene.ready_to_play:quit(1);return
	var boundaries:Array=oracle.frames
	var counts=[]
	for direction in [0,1]:
		scene.select_direction(direction)
		check(scene.canvas==Vector2(400,320) and scene.frame_foot==Vector2(177,213) and scene.display_scale==.75 and scene.FOOT==Vector2(720,441),"front exact canvas/anchor/scale")
		for p in [Vector2.ZERO,Vector2(177,213),Vector2(399,319),Vector2(390,150)]:
			var expected:Vector2=Vector2(720,441)+(p-Vector2(177,213))*Vector2(.75 if direction==0 else -.75,.75)
			check(scene.source_to_world(p)==expected,"entire 400 canvas mirrors about same anchor")
		for cycle in [0,1,11,10000]:
			var observed=[];observed.resize(84);observed.fill(0)
			var expected_index:=0
			for tick in 46080:
				while expected_index<83 and tick>=int(boundaries[expected_index+1].pts):expected_index+=1
				var actual:int=scene.frame_at(cycle*3.0+(tick+.25)/15360.0)
				check(actual==expected_index,"every source tick exact VFR occupancy")
				if actual>=0 and actual<84:observed[actual]+=1
			for i in 84:check(observed[i]==int(boundaries[i].duration),"each frame exact duration across complete cycles")
			check(scene.frame_at((cycle+1)*3.0)==0 and scene.frame_at((cycle+1)*3.0-1e-6)==83,"zero added interval; 84 -> 1 at exact cycle")
			counts.append({"direction":direction,"cycle":cycle,"duration_ticks":observed})
		for i in range(1,84):
			var t:float=float(boundaries[i].pts)/15360.0
			check(scene.frame_at(t-1e-6)==i-1 and scene.frame_at(t)==i and scene.frame_at(t+1e-6)==i,"subframe boundary exact side "+str(i+1))
		check(scene.frame_at(2.95)==83 and scene.frame_at(2.999999)==83 and scene.frame_at(3)==0,"last 0.05 sec no added hold")
	# Actual native playback under a brief audio-driver lock; no device-output claim.
	for direction in [3,0,2,1,0]:
		var previous=scene.sound_player.get_stream_playback() if scene.sound_player.playing else null
		AudioServer.lock();scene.select_direction(direction);compare_audio(scene,0.0,previous,"switch "+str(direction));AudioServer.unlock()
		var same=scene.sound_player.get_stream_playback();scene.elapsed=.231
		scene.select_direction(direction)
		check(scene.elapsed==.231 and scene.sound_player.get_stream_playback()==same,"same direction never restarts")
	var period:float=scene.duration+scene.loop_interval
	for phase in [1.0/44100,0.123456,1.711,2.95]:
		scene.elapsed=.25
		var previous=scene.sound_player.get_stream_playback()
		AudioServer.lock();scene._process(1000*period+phase-.25);compare_audio(scene,phase,previous,"1000-cycle jump "+str(phase));AudioServer.unlock()
		check(absf(fposmod(scene.elapsed,period)-phase)<1e-10,"multi-cycle elapsed keeps current phase without repeated past loops")
	# The 20-sample short tail is not padded or extended; a jump into it stays silent.
	scene.elapsed=0
	scene._process(3003+2.9998)
	check(not scene.sound_player.playing and scene.frame_at(scene.elapsed)==83,"jump into 0.454ms front audio gap stops old sound and holds last actual frame")
	scene._process(.0002)
	check(scene.sound_player.playing and scene.frame_at(scene.elapsed)==0,"next front cycle restarts frame and original audio")
	scene.select_direction(2)
	check(scene.frames.size()==340 and scene.duration==85.0/24 and scene.loop_interval==.35,"back source duration and interval retained")
	var back_period:float=scene.duration+scene.loop_interval
	scene.elapsed=0;scene._process(5*back_period+3.7)
	check(not scene.sound_player.playing and scene.frame_at(scene.elapsed)==339,"back actual silent tail retains last frame without old sound")
	check(scene.get_children().filter(func(n):return n is AudioStreamPlayer).size()==1,"single real audio player")
	cases.append({"case":"tick_exact_VFR","tested_ticks":368640,"cycles":counts})
	scene.sound_player.stop();scene.queue_free();await process_frame
	var f=FileAccess.open(output,FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"failures":failures,"cases":cases,"headless_Dummy_only":true},"\t"))
	print("QA07_FRONT_V2 ",checks," checks / ",failures.size()," failures ",failures)
	quit(1 if failures.size() else 0)
