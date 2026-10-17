extends SceneTree
## Root Viewport event routing against the real depth scene. Default is logical
## injection, not OS pointer verification. --native-pointer enables the separately
## authorized normal-window/native-pointer path.
const GroundProjection = preload("res://scripts/presentation/board_depth_projection.gd")
const Config = preload("res://scripts/data/board_trial_config.gd")
var game
var failures := 0
var checks := 0
var failed_labels: Array[String] = []
var cases: Array[Dictionary] = []
var cells_exercised := 0
var pointer_timeouts := 0
var consecutive_pointer_timeouts := 0
var native_pointer := false
var boundary_samples := 0

func _initialize() -> void:
	if "--native-pointer" in OS.get_cmdline_user_args(): root.position=Vector2i(80,80)
	call_deferred("run")

func frames() -> void:
	for i in 3: await process_frame
	if is_instance_valid(game) and not native_pointer: game._update_ui()

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		failed_labels.append(label)
		push_error(label)

func settle(point: Vector2) -> void:
	if not native_pointer:
		var motion:=InputEventMouseMotion.new()
		motion.position=point
		motion.global_position=point
		root.push_input(motion,true)
		await frames()
		return
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

func pointer(point: Vector2, pressed: bool, button := MOUSE_BUTTON_LEFT) -> void:
	await settle(point)
	var event:=InputEventMouseButton.new()
	event.position=point
	event.global_position=point
	event.button_index=button
	event.pressed=pressed
	event.button_mask=(MOUSE_BUTTON_MASK_LEFT if button==MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT) if pressed else 0
	root.push_input(event,true)
	await frames()

