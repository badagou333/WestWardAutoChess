extends SceneTree
var out:="/tmp/qa07-bear-front-v2-20261102/boundary-render"
var rows:=[]
var failures:=[]
func _initialize():call_deferred("run")
func run():
	if DisplayServer.get_name()=="headless":quit(2);return
	DirAccess.make_dir_recursive_absolute(out)
	root.size=Vector2i(1440,810)
	AudioServer.set_bus_mute(0,true)
	var game=load("res://showcase.tscn").instantiate();root.add_child(game);game.set_process(false)
	await process_frame
	for direction in [0,1]:
		game.select_direction(direction);game.sound_player.stop()
		for t in [2.9999,3.0]:
			game.elapsed=t;game.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
			var frame:int=game.frame_at(t);var expected:=83 if t<3 else 0
			if frame!=expected:failures.append("boundary frame mismatch")
			var pic:Image=root.get_texture().get_image()
			var a:Vector2=game.source_to_world(Vector2.ZERO);var z:Vector2=game.source_to_world(game.canvas)
			var left:=floori(minf(a.x,z.x))-12;var top:=floori(minf(a.y,z.y))-12
			var right:=ceili(maxf(a.x,z.x))+12;var bottom:=ceili(maxf(a.y,z.y))+12
			var rect:=Rect2i(left,top,right-left,bottom-top)
			var name:="front-%s-%s-frame-%s.png"%[direction,str(t),frame+1]
			if pic.get_region(rect).save_png(out.path_join(name))!=OK:failures.append("crop save")
			if direction==0 and t==3.0:
				if pic.save_png(out.path_join("viewport-loop-start.png"))!=OK:failures.append("full save")
			rows.append({"direction":direction,"elapsed":t,"source_frame":frame+1,"original_source_frame":frame+10,"source_file_sha256":FileAccess.get_sha256("res://art/attack/attack_%04d.png"%(frame+1)),"frame":frame,"crop_rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],"file":name,"sha256":FileAccess.get_sha256(out.path_join(name)),"foot":[720,441],"mirrored":game.mirrored})
	game.sound_player.stop();game.queue_free();await process_frame
	var f=FileAccess.open(out.path_join("capture.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"display_server":DisplayServer.get_name(),"renderer":RenderingServer.get_video_adapter_name(),"viewport":[1440,810],"samples":rows,"failures":failures,"audio":"Dummy and Master muted","boundary":"actual engine draw at elapsed 2.9999 / 3.0; no interpolated/offline compositing","device_listening_or_OS_mouse":false},"\t"))
	print("QA07_BOUNDARY_CAPTURE samples=",rows.size()," failures=",failures.size())
	quit(1 if failures.size() else 0)
