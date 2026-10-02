extends "res://tests/camp_roster_input_test.gd"
## D-005: production frame processing and full Viewport/Control gestures.
func run():
	game = load("res://scenes/free_escort.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.audio_feedback.enabled = false
	await frames()
	check(not game.shop_open and not game.bench_open and game.roster_hud.visible,"unified panel initially closed; roster always visible")
	await press(KEY_B)
	check(not game.shop_open and not game.bench_open,"B no longer opens any independent panel")
	await click(game.shop_toggle.get_global_rect().get_center())
	check(game.shop_open and game.bench_open,"one button opens both shop and bench")
	for card in game.shop_buttons: await click(card.get_global_rect().get_center())
	check(game.heroes.size()==3 and game.coins==0,"three paid offers still consume exactly starting three gold")
	if game.heroes.size()!=3:
		await finish()
		return
	var monk = game.heroes[0]
	var hunter = game.heroes[1]
	var healer = game.heroes[2]
	var a: Vector2 = game.escort.position+Vector2(50,-30)
	var b: Vector2 = game.escort.position+Vector2(110,-30)
	var c: Vector2 = game.escort.position+Vector2(170,-30)
	for i in range(3):
		var hero = game.heroes[i]
		await click(hero.position)
		check(game.carry_hero==hero,"panel bench click picks actual reserve %d" % i)
		await click([a,b,c][i])
		check(hero.board_row>=0 and game.carry_hero==null and game.selected_hero==null,"legal deployment clears preview and selection %d" % i)
		await click(game.escort.position+Vector2(55,-95))
		check(hero.position==[a,b,c][i],"later empty-ground click cannot move newly placed hero")
	if game._deployed_count()!=3:
		await finish()
		return
	await shot("operation-ui-preparing")
	# Uniform panel visibility and click/drag interception, including hidden areas.
	await press(KEY_1)
	await click(Vector2(690,520))
	check(monk.position==a and game.selected_hero==monk,"blank panel click never passes to map")
	await pointer(monk.position,"press")
	await pointer(Vector2(690,520),"motion")
	await pointer(Vector2(690,520),"release")
	check(monk.position==a and game.carry_hero==monk,"drag release over blank panel never deploys through it")
	await press(KEY_ESCAPE)
	await press(KEY_SPACE)
	check(not game.shop_open and not game.bench_open and not game.shop_buttons[0].visible and not game.bench_panels[0].visible and game.roster_hud.visible,"Space closes both, leaving roster visible")
	# Field exchange: identities/HP follow the actors; number and point follow seat.
	monk.health = 43
	hunter.health = 29
	await press(KEY_1)
	await press(KEY_F)
	await echo_key(KEY_F)
	var before := snapshot()
	await click(hunter.position)
	check(monk.position==b and hunter.position==a and game.hero_slots[0]==hunter and game.hero_slots[1]==monk,"F field-to-field swaps exactly two existing numbered points")
	check(monk.health==43 and hunter.health==29 and snapshot()==before and game.selected_hero==null and game.swap_source==null,"exchange preserves health/currency/population and releases control")
	await click(game.escort.position+Vector2(55,-95))
	check(monk.position==b and hunter.position==a,"post-swap ground click cannot move either actor")
	check(game.guard_anchors[monk]==b and game.guard_anchors[hunter]==a and not game.brains.has(monk) and not game.brains.has(hunter),"swap updates anchors and clears old commands")
	check(game.roster_hud.slots[0].unit==hunter.unit_type and game.roster_hud.slots[0].hp==29 and game.roster_hud.slots[1].hp==43,"bottom view follows new slot identities and exact HP")
	await press(KEY_1)
	await press(KEY_F)
	await click(Vector2(300+130+62,980))
	check(monk.position==a and hunter.position==b and game.selected_hero==null,"bottom slot can select exchange target without map passthrough")
	await press(KEY_1)
	await press(KEY_F)
	await press(KEY_ESCAPE)
	check(game.swap_source==null and monk.position==a,"Escape cancels field exchange")
	await press(KEY_F)
	await press(KEY_SPACE)
	check(game.swap_source==null and not game.shop_open,"closing unified panel cancels armed exchange")
	await press(KEY_F)
	await click(monk.position)
	check(game.swap_source==null and monk.position==a,"clicking source cancels without self-exchange")
	# Start resets panel and pending gestures. Battle right-click releases selection.
	await click(game.start_button.get_global_rect().get_center())
	if game.state != game.GameState.BATTLE_RUNNING:
		check(false,"departure must enter battle")
		await finish()
		return
	game.intermission = 999
	await press(KEY_P)
	check(not game.shop_open and not game.bench_open and game.roster_hud.visible,"battle starts with unified panel closed and roster present")
	await click(monk.position)
	var goal: Vector2 = a+Vector2(0,-90)
	await click(goal,MOUSE_BUTTON_RIGHT)
	check(game.selected_hero==null and game._brain(monk).mode=="手动" and game._brain(monk).goal==goal,"mouse selection/right command clears selection but preserves accepted movement")
	await press(KEY_1)
	await click(Vector2(1000,470),MOUSE_BUTTON_RIGHT)
	check(game.selected_hero==null and game._brain(monk).goal==goal and "保留原任务" in game.status_label.text,"number selection/invalid right clears selection without damaging previous command")
	await click(a+Vector2(-40,-100),MOUSE_BUTTON_RIGHT)
	check(game._brain(monk).goal==goal,"unselected right click cannot retarget previous hero")
	await press(KEY_1)
	await press(KEY_SPACE)
	before = snapshot()
	await click(game.shop_buttons[0].get_global_rect().get_center())
	await click(game.refresh_button.get_global_rect().get_center())
	await click(game.level_button.get_global_rect().get_center())
	await click(Vector2(690,520),MOUSE_BUTTON_RIGHT)
	check(snapshot()==before and game.selected_hero==monk and game._brain(monk).goal==goal,"battle panel is read-only and consumes right click without changing selection or commands")
	await press(KEY_SPACE)
	# A valid map point hidden by the open panel must work after it closes.
	var uncovered := Map.center(Vector2i(4,8))
	await click(uncovered,MOUSE_BUTTON_RIGHT)
	check(game.selected_hero==null and game._brain(monk).goal==uncovered,"hidden panel no longer intercepts ground commands")
	await press(KEY_1)
	await click(goal,MOUSE_BUTTON_RIGHT)
	game._spawn_enemy("boar",Map.ROUTE[0])
	game.enemies[0].position = a+Vector2(80,0)
	var clock_before: float = game.battle_elapsed
	await create_timer(0.15).timeout
	check(monk.position==a and game.battle_elapsed==clock_before,"paused deselected command stays frozen")
	await click(game.speed_button.get_global_rect().get_center())
	var completed_before: int = game.manual_completions
	await press(KEY_P)
	await create_timer(0.15).timeout
	check(game.selected_hero==null and monk.position!=a and game._brain(monk).mode=="手动" and game._brain(monk).goal==goal,"normal 2x frames execute deselected command without nearby AI stealing it")
	for frame in range(180):
		if game.manual_completions > completed_before: break
		await process_frame
	check(game.manual_completions>completed_before and game.guard_anchors[monk]==goal and game.selected_hero==null,"deselected command reaches goal and establishes the new guard anchor on normal frames")
	await press(KEY_P)
	monk.take_damage(11)
	await frames()
	check(game.roster_hud.slots[0].hp==monk.health,"bottom health reflects damage on next real frame")
	monk.take_damage(9999)
	await frames()
	check(game.roster_hud.slots[0].dead and game.roster_hud.slots[0].status=="阵亡" and game.roster_hud.slots[0].hp==0 and game.roster_hud.slots[1].unit==hunter.unit_type,"death grays fixed slot without renumbering survivors")
	check("未配置" in game.roster_hud.skills_text and "—" in game.roster_hud.skills_text,"empty QWE states never fake cooldowns")
	before = snapshot()
	for key in [KEY_Q,KEY_W,KEY_E,KEY_R,KEY_F]: await press(key)
	check(snapshot()==before and game.swap_source==null,"empty skills and battle R/F have no economy or exchange effects")
	await shot("operation-ui-battle")
	# Controlled camp transition for revival and merge view-model refresh.
	game._enter_wave_preparation()
	await frames()
	check(game.shop_open and game.bench_open and not game.roster_hud.slots[0].dead and game.roster_hud.slots[0].hp==monk.max_health,"camp opens unified management and refreshes revived hero HP in same stable slot")
	var points: Dictionary = game.camp_positions.points.duplicate()
	await press(KEY_1)
	await press(KEY_F)
	await click(hunter.position)
	check(game.camp_positions.points==points and game.hero_slots[0]==hunter and game.hero_slots[1]==monk,"camp field exchange preserves complete coordinate ledger")
	game.coins = 10
	for i in range(2):
		game.shop_types[0] = "guard_monk"
		await frames()
		await click(game.shop_buttons[0].get_global_rect().get_center())
	check(monk.star==2 and game.roster_hud.slots[1].star==2 and game.roster_hud.slots[1].hp==monk.max_health and game.roster_hud.slots[0].unit==hunter.unit_type,"paid merge refreshes original keeper HP/star without renumbering")
	# Focus/echo retain both visibility and ownership.
	var edit := LineEdit.new()
	edit.position = Vector2(320,830)
	edit.size = Vector2(300,32)
	edit.z_index = 2100
	game.add_child(edit)
	edit.grab_focus()
	before = snapshot()
	for key in [KEY_SPACE,KEY_B,KEY_F,KEY_R,KEY_1]: await press(key)
	check(game.shop_open and game.bench_open and snapshot()==before and game.swap_source==null,"text focus keeps unified panel and gameplay shortcuts inert")
	edit.release_focus()
	edit.queue_free()
	await echo_key(KEY_SPACE)
	check(game.shop_open and game.bench_open,"Space echo cannot toggle repeatedly")
	await shot("operation-ui-camp")
	game._restart_demo()
	await frames()
	check(game.hero_slots.is_empty() and game.roster_hud.slots[0].is_empty() and not game.shop_open and not game.bench_open and game.coins==3,"restart resets all panel and roster state")
	await finish()

func finish() -> void:
	print("OPERATION_UI_INPUT failures=",failures)
	game.free()
	quit(1 if failures else 0)
