extends SceneTree
const Config = preload("res://scripts/data/board_trial_config.gd")
var game
var failures := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)
func _initialize() -> void: call_deferred("run")
func frames() -> void:
	for i in range(3): await process_frame
func settle(point: Vector2) -> void:
	root.grab_focus()
	await process_frame
	root.warp_mouse(point)
	var began := Time.get_ticks_msec()
	var stable := 0
	while stable<3 and Time.get_ticks_msec()-began<1800:
		await create_timer(0.04).timeout
		stable = stable+1 if root.get_mouse_position().distance_to(point)<5 else 0
	if stable<3: print("BOARD_POINTER_TIMEOUT requested=",point," actual=",root.get_mouse_position()," window=",root.position," size=",root.size)
	check(stable==3,"native pointer stable before full viewport gesture")
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	root.push_input(event,true)
func pointer(point: Vector2, pressed: bool, button := MOUSE_BUTTON_LEFT) -> void:
	await settle(point)
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = button
	event.pressed = pressed
	event.button_mask = (MOUSE_BUTTON_MASK_LEFT if button==MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT) if pressed else 0
	root.push_input(event,true)
	await frames()
func click(point: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	await pointer(point,true,button)
	await pointer(point,false,button)
func press(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event,true)
	await frames()
	event = event.duplicate()
	event.pressed = false
	root.push_input(event,true)
	await frames()
func shot(name: String) -> void:
	game._update_ui()
	game.queue_redraw()
	await frames()
	RenderingServer.force_draw(false)
	check(root.get_texture().get_image().save_png("/tmp/board-trial-20261007-"+name+".png")==OK,"actual viewport capture "+name)
func await_result() -> void:
	var began := Time.get_ticks_msec()
	while game.phase==game.Phase.BATTLE and Time.get_ticks_msec()-began<25000: await process_frame
	check(game.phase==game.Phase.RESULT,"normal production frames reach result")
func run() -> void:
	root.size = Vector2i(1280,720)
	game = load("res://scenes/board_trial.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.audio_feedback.enabled = false
	await frames()
	check(game.is_processing() and game.deployment.size()==6,"normal frames / no three-person limit")
	var initial: Dictionary = game.deployment.duplicate()
	await click(game.roster_buttons[0].get_global_rect().get_center())
	await click(Config.center(Vector2i(6,3)))
	check(game.deployment==initial and "部署失败" in game.status_label.text,"UI seventh column refused and reason visible")
	await click(Config.center(Vector2i(5,6)))
	check(game.deployment.tangseng==Vector2i(5,6),"UI sixth column accepted")
	await click(Config.center(Vector2i(5,6)))
	await click(Config.center(Vector2i(5,6)),MOUSE_BUTTON_RIGHT)
	check(game.selected.is_empty() and not game.pointer_drag,"right cancels selection without moving")
	await click(game.roster_buttons[0].get_global_rect().get_center())
	await click(Config.center(initial.guard_monk))
	check(game.deployment.tangseng==initial.guard_monk and game.deployment.guard_monk==Vector2i(5,6),"UI occupied cell atomically swaps both friends")
	await press(KEY_R)
	check(not game.deployment.has("tangseng"),"UI R withdraws Tang without deletion")
	await click(game.start_button.get_global_rect().get_center())
	check(game.phase==game.Phase.DEPLOY and "唐僧" in game.status_label.text,"start precondition visible through native button")
	await click(game.formation_buttons[0].get_global_rect().get_center())
	var origin: Vector2i = game.deployment.guard_monk
	await pointer(Config.center(origin),true)
	await settle(Config.center(Vector2i(5,2)))
	await pointer(Config.center(Vector2i(5,2)),false)
	check(game.deployment.guard_monk==Vector2i(5,2),"complete drag-release commits once")
	await click(game.formation_buttons[0].get_global_rect().get_center())
	await click(game.roster_buttons[4].get_global_rect().get_center())
	check("治疗" in game.info_label.text and "射程 3" in game.info_label.text,"selected healer reports real treatment/range")
	await shot("deploy")
	# All important UI regions remain usable inside the 1920 logical / 720p view.
	check(game.roster_buttons.back().get_global_rect().end.x<game.withdraw_button.position.x,"roster and action areas do not overlap")
	check(game.info_label.position.y>game.formation_buttons.back().get_global_rect().end.y,"selection details do not overlap formation buttons")
	print("BOARD_PREVIEW_LAYOUT min=",game.enemies_label.get_minimum_size()," rect=",game.enemies_label.get_global_rect()," lines=",game.enemies_label.get_line_count())
	check(game.enemies_label.get_minimum_size().y<=714,"all six enemy previews fit sidebar vertically")
	await click(game.start_button.get_global_rect().get_center())
	check(game.phase==game.Phase.BATTLE,"native start enters actual process battle")
	await press(KEY_P)
	check(game.paused,"native keyboard pause")
	var snapshot: Dictionary = game.deployment.duplicate()
	var elapsed: float = game.elapsed
	await click(game.roster_buttons[1].get_global_rect().get_center())
	await click(Config.center(Vector2i(0,0)))
	await click(Config.center(Vector2i(2,2)),MOUSE_BUTTON_RIGHT)
	await press(KEY_R)
	await press(KEY_F)
	check(game.deployment==snapshot and game.elapsed==elapsed and game.paused,"paused battle left/right/R/F never moves/deploys and clock stays frozen")
	await click(game.speed_button.get_global_rect().get_center())
	check(game.speed==2 and game.paused,"speed toggle preserves pause")
	await shot("paused")
	await click(game.pause_button.get_global_rect().get_center())
	await await_result()
	check(game.victory and game.result_count==1,"natural A normal-frame victory settled once")
	await shot("victory")
	await click(game.retry_button.get_global_rect().get_center())
	check(game.phase==game.Phase.DEPLOY and game.deployment==snapshot and game.elapsed==0,"native retry restores pre-battle cells/clock")
	await click(game.formation_buttons[1].get_global_rect().get_center())
	await click(game.start_button.get_global_rect().get_center())
	await click(game.speed_button.get_global_rect().get_center())
	await await_result()
	check(not game.victory and game._record("tangseng").node.dead,"normal B produces real core death, not fixture HP")
	await shot("defeat")
	for index in range(game.roster_buttons.size()-1):
		check(game.roster_buttons[index].get_global_rect().end.x<=game.roster_buttons[index+1].position.x,"battle status text never enlarges one card over its neighbour")
	await click(game.retry_button.get_global_rect().get_center())
	check(game.actors.all(func(actor): return game._alive(actor) and game._hp(actor)==actor.hp_max),"native death retry restores both complete rosters")
	# No skill/economy keys change the fixed roster or phase.
	var before: Dictionary = game.deployment.duplicate()
	for key in [KEY_Q,KEY_W,KEY_E,KEY_SPACE]: await press(key)
	check(game.deployment==before and game.actors.size()==12 and game.phase==game.Phase.DEPLOY,"unused keys have no skill/shop side effects")
	print("BOARD_TRIAL_INPUT failures=",failures)
	game.free()
	quit(1 if failures else 0)
