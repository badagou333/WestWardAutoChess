extends "res://tests/board_trial_input_test.gd"
## Full Window/Viewport gestures against the depth scene, with production frames.
## Pointer helpers are inherited; no rectangular Config.center clicks.
const GroundProjection = preload("res://scripts/presentation/board_depth_projection.gd")
var checks := 0
var failed_labels: Array[String] = []
var cases: Array[Dictionary] = []
var cells_exercised := 0
var pointer_timeouts := 0
var consecutive_pointer_timeouts := 0

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		failed_labels.append(label)
		push_error(label)

func settle(point: Vector2) -> void:
	root.grab_focus()
	await process_frame
	root.warp_mouse(point)
	var began := Time.get_ticks_msec()
	var stable := 0
	while stable<3 and Time.get_ticks_msec()-began<1800:
		await create_timer(0.04).timeout
		stable=stable+1 if root.get_mouse_position().distance_to(point)<5 else 0
	if stable<3:
		pointer_timeouts+=1
		consecutive_pointer_timeouts+=1
		print("BOARD_DEPTH_POINTER_TIMEOUT requested=",point," actual=",root.get_mouse_position()," window=",root.position," size=",root.size)
	else:
		consecutive_pointer_timeouts=0
	check(stable==3,"native pointer stabilizes before complete depth viewport gesture")
	if consecutive_pointer_timeouts>=3:
		save_evidence(false,"three_consecutive_native_pointer_timeouts")
		quit(1)
		await process_frame
		return
	var event:=InputEventMouseMotion.new()
	event.position=point
	event.global_position=point
	root.push_input(event,true)

func cell_click(cell: Vector2i, button := MOUSE_BUTTON_LEFT) -> void:
	await click(game.display_center(cell),button)

func choose_profile(index: int) -> void:
	# Route through the root's real embedded-window dispatch. Sending keys to
	# PopupMenu.push_input bypasses Window._input_from_window and its navigation.
	# Never emit item_selected or call set_enemy_profile to simulate selection.
	var point: Vector2=game.ui.profile_choice.get_global_rect().get_center()
	await settle(point)
	var gesture:=InputEventMouseButton.new()
	gesture.position=point
	gesture.global_position=point
	gesture.button_index=MOUSE_BUTTON_LEFT
	gesture.button_mask=MOUSE_BUTTON_MASK_LEFT
	gesture.pressed=true
	root.push_input(gesture,true)
	await process_frame
	gesture=gesture.duplicate()
	gesture.button_mask=0
	gesture.pressed=false
	root.push_input(gesture,true)
	await frames()
	var popup: PopupMenu=game.ui.profile_choice.get_popup()
	check(popup.visible,"real enemy-profile popup opens during deployment")
	if not popup.visible: return
	check(popup.is_embedded(),"unchanged production profile popup uses the root's embedded-window event route")
	popup.grab_focus()
	await frames()
	var focused: int=popup.get_focused_item()
	print("BOARD_DEPTH_PROFILE before=",game.enemy_profile," target=",index," focused=",focused," embedded=",popup.is_embedded())
	# Focus is observed, not assigned; all navigation uses actual key gestures.
	for attempt in popup.item_count+1:
		if popup.get_focused_item()==index: break
		await press(KEY_DOWN)
	check(popup.get_focused_item()==index,"root keyboard navigation focuses requested actual profile row")
	await press(KEY_ENTER)
	check(not popup.visible and game.ui.profile_choice.selected==index,"root Enter activates and closes the actual profile popup")
	print("BOARD_DEPTH_PROFILE after=",game.enemy_profile," visible=",popup.visible)

func reset_formation() -> void:
	await click(game.formation_buttons[0].get_global_rect().get_center())
	check(game.phase==game.Phase.DEPLOY and game.selected.is_empty(),"actual A button restores deployment and releases selection")

func keyboard_and_profiles() -> void:
	for index in Config.FRIENDS.size():
		await press([KEY_1,KEY_2,KEY_3,KEY_4,KEY_5,KEY_6][index])
		check(game.selected==Config.FRIENDS[index],"actual key selects mapped roster member "+str(index+1))
		check(game.ui.selected_name.text==game._record(game.selected).name,"keyboard selection updates the visible detail panel")
	var opening: Dictionary=game.deployment.duplicate()
	for index in Config.ENEMY_PROFILES.size():
		await choose_profile(index)
		check_profile(Config.ENEMY_PROFILES[index])
		check(game.deployment==opening and game.phase==game.Phase.DEPLOY,"actual profile popup preserves friendly grid cells")
		check(game.actors.all(func(actor): return actor.node.position==game.display_center(actor.cell)),"profile popup rebuilds every actor on the projected grid")
	cases.append({"case":"keyboard_1_to_6_and_real_profile_popup","profiles":Config.ENEMY_PROFILES})

