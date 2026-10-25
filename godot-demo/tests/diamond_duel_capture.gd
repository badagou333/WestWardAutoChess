extends SceneTree
## Captures only genuinely rendered production viewport frames. No compositing,
## desktop automation, system pointer changes or device audio are performed.
const SCENE := "res://scenes/diamond_duel.tscn"
const STEP := 1.0/120.0
var game
var output := "/tmp/diamond-duel-runtime"
var records: Array=[]

func _initialize() -> void: call_deferred("run")

func capture(name: String) -> void:
	game._update_ui()
	game.queue_redraw()
	if is_instance_valid(game.board_overlay): game.board_overlay.queue_redraw()
	for item in game.actors:
		if is_instance_valid(item.node): item.node.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image()
	var error:=image.save_png(output+"/"+name+".png")
	var actors: Array=[]
	for item in game.actors:
		actors.append({"id":item.id,"cell":[item.cell.x,item.cell.y],"foot":[item.node.position.x,item.node.position.y],"frame":item.node.presentation.frame_id,"pose":item.node.presentation.pose,"pose_time":item.node.presentation.pose_time,"hp":item.node.health,"moving":not item.move.is_empty()})
	records.append({"name":name,"saved":error==OK,"time":game.elapsed,"phase":game.phase,"viewport":[image.get_width(),image.get_height()],"actors":actors})

func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output=argument.trim_prefix("--output=")
	if DisplayServer.get_name()=="headless":
		push_error("Actual screenshot capture requires the authorized dedicated graphical window; headless is not a substitute")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(1440,810)
	root.title="D002 菱格对打测试 · 专用取证"
	game=load(SCENE).instantiate()
	root.add_child(game)
	game.set_process(false)
	game.audio_feedback.enabled=false
	for i in range(3): await process_frame
	await capture("01-deployment")
	game.start_battle()
	var walk_done:=false
	var attack_done:=false
	var contact_done:=false
	while game.phase==game.Phase.BATTLE and game.elapsed<60:
		game.step(STEP)
		if not walk_done and game.actors.any(func(item): return not item.move.is_empty() and float(item.move.time)>.2):
			await capture("02-approaching")
			walk_done=true
		if not attack_done and game.actors.any(func(item): return item.node.presentation.pose=="basic_attack" and item.node.presentation.pose_time>.08):
			await capture("03-attack-windup")
			attack_done=true
		if not contact_done and game.combat.counts.hits>0:
			await capture("04-actual-contact")
			contact_done=true
	await capture("05-result")
	var file:=FileAccess.open(output+"/capture.json",FileAccess.WRITE)
	if file!=null:
		file.store_string(JSON.stringify({"scope":"D002 actual production viewport capture","device_audio":false,"OS_mouse":false,"offline_composite":false,"dedicated_title":root.title,"records":records,"report":game.report()},"\t"))
	print("DIAMOND_DUEL_CAPTURE frames=",records.size()," result=",game.phase==game.Phase.RESULT," output=",output)
	quit(0 if game.phase==game.Phase.RESULT and records.all(func(row): return row.saved) else 1)