func click(point: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	await pointer(point,true,button)
	await pointer(point,false,button)

func press(code: Key) -> void:
	var event:=InputEventKey.new()
	event.keycode=code
	event.pressed=true
	root.push_input(event,true)
	await frames()
	event=event.duplicate()
	event.pressed=false
	root.push_input(event,true)
	await frames()

func check_profile(profile: String) -> void:
	var report: Dictionary=game.report()
	var specs: Array=Config.enemy_specs(profile)
	check(game.enemy_profile==profile and report.enemy_profile==profile and report.config==Config.version_for(profile),"actual selected profile/version reported "+profile)
	check(game.actors.size()==Config.FRIENDS.size()+specs.size() and report.enemy_parameters.size()==specs.size(),"profile rebuilds actual actor/parameter counts "+profile)
	for index in specs.size():
		var actor: Dictionary=game._record("E%d" % (index+1))
		var stats: Dictionary=Config.enemy_stats(specs[index][0],profile)
		var parameter: Dictionary=report.enemy_parameters[index]
		check(actor.key==specs[index][0] and actor.hp_max==stats.hp and actor.damage==stats.damage and actor.interval==stats.interval and actor.reach==stats.range,"actual enemy stats bind selected profile "+profile+" "+actor.id)
		check(parameter.id==actor.id and parameter.key==actor.key and parameter.hp==stats.hp and parameter.damage==stats.damage and parameter.interval==stats.interval and parameter.range==stats.range and parameter.walk==0.5 and parameter.initial_cell==[specs[index][1].x,specs[index][1].y],"reported parameter table matches selected profile "+profile+" "+actor.id)
	check(game.ui.enemy_rows[3].is_visible_in_tree()==(profile=="bear"),"bear inspection row follows actual profile membership")
	check(game.monk_sample_enabled and game._record("guard_monk").node.presentation.motion_sample_enabled,"profile rebuild preserves default board monk sample clock")

func check_result() -> void:
	var report: Dictionary=game.report()
	check(game.phase==game.Phase.RESULT and game.result_count==1 and report.enemy_profile=="bear" and report.config==Config.version_for("bear"),"default bear settles exactly one actual profiled Result")
	var core: Dictionary=game._record("tangseng")
	var enemies: Array=game.actors.filter(func(actor): return not actor.friendly)
	if game.victory:
		check(game._alive(core) and enemies.all(func(actor): return not game._alive(actor)) and "唐僧存活且全敌清除" in game.ui.result_label.text,"actual victory requires living Tang and all enemies cleared")
	else:
		check(not game._alive(core) and "唐僧阵亡" in game.ui.result_label.text,"actual failure reports real Tang death")
	check(game.ui.profile_choice.disabled,"result never unlocks profile changes")
	for index in game.ui.ENEMY_TYPES.size():
		var kind: String=game.ui.ENEMY_TYPES[index]
		var members: Array=game.actors.filter(func(actor): return not actor.friendly and actor.key==kind)
		if members.is_empty(): continue
		var living: int=members.filter(func(actor): return game._alive(actor)).size()
		check(game.ui.enemy_counts[index].text=="存活 %d / %d" % [living,members.size()],"enemy summary binds actual live/total count "+kind)

func check_pick(point: Vector2, expected: Vector2i, label: String) -> void:
	check(game.display_cell_at(point)==expected and GroundProjection.cell_at(point)==expected,label)

func projected_boundaries() -> void:
	# Probe every shared edge on both sides, including the deployment seam.
	# Exact outer-boundary ownership is half-open [0,12) x [0,7).
	var epsilon:=0.0001
	for row in Config.ROWS:
		for col in range(1,Config.COLS):
			for side in [-1,1]:
				var grid:=Vector2(col+side*epsilon,row+0.5)
				var expected:=Vector2i(col-1 if side<0 else col,row)
				check_pick(GroundProjection.point(grid),expected,"both sides of vertical shared edge "+str(grid))
				boundary_samples+=1
	for row in range(1,Config.ROWS):
		for col in Config.COLS:
			for side in [-1,1]:
				var grid:=Vector2(col+0.5,row+side*epsilon)
				var expected:=Vector2i(col,row-1 if side<0 else row)
				check_pick(GroundProjection.point(grid),expected,"both sides of horizontal shared edge "+str(grid))
				boundary_samples+=1
	for corner in [Vector2(0,0),Vector2(12,0),Vector2(12,7),Vector2(0,7)]:
		var inside:=Vector2(epsilon if corner.x==0 else 12-epsilon,epsilon if corner.y==0 else 7-epsilon)
		check_pick(GroundProjection.point(inside),Vector2i(0 if corner.x==0 else 11,0 if corner.y==0 else 6),"inside corner "+str(corner))
		var outside:=Vector2(-epsilon if corner.x==0 else 12+epsilon,-epsilon if corner.y==0 else 7+epsilon)
		check_pick(GroundProjection.point(outside),Vector2i(-1,-1),"outside corner never clamps inward "+str(corner))
	# Stone rim, sidewall and stairs are outside the playable homography.
	for grid in [Vector2(-epsilon,0.5),Vector2(12+epsilon,0.5),Vector2(6,-epsilon),Vector2(6,7+epsilon),Vector2(-0.08,3.5),Vector2(12.08,3.5),Vector2(6,7.12),Vector2(6,7.8)]:
		check_pick(GroundProjection.point(grid),Vector2i(-1,-1),"rim/step/exterior never accepted "+str(grid))
	var far_left: Vector2=GroundProjection.point(Vector2.ZERO)
	var near_left: Vector2=GroundProjection.point(Vector2(0,7))
	check_pick(Vector2(near_left.x+1,far_left.y+1),Vector2i(-1,-1),"trapezoid bounding-box false positive rejected")
	check_pick(GroundProjection.point(Vector2.ZERO),Vector2i.ZERO,"top-left boundary inclusive")
	check_pick(GroundProjection.point(Vector2(12,0)),Vector2i(-1,-1),"right boundary exclusive")
	check_pick(GroundProjection.point(Vector2(0,7)),Vector2i(-1,-1),"bottom boundary exclusive")
	cases.append({"case":"projective_shared_edges_corners_and_exterior","two_sided_shared_edge_samples":boundary_samples,"boundary_policy":"half-open [0,12) x [0,7), no outward clamping"})

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
			check_pick(game.display_center(cell),cell,"event point agrees with projected cell "+str(cell))
			if native_pointer: check(game.hover_cell()==cell,"native hover agrees with projected cell "+str(cell))
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
		check(game.display_cell_at(point)==Vector2i(-1,-1) and game.deployment==before and game.selected=="tangseng","visible platform sides and off-board point never deploy or discard selection")
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
	var before_outside: Dictionary=game.deployment.duplicate()
	await pointer(game.display_center(game.deployment.guard_monk),true)
	await pointer(GroundProjection.point(Vector2(6,7.6)),false)
	check(game.deployment==before_outside and not game.pointer_drag and game.selected=="guard_monk","drag release on stairs ends gesture without moving or silently discarding selection")
	await pointer(game.display_center(Vector2i(5,1)),false)
	check(game.deployment==before_outside and game.selected=="guard_monk","release after off-board drag cannot commit a second drop")
	await press(KEY_ESCAPE)
	check(game.selected.is_empty() and not game.pointer_drag,"Escape cancels board selection and drag without movement")
	await press(KEY_2)
	await press(KEY_R)
	check(not game.deployment.has("guard_monk") and game.selected=="guard_monk" and not game.pointer_drag,"R withdraws selected friendly while keeping it available for redeployment")
	await press(KEY_2)
	await cell_click(Vector2i(5,1))
	check(game.deployment.guard_monk==Vector2i(5,1) and game.selected.is_empty(),"withdrawn friend returns through ordinary projected placement")
	await reset_formation()
	for size in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1440,810)]:
		root.size=size
		await frames()
		for row in Config.ROWS:
			for col in Config.COLS:
				var cell:=Vector2i(col,row)
				await settle(game.display_center(cell))
				check_pick(game.display_center(cell),cell,"resized viewport retains all projected centers "+str(size)+" "+str(cell))
				if native_pointer: check(game.hover_cell()==cell,"resized native hover agrees with projected center "+str(size)+" "+str(cell))
		await press(KEY_1)
		await cell_click(Vector2i(5,6))
		check(game.deployment.tangseng==Vector2i(5,6),"resized native sixth-column edge accepts deployment")
		await press(KEY_1)
		var before: Dictionary=game.deployment.duplicate()
		await cell_click(Vector2i(6,6))
		check(game.deployment==before and game.selected=="tangseng","resized native seventh-column edge rejects deployment")
		await reset_formation()
	cases.append({"case":"occupied_swap_drag_selection_release_resize","window_sizes":[[960,540],[1280,720],[1440,810]],"centers_per_size":84,"event_coordinate_space":"logical viewport; native mouse separately flagged","off_board_drag":true,"withdraw_and_redeploy":true})

