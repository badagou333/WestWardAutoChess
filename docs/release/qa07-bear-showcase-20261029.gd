extends SceneTree
var checks:=0
var failures:=0
func _initialize(): call_deferred("run")
func check(ok:bool, note:String):
	checks+=1
	if not ok:
		failures+=1
		printerr("QA07_SINGLE_BEAR FAIL ",note)
func run():
	check(ProjectSettings.get_setting("application/run/main_scene")=="res://showcase.tscn","separate default scene")
	var scene=load("res://showcase.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	check(scene.ready_to_play and scene.frames.size()==20,"load real frames")
	check(scene.get_child_count()==1 and scene.get_child(0) is AudioStreamPlayer,"one root drawing and one audio player")
	check(scene.sound_player.stream!=null,"audio loaded")
	check(not scene.has_method("_attack") and not scene.has_method("_resolve") and not scene.has_method("start_battle"),"no combat")
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://art/attack/manifest.json"))
	check(manifest.frames.size()==20 and manifest.impact_index==11.0,"manifest actual index")
	check(is_equal_approx(scene.HOLD,0.7) and is_equal_approx(scene.duration,0.82),"loop period")
	var period:float=scene.HOLD+scene.duration
	var hits:=0
	for i in 20:
		var f:Dictionary=manifest.frames[i]
		var next:float=manifest.frames[i+1].at if i<19 else scene.duration
		var mid:float=scene.HOLD+(float(f.at)+next)/2
		check(scene.frame_at(mid)==i,"frame %d"%i)
		check(scene.frame_at(mid+period)==i,"repeat frame %d"%i)
		check(scene.frames[i].get_size()==Vector2(384,320),"frame canvas %d"%i)
		check(scene.frames[i].get_image().get_used_rect().has_area(),"frame nonempty %d"%i)
	for frame_rate in [30,60,120]:
		var seen:={}
		for tick in range(ceili(period*frame_rate)):
			seen[scene.frame_at(float(tick)/frame_rate)]=true
		check(seen.size()==20,"all frames reached at %d fps"%frame_rate)
	check(scene.frame_at(0)==0 and scene.frame_at(scene.HOLD-0.001)==0,"first frame held")
	check(scene.frame_at(period-0.001)==19 and scene.frame_at(period+0.001)==0,"loop boundary")
	var sound=scene.sound_player
	sound.stop()
	scene.elapsed=0
	scene._process(scene.HOLD+scene.impact-0.001)
	check(not sound.playing,"sound silent before first impact")
	scene._process(0.002)
	check(sound.playing,"sound starts at first impact")
	sound.stop()
	scene._process(period-0.002)
	check(not sound.playing,"no repeated sound before next impact")
	scene._process(0.002)
	check(sound.playing,"sound starts on next loop impact")
	sound.stop()
	sound.stream=null
	check(scene.frame_foot==Vector2(177,213) and scene.DISPLAY_SCALE==2.0,"fixed nonmirrored frame anchor")
	var top:Vector2=scene.board_point(Vector2(0,0))
	var bottom:Vector2=scene.board_point(Vector2(12,7))
	check(scene.FOOT.x>top.x and scene.FOOT.x<bottom.x and scene.FOOT.y>top.y and scene.FOOT.y<bottom.y,"bear anchor within board bounds")
	scene.ready_to_play=false
	check(scene.frame_at(1.0)==-1,"missing asset signals no frame")
	scene.free()
	await create_timer(0.1).timeout
	print("QA07_SINGLE_BEAR checks=",checks," failures=",failures)
	quit(1 if failures else 0)
