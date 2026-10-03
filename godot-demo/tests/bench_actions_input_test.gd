extends "res://tests/operation_ui_input_test.gd"
## D-20261003-001: normal production frames, native Control and Viewport input.
func run():
	game = load("res://scenes/free_escort.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.audio_feedback.enabled = false
	await frames()
	check(game.is_processing() and game.bench_open and game.bench_back.visible and not game.shop_open,"initial bench is permanently visible with shop closed")
	check(game.withdraw_button.disabled and game.swap_button.disabled and "请先选择场上英雄" in game.action_hint.text,"no selection disables both actions with visible reason")
	check("请先选择场上英雄" in game.withdraw_button.tooltip_text and "请先选择场上英雄" in game.swap_button.tooltip_text,"disabled tooltips explain how to enable actions")
	await press(KEY_B)
	check(game.bench_open and not game.shop_open,"B neither hides bench nor opens shop")
	await press(KEY_SPACE)
	for card in game.shop_buttons: await click(card.get_global_rect().get_center())
	if game.heroes.size()!=3:
		check(false,"three native shop purchases required")
		await finish()
		return
	var monk = game.heroes[0]
	var hunter = game.heroes[1]
	var healer = game.heroes[2]
	var a: Vector2 = game.escort.position+Vector2(50,-30)
	var b: Vector2 = game.escort.position+Vector2(110,-30)
	var c: Vector2 = game.escort.position+Vector2(170,-30)
	await click(monk.position)
	await press(KEY_SPACE)
	check(not game.shop_open and game.bench_open and game.carry_hero==monk and monk.visible,"closing shop keeps picked bench hero usable")
	await click(a)
	check(monk.position==a and game.selected_hero==null and game.carry_hero==null,"bench deploy works with shop closed and releases selection")
	await pointer(hunter.position,"motion")
	await pointer(hunter.position,"press")
	await pointer(game.swap_button.get_global_rect().get_center(),"motion")
	await pointer(game.swap_button.get_global_rect().get_center(),"release")
	check(hunter.board_row<0 and game.carry_hero==hunter and game.swap_source==null,"bench drag release over action button does not place or arm exchange")
	await click(b,MOUSE_BUTTON_RIGHT)
	check(game.carry_hero==null and hunter.board_row<0,"right click cancels bench pickup with shop closed")
	await pointer(hunter.position,"motion")
	await pointer(hunter.position,"press")
	await pointer(b,"motion")
	await pointer(b,"release")
	await click(healer.position)
	await click(c)
	check(game._deployed_count()==3 and hunter.position==b and healer.position==c,"closed-shop bench supports drag and point placement")
	await press(KEY_1)
	check(not game.withdraw_button.disabled and not game.swap_button.disabled,"selected field hero enables R and F")
	var before := snapshot()
	await pointer(game.withdraw_button.get_global_rect().get_center(),"press")
	await create_timer(0.2).timeout
	check(snapshot()==before and monk.position==a,"holding mouse on R does not repeatedly withdraw before release")
	await pointer(game.withdraw_button.get_global_rect().get_center(),"release")
	check(monk.board_row<0 and monk.bench_slot==0 and game._deployed_count()==2 and not game.shop_open and game.selected_hero==null,"mouse R performs one withdrawal without opening shop or losing inventory")
	await echo_key(KEY_R)
	check(game.heroes.size()==3 and game._deployed_count()==2,"held-key echo does not duplicate withdrawal")
	await click(monk.position)
	await click(a)
	await press(KEY_1)
	await press(KEY_R)
	check(monk.board_row<0 and monk.bench_slot==0 and game._deployed_count()==2,"keyboard R matches mouse R")
	await click(monk.position)
	await click(a)
	monk.health = 43
	hunter.health = 29
	await press(KEY_1)
	await click(game.swap_button.get_global_rect().get_center())
	check(game.swap_source==monk and game.swap_button.button_pressed and "互换中" in game.action_hint.text and not game.shop_open,"mouse F highlights waiting state and never forces shop open")
	await shot("bench-actions-swap")
	await click(hunter.position)
	check(monk.position==b and hunter.position==a and game.hero_slots[0]==hunter and game.selected_hero==null and not game.swap_button.button_pressed,"mouse F swaps field targets and clears selection")
	check(monk.health==43 and hunter.health==29 and snapshot()==before,"mouse field swap preserves health, coins and roster")
	await press(KEY_1)
	await press(KEY_F)
	await click(monk.position)
	check(monk.position==a and hunter.position==b and game.hero_slots[0]==monk,"keyboard F matches mouse F field exchange")
	await press(KEY_1)
	await pointer(game.swap_button.get_global_rect().get_center(),"press")
	await create_timer(0.2).timeout
	check(game.swap_source==null,"holding mouse F waits for one release, not repeated execution")
	await pointer(game.swap_button.get_global_rect().get_center(),"release")
	await echo_key(KEY_F)
	check(game.swap_source==monk and snapshot()==before,"mouse release and key echo cannot duplicate exchange")
	await press(KEY_SPACE)
	await press(KEY_SPACE)
	check(game.swap_source==monk and game.bench_open and not game.shop_open,"shop open/close never cancels independent bench exchange")
	await press(KEY_ESCAPE)
	check(game.swap_source==null and not game.swap_button.button_pressed,"Escape cancels button-armed exchange")
	check(game.withdraw_button.focus_mode==Control.FOCUS_NONE and game.swap_button.focus_mode==Control.FOCUS_NONE and root.gui_get_focus_owner()==null,"action buttons do not retain keyboard focus")
	# Controlled full-inventory fixture; actions themselves still use real input.
	game.coins = 50
	for hero in game.heroes: hero.merge_locked = true
	var kinds := ["guard_monk","wild_hunter","herbal_spirit_child","sparrow_spirit","foxfire_imp"]
	var stocked := 0
	while game._free_bench_slot()>=0:
		game.shop_types[0] = kinds[stocked%kinds.size()]
		game._on_shop_pressed(0)
		game.heroes.back().merge_locked = true
		stocked += 1
	await frames()
	# New visual sizes must preserve all eight clickable seats and their feet.
	var full_before := snapshot()
	for slot in range(8):
		var stored = game._hero_in_bench(slot)
		var bounds: Rect2i = game.BenchPortraits.idle_bounds[stored.unit_type]
		var feet: float = stored.position.y+(stored.presentation.foot_anchor.y+bounds.end.y-218)*stored.presentation.scale.y
		check(absf(feet-862)<0.1,"mixed reserve feet share baseline %d" % slot)
		check(stored.compact_bench and not stored.presentation.show_shadow and game.bench_panels[slot].flat_mode,"free-mode flat bench presentation %d" % slot)
		await click(stored.position)
		check(game.carry_hero==stored and game.bench_panels[slot].highlighted,"enlarged mixed reserve remains selectable %d" % slot)
		if slot == 7: await shot("bench-actions-reserve-selected")
		await click(stored.position,MOUSE_BUTTON_RIGHT)
		check(game.carry_hero==null and snapshot()==full_before,"selected reserve right cancel preserves full inventory %d" % slot)
	await press(KEY_1)
	before = snapshot()
	check(game.withdraw_button.disabled and not game.swap_button.disabled and "后备已满" in game.action_hint.text,"full bench disables only R and visibly explains F remains available")
	await click(game.withdraw_button.get_global_rect().get_center())
	check(snapshot()==before and game.selected_hero==monk and monk.position==a,"disabled R click preserves selection, inventory and map position")
	await press(KEY_R)
	check(game.command_note==game.withdraw_button.tooltip_text and snapshot()==before,"keyboard R and disabled mouse R share full-bench rejection rule")
	var reserve = game._hero_in_bench(7)
	await click(game.swap_button.get_global_rect().get_center())
	await click(reserve.position)
	check(snapshot()==before and reserve.position==a and monk.bench_slot==7 and game.selected_hero==null,"mouse F works atomically with a full bench")
	await press(KEY_1)
	await click(game.swap_button.get_global_rect().get_center())
	await press(KEY_SPACE)
	await click(game.shop_controls[2].get_global_rect().get_center())
	check(not game.shop_open and game.swap_source==reserve and game.bench_open,"shop close button leaves bench and F state intact")
	await press(KEY_ESCAPE)
	# Text input must not steal any existing keys or activate button focus.
	var edit := LineEdit.new()
	edit.position = Vector2(320,680)
	edit.size = Vector2(300,30)
	edit.z_index = 2100
	game.add_child(edit)
	edit.grab_focus()
	for key in [KEY_R,KEY_F,KEY_SPACE,KEY_B,KEY_2]: await press(key)
	check(not game.shop_open and game.bench_open and game.selected_hero==reserve and game.swap_source==null and snapshot()==before,"text focus keeps action and shop shortcuts inert")
	edit.release_focus()
	edit.queue_free()
	await shot("bench-actions-full")
	await press(KEY_SPACE)
	await click(game.start_button.get_global_rect().get_center())
	if game.state!=game.GameState.BATTLE_RUNNING:
		check(false,"native departure required")
		await finish()
		return
	game.intermission = 999
	await press(KEY_P)
	check(not game.shop_open and game.bench_open and game._hero_in_bench(7).visible,"battle hides only shop, never bench inventory")
	await press(KEY_1)
	var goal: Vector2 = reserve.position+Vector2(0,-70)
	await click(goal,MOUSE_BUTTON_RIGHT)
	await press(KEY_1)
	before = snapshot()
	await click(game.withdraw_button.get_global_rect().get_center())
	await click(game.swap_button.get_global_rect().get_center())
	check(game.withdraw_button.disabled and game.swap_button.disabled and "战斗中" in game.action_hint.text,"battle action buttons remain visible but disabled with reason")
	check(snapshot()==before and game.selected_hero==reserve and game._brain(reserve).goal==goal,"disabled buttons cannot clear selection or turn into map commands")
	await press(KEY_9)
	await click(monk.position)
	await click(a+Vector2(30,-100))
	check(game.carry_hero==null and monk.board_row<0 and snapshot()==before,"permanent battle bench is read-only and cannot deploy")
	await press(KEY_SPACE)
	await click(game.refresh_button.get_global_rect().get_center())
	await click(game.shop_buttons[0].get_global_rect().get_center())
	check(snapshot()==before and game.bench_open,"battle shop cannot recruit or refresh")
	# Actual window-size changes, not just fabricated control rectangles.
	for window_size in [Vector2i(1280,720),Vector2i(1600,1000),Vector2i(1920,1080)]:
		root.size = window_size
		await frames()
		await process_frame
		check_layout()
		await shot("bench-actions-%dx%d" % [window_size.x,window_size.y])
		await click(game.shop_toggle.get_global_rect().get_center())
		check(not game.shop_open and game.bench_back.visible,"scaled mouse shop button preserves bench visibility")
		await press(KEY_SPACE)
		check(game.shop_open and game.bench_open,"scaled keyboard Space affects only shop")
	game._enter_wave_preparation()
	await frames()
	check(game.bench_open and game.bench_back.visible,"camp retains permanent bench")
	game._restart_demo()
	await frames()
	check(game.bench_open and not game.shop_open and game.withdraw_button.disabled and game.swap_button.disabled,"restart resets actions but keeps empty bench visible")
	await finish()

func check_layout() -> void:
	var shop: Rect2 = game.management_back.get_global_rect()
	var bench: Rect2 = game.bench_back.get_global_rect()
	var hud: Rect2 = game.roster_hud.get_global_rect()
	check(not shop.intersects(bench) and not shop.intersects(hud) and not bench.intersects(hud),"shop/bench/status bands never overlap")
	check(not shop.intersects(game.withdraw_button.get_global_rect()) and not shop.intersects(game.swap_button.get_global_rect()),"shop never covers action controls")
	for panel in game.bench_panels:
		check(panel.visible and bench.encloses(panel.get_global_rect()),"all eight tiles remain inside visible bench band")
	check(hud.encloses(game.withdraw_button.get_global_rect()) and hud.encloses(game.swap_button.get_global_rect()),"action buttons remain inside bottom-right status area")
	check(game.action_hint.size.y>=game.action_hint.get_minimum_size().y,"action explanation fits its assigned region")
	check("未配置" in game.roster_hud.skills_text and "Q" in game.roster_hud.skills_text and "W" in game.roster_hud.skills_text and "E" in game.roster_hud.skills_text,"all empty skill indicators remain present")
	print("BENCH_LAYOUT window=",root.size," viewport=",root.get_visible_rect())

func finish() -> void:
	print("BENCH_ACTIONS_INPUT failures=",failures)
	game.free()
	quit(1 if failures else 0)
