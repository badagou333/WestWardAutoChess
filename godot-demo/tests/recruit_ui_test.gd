extends SceneTree
var failures := 0
func check(ok: bool, message: String):
	if not ok:
		failures += 1
		push_error(message)
func _initialize(): call_deferred("run")
func key(game,code: int,echo := false):
	var event:=InputEventKey.new()
	event.keycode=code
	event.pressed=true
	event.echo=echo
	game._unhandled_input(event)
func run():
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	check(not game.shop_open,"Shop starts collapsed")
	for control in game.shop_controls: check(not control.visible,"All shop controls hidden")
	key(game,KEY_1)
	key(game,KEY_R)
	check(game.heroes.is_empty() and game.refresh_token==1,"Hidden shop cannot buy or refresh with keys")
	key(game,KEY_SPACE)
	check(game.shop_open and game.state==game.GameState.PREPARING,"Space opens shop instead of starting battle")
	key(game,KEY_SPACE,true)
	check(game.shop_open,"Held Space does not repeatedly toggle")
	key(game,KEY_ESCAPE)
	check(not game.shop_open,"Escape closes shop")
	game.shop_toggle.pressed.emit()
	check(game.shop_open,"Button opens shop")
	check(game.shop_controls[0].mouse_filter==Control.MOUSE_FILTER_STOP,"Popup blocks click-through")
	game.shop_toggle.pressed.emit()
	check(not game.shop_open,"Button closes shop")
	var output:=OS.get_environment("RECRUIT_UI_PREVIEW")
	if not output.is_empty():
		for i in range(8): await process_frame
		check(root.get_texture().get_image().save_png(output.replace(".png","-empty.png"))==OK,"Empty bench screenshot saved")
	var all_controls: Array = []
	all_controls.append_array(game.shop_buttons)
	all_controls.append_array(game.bench_panels)
	all_controls.append_array([game.refresh_button,game.level_button,game.shop_toggle])
	for a in range(all_controls.size()):
		var rect: Rect2 = all_controls[a].get_global_rect()
		check(Rect2(Vector2.ZERO,Vector2(1920,1080)).encloses(rect),"Control outside viewport")
		for b in range(a+1,all_controls.size()):
			check(not rect.intersects(all_controls[b].get_global_rect()),"Overlapping controls")
	for card in game.shop_buttons:
		check(card.portrait!=null,"Every recruit card has a portrait")
		check(not card.caption.is_empty(),"Every recruit card has a name")
	for slot in range(8):
		check(game._bench_slot_at(game._bench_position(slot))==slot,"Bench hit geometry matches slot")
		check(game.bench_panels[slot].z_index==2026,"Slots visible above bottom panel")
	# Purchase, occupied label, sold-out card, deployment and return to last bench slot.
	key(game,KEY_SPACE)
	game.shop_buttons[0].pressed.emit()
	check(game.heroes.size()==1 and game.shop_buttons[0].portrait==null,"Purchase clears sold portrait")
	check(game.bench_label.text.contains("1 / 8"),"Bench counter updates")
	var hero=game.heroes[0]
	game._begin_pointer_action(hero.position)
	game.dragging=true
	game._end_pointer_action(game._cell_center(Vector2i(2,2)))
	check(hero.board_row==2,"Recruit deploy works")
	game._begin_pointer_action(hero.position)
	game.dragging=true
	game._end_pointer_action(game._bench_position(7))
	check(hero.bench_slot==7,"Return to last bench slot works")
	game._on_refresh_pressed()
	game._update_ui()
	check(game.refresh_token==0,"Free refresh preserved")
	for card in game.shop_buttons: check(card.portrait!=null,"Refresh restores images")
	game.coins=100
	game._on_level_pressed()
	check(game.population==4,"Population upgrade preserved")
	# A filled bench remains legible; avoid merges by locking the demonstration actors.
	hero.merge_locked=true
	for slot in range(7):
		var actor=game.HeroScene.new()
		actor.setup(game.DemoUnits.SHOP[slot%5],1)
		actor.bench_slot=slot
		actor.position=game._bench_position(slot)
		actor.set_bench_mode(true)
		actor.z_index=2030
		game.add_child(actor)
		game.heroes.append(actor)
	hero.z_index=2030
	game._update_ui()
	check(game.bench_label.text.contains("8 / 8"),"Full bench counter")
	for card in game.shop_buttons: check(card.disabled,"Full bench prevents purchases")
	if not output.is_empty():
		# Keep five different offers in the screenshot, after testing refresh separately.
		game.shop_types.assign(game.DemoUnits.SHOP)
		game._update_ui()
		game._set_shop_open(false)
		for i in range(8): await process_frame
		check(root.get_texture().get_image().save_png(output)==OK,"Screenshot saved")
		game._set_shop_open(true)
		for i in range(8): await process_frame
		check(root.get_texture().get_image().save_png(output.replace(".png","-open.png"))==OK,"Open shop screenshot saved")
	game.state=game.GameState.BATTLE_RUNNING
	game._set_shop_open(false)
	key(game,KEY_SPACE)
	check(game.shop_open and not game.battle_paused,"Battle Space opens shop without pausing")
	game._update_ui()
	check(game.refresh_button.disabled and game.level_button.disabled,"Battle locks economy controls")
	game._restart_demo()
	check(not game.shop_open,"Restart restores collapsed shop")
	check(game.bench_label.text.contains("0 / 8"),"Restart clears bench state")
	print("RECRUIT_UI: failures=",failures)
	game.free()
	quit(1 if failures else 0)