func all_cell_gestures() -> void:
	for row in Config.ROWS:
		for col in Config.COLS:
			var cell:=Vector2i(col,row)
			await press(KEY_1)
			var before: Dictionary=game.deployment.duplicate()
			await cell_click(cell)
			cells_exercised+=1
			check(game.hover_cell()==cell,"actual pointer/hover agrees with projected cell "+str(cell))
			if Config.deployable(cell):
				check(game.deployment.tangseng==cell,"native depth gesture deploys in left-half cell "+str(cell))
				check(game.selected.is_empty() and not game.pointer_drag and game.range_cells().is_empty(),"successful depth gesture releases control and range "+str(cell))
			else:
				check(game.deployment==before and game.selected=="tangseng","native depth gesture rejects right-half cell without losing selection "+str(cell))
				check("部署失败" in game.status_label.text,"rejected projected cell publishes a visible reason")
		print("BOARD_DEPTH_INPUT_ROW ",row+1," cells=",cells_exercised)
	await press(KEY_1)
	var before: Dictionary=game.deployment.duplicate()
	for point in [GroundProjection.point(Vector2(0,3))+Vector2(-20,0),GroundProjection.point(Vector2(6,7))+Vector2(0,20),GroundProjection.point(Vector2(-.25,-.25))]:
		await click(point)
		check(game.hover_cell()==Vector2i(-1,-1) and game.deployment==before and game.selected=="tangseng","visible platform sides and off-board point never deploy or discard selection")
	await cell_click(Vector2i(0,0),MOUSE_BUTTON_RIGHT)
	check(game.selected.is_empty() and not game.pointer_drag,"native right-click cancels selection without moving any unit")
	cases.append({"case":"84_projected_centers_and_platform_sides","cells":cells_exercised,"left_cells":42,"right_cells":42})

func swap_drag_and_resize() -> void:
	await reset_formation()
	var opening: Dictionary=game.deployment.duplicate()
	await press(KEY_1)
	await cell_click(opening.guard_monk)
	check(game.deployment.tangseng==opening.guard_monk and game.deployment.guard_monk==opening.tangseng,"complete viewport click atomically swaps occupied friendly cells")
	check(game.selected.is_empty() and not game.pointer_drag and game.range_cells().is_empty(),"successful swap clears control without selecting the other friend")
	await reset_formation()
	var origin: Vector2i=game.deployment.guard_monk
	var destination:=Vector2i(5,2)
	await pointer(game.display_center(origin),true)
	check(game.selected=="guard_monk" and game.pointer_drag,"native press picks up the unit from its projected foot cell")
	await settle(game.display_center(destination))
	await pointer(game.display_center(destination),false)
	check(game.deployment.guard_monk==destination and game.selected.is_empty() and not game.pointer_drag,"native drag and release commits one projected move and releases control")
	var after_drag: Dictionary=game.deployment.duplicate()
	await pointer(game.display_center(destination),false)
	check(game.deployment==after_drag and game.selected.is_empty(),"a repeated release cannot swap or place a second time")
	await reset_formation()
	for size in [Vector2i(960,540),Vector2i(1280,720)]:
		root.size=size
		await frames()
		for cell in [Vector2i(0,0),Vector2i(11,0),Vector2i(0,6),Vector2i(11,6)]:
			await settle(game.display_center(cell))
			check(game.hover_cell()==cell,"resized actual viewport retains projected corner picking "+str(size)+" "+str(cell))
		await press(KEY_1)
		await cell_click(Vector2i(5,6))
		check(game.deployment.tangseng==Vector2i(5,6),"resized native sixth-column edge accepts deployment")
		await press(KEY_1)
		var before: Dictionary=game.deployment.duplicate()
		await cell_click(Vector2i(6,6))
		check(game.deployment==before and game.selected=="tangseng","resized native seventh-column edge rejects deployment")
		await reset_formation()
	cases.append({"case":"occupied_swap_drag_selection_release_resize","window_sizes":[[960,540],[1280,720]]})

func help_modal() -> void:
	await press(KEY_6)
	var before: Dictionary=game.deployment.duplicate()
	var selection: String=game.selected
	await click(game.ui.help_button.get_global_rect().get_center())
	check(game.ui.help_layer.visible,"real help button opens the blocking overlay")
	await cell_click(Vector2i(4,3))
	await cell_click(Vector2i(4,3),MOUSE_BUTTON_RIGHT)
	await click(game.start_button.get_global_rect().get_center())
	await click(game.roster_buttons[0].get_global_rect().get_center())
	for key in [KEY_1,KEY_R,KEY_P]: await press(key)
	check(game.deployment==before and game.selected==selection and game.phase==game.Phase.DEPLOY,"help overlay blocks covered and outside-pane left/right clicks, controls and gameplay keys")
	await press(KEY_ESCAPE)
	check(not game.ui.help_layer.visible and game.selected==selection,"Escape closes help without forwarding a gameplay action")
	cases.append({"case":"help_modal","mouse_buttons":["left","right"],"keyboard_blocked":true})