func ui_occlusion() -> void:
	await press(KEY_2)
	var before: Dictionary=game.deployment.duplicate()
	var selected_before: String=game.selected
	# Actual panel surfaces, away from intentional buttons, cannot place units.
	for point in [Vector2(1800,700),Vector2(80,200),Vector2(1000,80),Vector2(1000,940)]:
		await click(point)
		check(game.deployment==before and game.selected==selected_before and not game.pointer_drag,"HUD panel gesture does not place or pick an underlying actor "+str(point))
	cases.append({"case":"hud_occlusion","logical_viewport_events":true})

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
	check(game.phase==game.Phase.BATTLE and game.is_processing()==native_pointer,"real start button begins combat; native frames or explicit deterministic logical stepping")
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

func await_result() -> void:
	if native_pointer:
		var began:=Time.get_ticks_msec()
		while game.phase==game.Phase.BATTLE and Time.get_ticks_msec()-began<25000: await process_frame
		check(game.phase==game.Phase.RESULT,"normal production frames reach result")
		return
	while game.phase==game.Phase.BATTLE and game.elapsed<60: game.step(1.0/60)
	game._update_ui()
	await frames()
	check(game.phase==game.Phase.RESULT,"logical-input path reaches real natural result")

func save_evidence(completed: bool, reason := "") -> void:
	var path: String="/tmp/board-perspective-input-20261017.json"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): path=argument.trim_prefix("--output=")
	var output:=FileAccess.open(path,FileAccess.WRITE)
	if output!=null:
		output.store_string(JSON.stringify({"scope":"perspective board root viewport event routing","completed":completed,"abort_reason":reason,"checks":checks,"failures":failures,"failed_labels":failed_labels,"pointer_timeouts":pointer_timeouts,"cell_gestures":cells_exercised,"cases":cases,"native_window_and_root_push_input":native_pointer,"logical_root_push_input":not native_pointer,"OS_mouse_verified":native_pointer and pointer_timeouts==0,"human_manual_playtest":false},"\t"))
	print("BOARD_DEPTH_INPUT completed=",completed," checks=",checks," cells=",cells_exercised," pointer_timeouts=",pointer_timeouts," failures=",failures)

func run() -> void:
	native_pointer="--native-pointer" in OS.get_cmdline_user_args()
	root.title="松风台 · 本轮输入验证"
	root.size=Vector2i(1280,720)
	game=load("res://scenes/board_trial.tscn").instantiate()
	root.add_child(game)
	current_scene=game
	if not native_pointer: game.set_process(false)
	game.audio_feedback.enabled=false
	await frames()
	check(game.get_script().resource_path=="res://scripts/board_depth.gd" and game.is_processing()==native_pointer,"input test loads real main perspective scene without presenting logical injection as OS input")
	projected_boundaries()
	await keyboard_and_profiles()
	if "--profiles-only" in OS.get_cmdline_user_args():
		save_evidence(false,"profiles_only_diagnostic")
		game.free()
		quit(1 if failures else 0)
		return
	await all_cell_gestures()
	await swap_drag_and_resize()
	await ui_occlusion()
	await help_modal()
	await battle_result_retry()
	var completed: bool=cells_exercised==84 and boundary_samples==298 and cases.size()==7 and cases.all(func(entry): return entry.get("complete",true))
	check(completed,"all requested projected input groups actually execute")
	save_evidence(completed)
	game.free()
	quit(1 if failures else 0)
