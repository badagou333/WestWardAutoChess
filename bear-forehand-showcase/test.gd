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
	var scene = load("res://showcase.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	check(scene.ready_to_play and scene.frames.size()==20,"twenty actual attack frames load")
	check(scene.sound_player.stream!=null,"source video soundtrack loads")
	check(scene.sound_player.stream.get_length()>3.6 and scene.sound_player.stream.get_length()<scene.duration+scene.LOOP_INTERVAL,"source soundtrack fits once within each loop")
	check(scene.sound_player.playing,"source audio starts alongside first frame")
	check(scene.get_child_count()==1 and scene.get_child(0) is AudioStreamPlayer,"no other characters or combat scene are instantiated")
	check(not scene.has_method("_attack") and not scene.has_method("_resolve"),"display has no combat or damage logic")
	check(is_equal_approx(scene.duration,3.5) and is_equal_approx(scene.impact,1.716667),"source video duration and sound frame time load")
	check(scene.frame_foot==Vector2(177,213) and is_equal_approx(scene.DISPLAY_SCALE,0.75),"single foot anchor and matched positive scale")
	check(scene.FOOT==Vector2(720,441) and scene.GRID_HALF==Vector2(72,36),"forest board cell and anchor match reference geometry")
	check(scene.board!=null and scene.board.get_size()==Vector2(1672,941),"reference forest background loads")
	for foot in [Vector2(147,224),Vector2(207,203)]:
		var local:Vector2=(foot-scene.frame_foot)*scene.DISPLAY_SCALE
		check(absf(local.x)/scene.GRID_HALF.x+absf(local.y)/scene.GRID_HALF.y<1.0,"candidate first-frame foot point is within the highlighted cell")
	check(scene.frame_at(0)==0 and scene.frame_at(0.633332)==0,"first frame remains until source second frame")
	for i in scene.frame_times.size():
		check(scene.frame_at(scene.frame_times[i]+0.000001)==i,"candidate frame %d begins at source timestamp" % i)
		if i>0: check(scene.frame_at(scene.frame_times[i]-0.000001)==i-1,"frame %d does not appear before source timestamp" % i)
	check(scene.frame_at(scene.duration-0.001)==19,"last frame is shown through the video ending")
	check(scene.frame_at(scene.duration+scene.LOOP_INTERVAL-0.001)==19,"last frame holds through the added loop interval")
	check(scene.frame_at(scene.duration+scene.LOOP_INTERVAL+0.001)==0,"loop returns to the same character's initial frame")
	scene.ready_to_play = false
	check(scene.frame_at(0)==-1,"invalid or missing resources do not report a successful frame")
	scene.sound_player.stop()
	scene.free()
	print("BEAR_SHOWCASE ",checks," checks / ",failures," failures")
	quit(1 if failures else 0)
