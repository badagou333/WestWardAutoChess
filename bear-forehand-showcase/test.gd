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
	check(scene.sound_player.stream!=null,"single attack sound loads")
	check(scene.get_child_count()==1 and scene.get_child(0) is AudioStreamPlayer,"no other characters or combat scene are instantiated")
	check(not scene.has_method("_attack") and not scene.has_method("_resolve"),"display has no combat or damage logic")
	check(is_equal_approx(scene.duration,0.82) and is_equal_approx(scene.impact,0.389),"original candidate timing loads")
	check(scene.frame_foot==Vector2(177,213) and scene.DISPLAY_SCALE>0,"single foot anchor and positive non-mirrored scale")
	check(scene.frame_at(0)==0 and scene.frame_at(scene.HOLD-0.01)==0,"initial matching first frame is held during interval")
	for i in scene.frame_times.size():
		check(scene.frame_at(scene.HOLD+scene.frame_times[i]+0.0001)==i,"candidate frame %d is reachable in order" % i)
	check(scene.frame_at(scene.HOLD+scene.duration-0.001)==19,"last frame is shown before loop")
	check(scene.frame_at(scene.HOLD+scene.duration+0.001)==0,"loop returns to the same character's initial frame")
	scene.ready_to_play = false
	check(scene.frame_at(0)==-1,"invalid or missing resources do not report a successful frame")
	scene.free()
	print("BEAR_SHOWCASE ",checks," checks / ",failures," failures")
	quit(1 if failures else 0)
