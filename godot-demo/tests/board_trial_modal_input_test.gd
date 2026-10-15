extends "res://tests/board_trial_input_test.gd"
## Full native-pointer/Viewport gestures; modal GUI handles its own close button.
func mouse(point: Vector2, pressed: bool, which: MouseButton) -> void:
	await settle(point)
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = which
	event.pressed = pressed
	event.button_mask = (1<<(which-1)) if pressed and which in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT,MOUSE_BUTTON_MIDDLE,MOUSE_BUTTON_XBUTTON1,MOUSE_BUTTON_XBUTTON2] else 0
	root.push_input(event,true)
	await frames()

func gesture(point: Vector2, which: MouseButton) -> void:
	await mouse(point,true,which)
	await mouse(point,false,which)

func snapshot() -> Dictionary:
	return {"selected":game.selected,"deployment":game.deployment.duplicate(),"time":game.elapsed,
		"phase":game.phase,"paused":game.paused,"speed":game.speed,"message":game.message,
		"drag":game.pointer_drag,"origin":game.pointer_origin,"details":game.info_label.text}

func unchanged(before: Dictionary, label: String) -> void:
	check(game.ui.help_layer.visible and snapshot()==before,label+" modal preserves selection/details/deployment/message/drag/clock/phase/pause/speed")

func run_case(size: Vector2i, in_battle: bool) -> void:
	root.size = size
	game = load("res://scenes/board_trial.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.audio_feedback.enabled = false
	await frames()
	check(game.get_script().resource_path=="res://scripts/board_depth.gd","modal input test loads the main depth controller")
	if in_battle:
		await click(game.start_button.get_global_rect().get_center())
		await press(KEY_P)
		check(game.phase==game.Phase.BATTLE and game.paused,"real start/pause fixture")
	await click(game.roster_buttons[1 if in_battle else 5].get_global_rect().get_center())
	check(game.selected==("guard_monk" if in_battle else "foxfire_imp"),"real card selected before modal")
	await click(game.ui.help_button.get_global_rect().get_center())
	check(game.ui.help_layer.visible,"real help button opens modal")
	var before := snapshot()
	# Inside help body and outside it over the actual board.
	for point in [Vector2(960,500),game.display_center(Vector2i(0,0))]:
		for which in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT,MOUSE_BUTTON_MIDDLE,MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN,MOUSE_BUTTON_XBUTTON1,MOUSE_BUTTON_XBUTTON2]:
			await gesture(point,which)
			unchanged(before,"full mouse "+str(which)+" "+str(point))
	for control in [game.roster_buttons[0],game.start_button,game.retry_button,game.withdraw_button]:
		await click(control.get_global_rect().get_center())
		unchanged(before,"covered UI action")
	await mouse(game.display_center(game._record("guard_monk").cell),true,MOUSE_BUTTON_LEFT)
	await settle(game.display_center(Vector2i(0,6)))
	var motion := InputEventMouseMotion.new()
	motion.position = game.display_center(Vector2i(0,6))
	motion.global_position = motion.position
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	motion.relative = Vector2(-100,100)
	root.push_input(motion,true)
	await frames()
	await mouse(motion.position,false,MOUSE_BUTTON_LEFT)
	unchanged(before,"full press/move/release behind help")
	for key in [KEY_1,KEY_6,KEY_R,KEY_F,KEY_P,KEY_Q,KEY_W,KEY_E,KEY_SPACE]:
		await press(key)
		unchanged(before,"covered shortcut "+str(key))
	# Mouse close must be dispatched through GUI, not swallowed at _input.
	await click(game.ui.help_close.get_global_rect().get_center())
	check(not game.ui.help_layer.visible and snapshot()==before,"actual close button preserves underlying state without event leak")
	await click(game.ui.help_button.get_global_rect().get_center())
	await press(KEY_ESCAPE)
	check(not game.ui.help_layer.visible and snapshot()==before,"Esc closes only help, never cancels underlying selection")
	await click(Vector2(960,500),MOUSE_BUTTON_RIGHT)
	check(game.selected.is_empty() and game.deployment==before.deployment and game.elapsed==before.time and game.paused==before.paused,"non-modal right gesture still cancels selection, never moves or resumes")
	await click(game.roster_buttons[4].get_global_rect().get_center())
	check(game.selected=="herbal_spirit_child","normal card selection restored after help")
	await press(KEY_6)
	check(game.selected=="foxfire_imp","normal numeric shortcut restored after help")
	if in_battle:
		await press(KEY_R)
		check(game.deployment==before.deployment and game.elapsed==before.time and game.paused,"closed modal never removes paused battle lock")
	else:
		await press(KEY_R)
		check(not game.deployment.has("foxfire_imp"),"closed modal restores legal deployment withdraw shortcut")
	print("BOARD_MODAL_CASE size=",size," battle=",in_battle," failures=",failures)
	game.free()

func run() -> void:
	for size in [Vector2i(960,540),Vector2i(1440,810),Vector2i(1280,720)]:
		await run_case(size,false)
		await run_case(size,true)
	print("BOARD_TRIAL_MODAL_INPUT failures=",failures)
	quit(1 if failures else 0)
