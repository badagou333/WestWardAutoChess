extends SceneTree
var out := "/tmp/qa07-bear-front-v3-20261102/render"
var failures := []
var checks := 0
var captures := []
var traces := []
var audio_checks := []
var wanted := [37,38,42,43,44,45,48,49,50,51,52,84,1]
func check(ok: bool, label: String):
	checks += 1
	if not ok: failures.append(label)
func _initialize(): call_deferred("run")
func run():
	if DisplayServer.get_name()=="headless": quit(2);return
	DirAccess.make_dir_recursive_absolute(out)
	root.size=Vector2i(1440,810)
	AudioServer.set_bus_mute(0,true)
	var game=load("res://showcase.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	check(game.ready_to_play,"cold ready")
	check(FileAccess.get_sha256("res://art/attack/manifest.json")=="53f2cd27b2678282ae8e8fa905b4ce8e46cded2623a7b9384e1c870c3b3e2237","loaded v3 manifest")
	for i in 84:
		var img=Image.load_from_file("res://art/attack/attack_%04d.png"%(i+1))
		check(game.frames[i].get_image().get_data()==img.get_data(),"loaded pixels %d"%(i+1))
	for direction in [0,1]:
		game.select_direction(direction)
		check(game.frames.size()==84 and game.duration==3.0 and game.loop_interval==0.0,"front timing")
		check(game.canvas==Vector2(400,320) and game.frame_foot==Vector2(177,213) and game.display_scale==0.75,"geometry")
		check(game.source_to_world(game.frame_foot)==Vector2(720,441),"foot fixed")
		check(game.mirrored==(direction==1),"mirror")
		for t in [2.9499,2.95,2.9999,3.0]:
			check(game.frame_at(t)==(82 if t<2.95 else (83 if t<3 else 0)),"final boundary %s"%t)
	# A lightweight native reference test; compares requested phase without asynchronous device cursor claims.
	for direction in [2,0,3,1]:
		AudioServer.lock()
		var previous=game.sound_player.get_stream_playback()
		game.select_direction(direction)
		var playback=game.sound_player.get_stream_playback()
		var ref=game.sound_player.stream.instantiate_playback()
		ref.start(0.0)
		var diff=absf(playback.get_playback_position()-ref.get_playback_position())
		var rate:float=game.sound_player.stream.mix_rate
		check(game.elapsed==0.0 and playback!=previous and diff<=2.0/rate,"switch restart %d"%direction)
		audio_checks.append({"direction":direction,"diff_seconds":diff,"tolerance_seconds":2.0/rate,"new_playback":playback!=previous})
		ref.stop()
		AudioServer.unlock()
	# Native rendering during unmodified normal process(delta). No seeking/pausing within each 6.1s run.
	for direction in [0,1]:
		game.select_direction(direction)
		var observed := {}
		var trace := []
		var last := -1
		var previous_time := 0.0
		var max_delta := 0.0
		game.set_process(true)
		while game.elapsed<6.1:
			await RenderingServer.frame_post_draw
			var t:float=game.elapsed
			max_delta=maxf(max_delta,t-previous_time);previous_time=t
			var frame:int=game.frame_at(t)+1
			if frame!=last:
				trace.append({"elapsed":t,"frame":frame,"cycle":floori(t/3.0)})
				last=frame
			if frame in wanted and not observed.has(frame):
				var picture:Image=root.get_texture().get_image()
				var a:Vector2=game.source_to_world(Vector2.ZERO)
				var b:Vector2=game.source_to_world(game.canvas)
				var rect=Rect2i(floori(minf(a.x,b.x))-12,floori(a.y)-12,325,265)
				var name="front-%d-frame-%04d.png"%[direction,frame]
				observed[frame]=true
				captures.append({"direction":direction,"frame":frame,"original_frame":frame+9,"elapsed":t,"file":name,"crop_rect":[rect.position.x,rect.position.y,325,265],"source_sha256":FileAccess.get_sha256("res://art/attack/attack_%04d.png"%frame),"image":picture.get_region(rect)})
				if direction==0 and frame==44:
					captures.append({"direction":direction,"frame":frame,"elapsed":t,"file":"viewport-front-right-44.png","image":picture})
		game.set_process(false)
		for frame in wanted:check(observed.has(frame),"normal capture dir%d frame%d"%[direction,frame])
		for pair in [[37,38],[42,43],[49,50],[50,51],[51,52],[84,1]]:
			var found := false
			for j in range(1,trace.size()):
				if trace[j-1].frame==pair[0] and trace[j].frame==pair[1]:found=true
			check(found,"normal adjacency dir%d %s"%[direction,pair])
		traces.append({"direction":direction,"elapsed":game.elapsed,"max_render_delta":max_delta,"frame_changes":trace})
	game.sound_player.stop()
	for sample in captures:
		check(sample.image.save_png(out.path_join(sample.file))==OK,"save "+sample.file)
		sample.erase("image")
		sample.sha256=FileAccess.get_sha256(out.path_join(sample.file))
	game.queue_free();await process_frame
	var result={"checks":checks,"failures":failures,"display":DisplayServer.get_name(),"adapter":RenderingServer.get_video_adapter_name(),"viewport":[1440,810],"audio":"Dummy; Master muted","normal_playback":true,"seeking_within_normal_runs":false,"captures":captures,"traces":traces,"audio_checks":audio_checks,"device_listening_or_os_input":false}
	FileAccess.open(out.path_join("results.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("QA07_V3 checks=",checks," failures=",failures.size()," captures=",captures.size())
	quit(1 if failures.size() else 0)