func battle_result_retry() -> void:
	await reset_formation()
	var opening: Dictionary=game.deployment.duplicate()
	await click(game.start_button.get_global_rect().get_center())
	check(game.phase==game.Phase.BATTLE and game.is_processing(),"real start button begins production frame-driven combat")
	await press(KEY_P)
	check(game.paused and game.pause_button.text=="继续 P","native pause key updates actual state and visible control")
	var elapsed: float=game.elapsed
	await press(KEY_2)
	await cell_click(Vector2i(0,0))
	await cell_click(Vector2i(2,2),MOUSE_BUTTON_RIGHT)
	for key in [KEY_R,KEY_F]: await press(key)
	await click(game.formation_buttons[1].get_global_rect().get_center())
	await click(game.ui.profile_choice.get_global_rect().get_center())
	check(game.deployment==opening and game.elapsed==elapsed and game.paused,"paused battle blocks projected deployment, swap, withdraw and formation changes")
	check(game.ui.profile_choice.disabled and not game.ui.profile_choice.get_popup().visible and game.enemy_profile=="bear","profile popup cannot open or rebuild actors during paused battle")
	await click(game.speed_button.get_global_rect().get_center())
	check(game.speed==2 and game.paused and game.elapsed==elapsed,"actual speed button changes playback rate without unpausing")
	await press(KEY_6)
	await click(game.pause_button.get_global_rect().get_center())
	check(not game.paused,"actual pause button resumes frame-driven combat")
	await await_result()
	if game.phase!=game.Phase.RESULT:
		cases.append({"case":"battle_result_retry","complete":false})
		return
	check_result()
	check(game.ui.result_panel.visible and game.result_count==1,"natural battle opens exactly one real result panel")
	var before_report: Dictionary=game.report().duplicate(true)
	var before_selection: String=game.selected
	check(not before_selection.is_empty(),"result right-click fixture retains a nonempty pre-result selection")
	var covered:=Vector2.ZERO
	var found:=false
	for actor in game.actors:
		var pick: Dictionary=game._occupant(actor.cell)
		var point: Vector2=game.display_center(actor.cell)
		if game._active(actor) and not pick.is_empty() and pick.id!=before_selection and game.ui.result_panel.get_global_rect().has_point(point):
			covered=point
			found=true
			break
	check(found,"result click fixture has a real live unit underneath the visible panel")
	if found:
		await click(covered)
		check(game.selected==before_selection and game.report()==before_report,"result panel absorbs left-click above a real unit without underlying selection")
		await click(covered,MOUSE_BUTTON_RIGHT)
		check(game.selected==before_selection and game.report()==before_report,"result panel absorbs right-click above a real unit without global cancellation")
	await click(game.ui.result_close.get_global_rect().get_center())
	check(not game.ui.result_panel.visible and game.report()==before_report,"actual result close reveals board without changing battle outcome")
	await click(game.start_button.get_global_rect().get_center())
	check(game.ui.result_panel.visible and game.report()==before_report,"actual primary button reopens existing result without starting another battle")
	await click(game.retry_button.get_global_rect().get_center())
	check(game.phase==game.Phase.DEPLOY and game.deployment==opening and game.elapsed==0 and game.result_count==0,"real retry restores exact opening cells and resets the battle clocks")
	check(game.actors.all(func(actor): return game._alive(actor) and game._hp(actor)==actor.hp_max and actor.node.position==game.display_center(actor.cell)),"real retry restores all actors, health and projected positions")
	check(not game.ui.profile_choice.disabled and not game.ui.result_panel.visible,"retry unlocks profile controls and closes result")
	cases.append({"case":"battle_result_retry","complete":true,"report":before_report})

func save_evidence(completed: bool, reason := "") -> void:
	var path: String="/tmp/board-depth-input-20261014.json"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): path=argument.trim_prefix("--output=")
	var output:=FileAccess.open(path,FileAccess.WRITE)
	if output!=null:
		output.store_string(JSON.stringify({"scope":"depth board normal-window full viewport input","completed":completed,"abort_reason":reason,"checks":checks,"failures":failures,"failed_labels":failed_labels,"pointer_timeouts":pointer_timeouts,"cell_gestures":cells_exercised,"cases":cases,"native_window_and_root_push_input":true,"human_manual_playtest":false},"\t"))
	print("BOARD_DEPTH_INPUT completed=",completed," checks=",checks," cells=",cells_exercised," pointer_timeouts=",pointer_timeouts," failures=",failures)

func run() -> void:
	root.title="松风台 · 本轮输入验证"
	root.size=Vector2i(1280,720)
	game=load("res://scenes/board_trial.tscn").instantiate()
	root.add_child(game)
	current_scene=game
	game.audio_feedback.enabled=false
	await frames()
	check(game.get_script().resource_path=="res://scripts/board_depth.gd" and game.is_processing(),"window test loads the real main depth scene with normal production processing")
	await keyboard_and_profiles()
	if "--profiles-only" in OS.get_cmdline_user_args():
		save_evidence(false,"profiles_only_diagnostic")
		game.free()
		quit(1 if failures else 0)
		return
	await all_cell_gestures()
	await swap_drag_and_resize()
	await help_modal()
	await battle_result_retry()
	var completed: bool=cells_exercised==84 and cases.size()==5 and cases.all(func(entry): return entry.get("complete",true))
	check(completed,"all requested projected input groups actually execute")
	save_evidence(completed)
	game.free()
	quit(1 if failures else 0)
