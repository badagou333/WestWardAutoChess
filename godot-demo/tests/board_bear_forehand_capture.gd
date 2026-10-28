extends SceneTree
## Explicit graphical capture for human review. Not an acceptance test.
var output := "/tmp/board-bear-forehand-render"
var game
var samples: Array = []

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	call_deferred("run")

func capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := output.path_join(label+".png")
	var result := image.save_png(path)
	if result != OK:
		push_error("Cannot save rendered viewport: "+path)
		quit(1)
		return
	var bear: Dictionary = game._record("E7")
	var victim: Dictionary = game._record(game.trial_target)
	var view = bear.node.presentation
	samples.append({"file":path,"elapsed":game.elapsed,"pose":view.pose,"pose_time":view.pose_time,
		"candidate_frame":view.trial_frame(),"sign":view.direction_sign,"back":view.direction_back,
		"target":game.trial_target,"target_health":victim.node.health,"board_scale":bear.node.scale.x,
		"candidate_scale":view.trial_track.scale,"foot":view.trial_track.foot})

func run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Graphical renderer required; headless output cannot establish actual appearance.")
		quit(1)
		return
	if DirAccess.make_dir_recursive_absolute(output)!=OK:
		push_error("Cannot create output directory: "+output)
		quit(1)
		return
	root.size = Vector2i(1440,810)
	game = load("res://scenes/board_bear_forehand_trial.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.audio_feedback.enabled = false
	if not game.trial_track_ready or game.trial_target.is_empty():
		push_error("Trial assets or rightward target are unavailable.")
		quit(1)
		return
	await capture("01-idle")
	game.start_battle()
	game.step(0.20)
	await capture("02-windup")
	game.step(0.20)
	await capture("03-impact")
	game.step(0.30)
	await capture("04-follow-through")
	var file := FileAccess.open(output.path_join("capture.json"),FileAccess.WRITE)
	if file == null:
		push_error("Cannot save capture report")
		quit(1)
		return
	file.store_string(JSON.stringify({"scope":"pending visual review, real viewport, no sound audition","samples":samples},"\t"))
	file.close()
	print("BEAR_FOREHAND_CAPTURE ",output," ",samples.size()," frames")
	quit(0)
