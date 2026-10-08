extends SceneTree
const Config = preload("res://scripts/data/board_trial_config.gd")
var game
var failures := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)
func _initialize() -> void:
	# Keep native pointer gestures on screen; centered macOS windows can extend
	# below the desktop. This affects tests only, never production picking.
	root.position = Vector2i(80,80)
	call_deferred("run")
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
	if "--no-capture" in OS.get_cmdline_user_args(): return
	game._update_ui()
	game.queue_redraw()
	await frames()
	RenderingServer.force_draw(false)
	check(root.get_texture().get_image().save_png("/tmp/board-ui-v2-20261007-"+name+".png")==OK,"actual new UI viewport capture "+name)
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
	check(game.BACKGROUND.get_size()==Vector2(1672,941) and game.BOARD_RECT==Rect2(220,190,1320,714),"full art texture and original exact geometry")
	check(game.BACKGROUND_RECT==Rect2(0,-12,1920,1128),"only v2 background uses calibrated crop mapping")
	check(game.ui.card_portraits.size()==6 and game.ui.enemy_portraits.size()==3 and game.ui.enemy_buttons.size()==6,"six real avatars, three enemy types and six specific inspection buttons")
	for index in range(6):
		await click(game.roster_buttons[index].get_global_rect().get_center())
		var actor: Dictionary = game._record(game.Config.FRIENDS[index])
		check(game.selected==actor.id and game.ui.card_portraits[index].texture!=null,"all six native card selections use actual production portraits")
		check(game.ui.card_hp[index].text=="%d / %d" % [game._hp(actor),actor.hp_max],"cards bind real HP")
		check(game.ui.card_bars[index].size.y==5 and game.ui.card_portraits[index].region.size.x<=70,"thin HP meters and actual head crops retain intended logical size")
		var mirror: bool = actor.key=="herbal_spirit_child" or actor.node.presentation.manifest.get("source_facing","right")=="left"
		check(game.ui.card_portraits[index].mirrored==mirror,"portraits use one source-dependent right-facing mirror")
	for index in range(3):
		await click(game.ui.enemy_names[index].get_parent().get_global_rect().get_center())
		check(game._record(game.selected).key==["wolf","boar","rat"][index] and not game.withdraw_button.visible,"all three real type rows inspect that enemy type")
	await click(game.roster_buttons[5].get_global_rect().get_center())
	check("攻击 20" in game.info_label.text and "1.25秒" in game.info_label.text and not "防御" in game.info_label.text,"fox details use real configuration, never concept statistics")
	var modal_before: Dictionary = game.deployment.duplicate()
	await click(game.ui.help_button.get_global_rect().get_center())
	check(game.ui.help_layer.visible,"actual help opens")
	await click(game.start_button.get_global_rect().get_center())
	await click(game.roster_buttons[0].get_global_rect().get_center())
	await click(Config.center(Vector2i(0,0)))
	await press(KEY_R)
	check(game.deployment==modal_before and game.phase==game.Phase.DEPLOY and game.selected=="foxfire_imp","help consumes covered mouse and gameplay keys without deployment")
	await press(KEY_ESCAPE)
	check(not game.ui.help_layer.visible,"Esc closes help without game action")
	await click(game.ui.enemy_buttons[5].get_global_rect().get_center())
	check(game.selected=="E6" and not game.withdraw_button.visible and "攻击 7" in game.info_label.text,"specific enemy inspection exposes attributes, never friendly withdraw")
	await press(KEY_R)
	check(game.deployment==modal_before,"enemy inspection R cannot withdraw a friendly")
	await click(Config.center(Vector2i(0,0)),MOUSE_BUTTON_RIGHT)
	# Complete viewport gestures through every drawn cell; no image-derived hit grid.
	for row in range(Config.ROWS):
		for col in range(Config.COLS):
			var cell := Vector2i(col,row)
			game.select("tangseng")
			var before: Dictionary = game.deployment.duplicate()
			await click(Config.center(cell))
			check(game.hover_cell()==cell,"hover/drawn grid and pointer agree at all 84 centers")
			check(game.deployment.tangseng==cell if col<6 else game.deployment==before,"84-cell actual gesture accepts only left half")
			if col==6: check("部署失败" in game.status_label.text,"invalid highlight has text reason, not color alone")
		print("BOARD_ART_ROW ",row+1," passed gesture checks")
	await click(game.formation_buttons[0].get_global_rect().get_center())
	await click(Config.center(Vector2i(0,0)),MOUSE_BUTTON_RIGHT)
	await shot("deploy")
	# Resize native window without moving logical grid, foot points or hover/range.
	for size in [Vector2i(960,540),Vector2i(1440,810)]:
		root.size = size
		await frames()
		check(game.ui.card_names.all(func(item): return item.get_minimum_size().x<=126) and game.ui.result_label.get_minimum_size().y<=425,"resized logical UI remains inside own panels")
		for cell in [Vector2i(0,0),Vector2i(11,0),Vector2i(0,6),Vector2i(11,6)]:
			await settle(Config.center(cell))
			check(game.hover_cell()==cell,"resized corner hover remains at logical cell")
		game.select("tangseng")
		await click(Config.center(Vector2i(5,6)))
		check(game.deployment.tangseng==Vector2i(5,6),"resize sixth-column gesture accepted")
		check(game.selected.is_empty() and not game.pointer_drag and game.range_cells().is_empty(),"successful sixth-column input releases control/range")
		await click(game.roster_buttons[0].get_global_rect().get_center())
		await click(Config.center(Vector2i(6,6)))
		check(game.deployment.tangseng==Vector2i(5,6),"resize seventh-column gesture rejected")
		await click(Config.ORIGIN-Vector2(1,1))
		check(game.deployment.tangseng==Vector2i(5,6),"resize outside top-left leaves deployment intact")
		await click(game.formation_buttons[0].get_global_rect().get_center())
	root.size = Vector2i(1280,720)
	await frames()
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
	check(game.selected.is_empty() and not game.pointer_drag and game.range_cells().is_empty(),"successful swap clears control, never auto-selects other friend")
	await click(game.roster_buttons[0].get_global_rect().get_center())
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
	check(game.range_cells().all(func(cell): return Config.distance(game._record("herbal_spirit_child").cell,cell)<=3),"range highlight uses real Manhattan cells")
	check(game.range_cells().size()==25,"interior radius-three diamond has exactly 25 cells")
	await shot("selected")
	# All important UI regions remain usable inside the 1920 logical / 720p view.
	check(game.roster_buttons.back().get_global_rect().end.x<game.withdraw_button.position.x,"roster and action areas do not overlap")
	check(game.info_label.get_global_rect().end.y<game.start_button.position.y,"right detail text stays clear of primary action")
	check(game.ui.card_names.all(func(item): return item.get_minimum_size().x<=126),"all six names fit real avatar cards")
	check(game.info_label.get_minimum_size().y<=231,"selected real detail wraps inside right rail")
	print("BOARD_PREVIEW_LAYOUT min=",game.enemies_label.get_minimum_size()," rect=",game.enemies_label.get_global_rect()," lines=",game.enemies_label.get_line_count())
	check(game.enemies_label.get_minimum_size().y<=714,"all six enemy previews fit sidebar vertically")
	await click(game.start_button.get_global_rect().get_center())
	check(game.phase==game.Phase.BATTLE,"native start enters actual process battle")
	await press(KEY_P)
	check(game.paused,"native keyboard pause")
	var snapshot: Dictionary = game.deployment.duplicate()
	var elapsed: float = game.elapsed
	for size in [Vector2i(960,540),Vector2i(1440,810),Vector2i(1280,720)]:
		root.size = size
		await frames()
		await click(game.roster_buttons[1].get_global_rect().get_center())
		await click(Config.center(Vector2i(0,0)))
		check(game.hover_cell()==Vector2i(0,0) and game.deployment==snapshot and game.elapsed==elapsed and game.paused,"all three window sizes preserve paused clock/grid and locked deployment")
	await click(game.ui.help_button.get_global_rect().get_center())
	await press(KEY_P)
	await press(KEY_R)
	await press(KEY_ESCAPE)
	check(game.paused and game.elapsed==elapsed and game.deployment==snapshot and not game.ui.help_layer.visible,"paused help blocks gameplay keys and closes without resuming")
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
	var began := Time.get_ticks_msec()
	while game.phase==game.Phase.BATTLE and game.elapsed<4.0 and Time.get_ticks_msec()-began<8000: await process_frame
	check(game.phase==game.Phase.BATTLE and game.metrics.damage.size()>0,"capture actual mixed battle with resolved damage")
	await click(game.roster_buttons[1].get_global_rect().get_center())
	var observed: Dictionary = game._record("guard_monk")
	var actual_target: Dictionary = game._record(observed.target)
	check(game.ui.selected_hp.text=="生命   %d / %d" % [game._hp(observed),observed.hp_max] and "状态 接敌" in game.info_label.text,"selected battle actor exposes actual changing HP and AI state")
	check(not actual_target.is_empty() and actual_target.id in game.info_label.text,"real current target is identified, not a placeholder or static enemy class")
	await shot("battle")
	await await_result()
	check(game.victory and game.result_count==1,"natural A normal-frame victory settled once")
	var total_damage := 0.0
	var total_healing := 0.0
	for actor in game.actors:
		if actor.friendly:
			total_damage += game.metrics.damage.get(actor.id,0)
			total_healing += game.metrics.healing.get(actor.id,0)
	check(game.ui.result_panel.visible and "合计伤害 %.0f" % total_damage in game.ui.result_label.text and "治疗 %.0f" % total_healing in game.ui.result_label.text and "阵亡 %d人" % game.report().fallen.size() in game.ui.result_label.text,"real A result keeps actual NEW-rule damage/heal/loss statistics")
	check(game.ui.result_label.get_minimum_size().y<=425,"actual complete six-person result text fits panel")
	check(game.ui.enemy_counts.all(func(item): return "存活 0 / 2"==item.text),"enemy summary live count reaches zero")
	await shot("victory")
	await click(game.ui.result_close.get_global_rect().get_center())
	check(not game.ui.result_panel.visible,"result can close for board inspection")
	await click(game.start_button.get_global_rect().get_center())
	check(game.ui.result_panel.visible,"primary action reopens real result, never starts another battle")
	await click(game.retry_button.get_global_rect().get_center())
	check(game.phase==game.Phase.DEPLOY and game.deployment==snapshot and game.elapsed==0,"native retry restores pre-battle cells/clock")
	await click(game.formation_buttons[1].get_global_rect().get_center())
	# Full B now legitimately wins under the approved active-guard strategy.
	# Keep actual failure/HP/stat UI coverage with a legal exposed core-alone
	# deployment, without weakening HP/damage or bypassing production combat.
	for key in Config.FRIENDS:
		if key=="tangseng": continue
		game.select(key)
		game.withdraw()
	check(game.deployment.size()==1 and game.deployment.has("tangseng"),"legal optional-roster fixture retains real exposed Tang for failure UI")
	await click(game.start_button.get_global_rect().get_center())
	await click(game.speed_button.get_global_rect().get_center())
	await await_result()
	check(not game.victory and game._record("tangseng").node.dead,"legal exposed core-alone deployment produces real core death, not fixture HP")
	total_damage = 0.0
	total_healing = 0.0
	for actor in game.actors:
		if actor.friendly:
			total_damage += game.metrics.damage.get(actor.id,0)
			total_healing += game.metrics.healing.get(actor.id,0)
	# Validate actual full statistics, not historical B healing/death premises.
	check("唐僧阵亡" in game.ui.result_label.text and "阵亡 %d人" % game.report().fallen.size() in game.ui.result_label.text and "合计伤害 %.0f" % total_damage in game.ui.result_label.text and "治疗 %.0f" % total_healing in game.ui.result_label.text,"real failure reason and fallen statistics remain accessible")
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
