extends SceneTree
const EXPECTED = [0.0,0.633333,0.916667,1.0,1.104167,1.158333,1.25,1.333333,1.466667,1.55,1.583333,1.716667,1.75,1.883333,2.55,2.716667,2.833333,3.0,3.166667,3.466667]
var checks:=0
var failures:=0
func _initialize(): call_deferred("run")
func check(ok:bool,note:String):
	checks+=1
	if not ok:
		failures+=1
		printerr("QA07_BEAR_TIMING FAIL ",note)
func run():
	check(ProjectSettings.get_setting("application/run/main_scene")=="res://showcase.tscn","separate default scene")
	var scene=load("res://showcase.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	check(scene.ready_to_play and scene.frames.size()==20,"20 real frames loaded")
	check(scene.get_child_count()==1 and scene.get_child(0) is AudioStreamPlayer,"one drawing scene and one audio player")
	check(not scene.has_method("_attack") and not scene.has_method("start_battle"),"no battle")
	check(scene.sound_player.stream!=null,"audio loaded")
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://art/attack/manifest.json"))
	check(manifest.frames.size()==20 and int(manifest.impact_index)==11,"manifest frame count and proposed marker")
	check(is_equal_approx(scene.duration,3.5),"video track duration")
	check(is_equal_approx(scene.LOOP_INTERVAL,0.35),"explicit interval at end")
	var period:float=scene.duration+scene.LOOP_INTERVAL
	for i in 20:
		var f:Dictionary=manifest.frames[i]
		var t:float=EXPECTED[i]
		var end:float=EXPECTED[i+1] if i<19 else scene.duration
		check(absf(float(f.source_time_seconds)-t)<0.000001,"manifest original timestamp %d"%i)
		check(absf(scene.frame_times[i]-t)<0.000001,"scene original timestamp %d"%i)
		check(scene.frame_at(t+0.000001)==i,"frame at original time %d"%i)
		check(scene.frame_at((t+end)/2.0)==i,"frame held to next original time %d"%i)
		check(scene.frame_at(t+period+0.000001)==i,"same frame next loop %d"%i)
		if i>0: check(scene.frame_at(t-0.000001)==i-1,"previous frame immediately before boundary %d"%i)
		check(scene.frames[i].get_size()==Vector2(384,320),"frame dimensions %d"%i)
		check(scene.frames[i].get_image().get_used_rect().has_area(),"nonempty frame %d"%i)
	for frame_rate in [30,60,120]:
		var seen:={}
		for tick in range(ceili(period*frame_rate)):
			seen[scene.frame_at(float(tick)/frame_rate)]=true
		check(seen.size()==20,"all frames reached at %d FPS"%frame_rate)
	check(scene.frame_at(0)==0,"starts at first frame")
	check(scene.frame_at(3.499999)==19,"end-of-video frame")
	check(scene.frame_at(3.5)==19 and scene.frame_at(period-0.001)==19,"last frame holds over interval")
	check(scene.frame_at(period+0.000001)==0,"loop returns to first frame")
	check(absf(scene.impact-1.716667)<0.000001,"sound event at selected source frame index 11")
	var sound=scene.sound_player
	sound.stop()
	scene.elapsed=0
	scene._process(scene.impact-0.001)
	check(not sound.playing,"sound silent before first impact")
	scene._process(0.002)
	check(sound.playing,"sound starts at first impact")
	sound.stop()
	scene._process(period-0.002)
	check(not sound.playing,"no repeated sound before next impact")
	scene._process(0.002)
	check(sound.playing,"sound starts at next loop impact")
	sound.stop()
	sound.stream=null
	check(scene.frame_foot==Vector2(177,213) and scene.DISPLAY_SCALE==2.0,"fixed nonmirrored anchor")
	var top:Vector2=scene.board_point(Vector2(0,0))
	var bottom:Vector2=scene.board_point(Vector2(12,7))
	check(scene.FOOT.x>top.x and scene.FOOT.x<bottom.x and scene.FOOT.y>top.y and scene.FOOT.y<bottom.y,"bear anchor within board bounds")
	scene.ready_to_play=false
	check(scene.frame_at(1.0)==-1,"missing resource signals no frame")
	scene.free()
	await create_timer(0.1).timeout
	print("QA07_BEAR_TIMING checks=",checks," failures=",failures)
	quit(1 if failures else 0)
