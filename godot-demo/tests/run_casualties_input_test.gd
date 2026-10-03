extends "res://tests/bench_actions_input_test.gd"
## Normal production frames and complete native/Viewport input. Wounded HP,
## extra wallet and cleared checkpoint are explicit boundary fixtures.

func native_roster() -> bool:
	await press(KEY_SPACE)
	for card in game.shop_buttons: await click(card.get_global_rect().get_center())
	check(game.heroes.size()==3,"casualty window purchases three paid heroes")
	if game.heroes.size()!=3: return false
	for i in range(3):
		await click(game.heroes[i].position)
		await click(game.escort.position+Vector2(50+i*60,-30))
	await click(game.start_button.get_global_rect().get_center())
	check(game.state==game.GameState.BATTLE_RUNNING,"casualty window enters battle through start button")
	game.intermission = 10000
	return game.state==game.GameState.BATTLE_RUNNING

func native_combat_loss(hero) -> void:
	game.combat.clear()
	for ally in game.heroes: ally.cooldown = 10000
	hero.health = 1
	game._spawn_enemy("boar",Map.ROUTE[0])
	var enemy = game.enemies.back()
	enemy.position = game._near_free(hero.position+Vector2(-30,0),enemy,60)
	check(enemy.position!=Vector2.INF and game._in_range(enemy,hero),"combat-loss fixture has valid land and clear attack line")
	if enemy.position==Vector2.INF or not game._in_range(enemy,hero): return
	game.combat.request(enemy,hero)
	var began := Time.get_ticks_msec()
	while not hero.run_fallen and Time.get_ticks_msec()-began < 2000:
		await process_frame
	if not hero.run_fallen:
		print("CASUALTY_TIMEOUT unit=",hero.unit_type," hp=",hero.health," position=",hero.position," enemy=",enemy.position," pose=",enemy.presentation.pose," source_time=",enemy.presentation.pose_time," strikes=",game.combat.strikes.size()," elapsed=",game.battle_elapsed," paused=",game.battle_paused)
	check(hero.run_fallen and hero.health==0,"normal-frame enemy attack produces persistent casualty: "+hero.unit_type)
	for threat in game.enemies: threat.queue_free()
	game.enemies.clear()
	game.combat.clear()
	await frames()

func native_camp() -> void:
	game.intermission = 0
	game.spawn_queue.clear()
	game.spawn_entries.clear()
	game.route_index = Map.CHECKPOINTS[game.wave_index]
	game.escort.position = Map.center(Map.ROUTE[game.route_index])
	await frames()
	check(game.state==game.GameState.PREPARING,"normal-frame cleared checkpoint reaches camp")

func run():
	game = load("res://scenes/free_escort.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.audio_feedback.enabled = false
	await frames()
	if not await native_roster():
		await finish()
		return
	var fallen = game.heroes[0]
	var living = game.heroes[1]
	var lost_at: Vector2 = fallen.position
	await press(KEY_1)
	await native_combat_loss(fallen)
	check(game.selected_hero==null and game.roster_hud.slots[0].permanent and game.roster_hud.slots[0].hp==0 and game._living_deployed_count()==2,"death updates fixed HUD and clears selection on normal frame")
	check("阵亡 1" in game.population_label.text and "可用 0" in game.population_label.text,"population distinguishes loss and available capacity")
	await press(KEY_P)
	await click(Vector2(362,980))
	check(game.selected_hero==null and "本关不可替补" in game.command_note,"dead HUD card cannot select an actor and explains restriction")
	await shot("run-casualty-battle")
	await press(KEY_P)
	await native_camp()
	check(fallen.run_fallen and fallen.health==0 and living.health==living.max_health and game.hero_slots[0]==fallen,"camp keeps original dead slot and restores living HP")
	game.coins = 50
	game.shop_types[0] = "guard_monk"
	await frames()
	await click(game.shop_buttons[0].get_global_rect().get_center())
	var reserve = game.heroes.back()
	await press(KEY_SPACE)
	await click(reserve.position)
	await click(lost_at)
	check(reserve.board_row<0 and game.carry_hero==reserve and "不可替补" in game.command_note,"same-identity purchase cannot deploy at dead marker")
	await click(lost_at,MOUSE_BUTTON_RIGHT)
	await click(game.level_button.get_global_rect().get_center())
	check(game.population==4,"real mouse upgrade remains available despite casualty")
	var extra: Vector2 = game._near_free(game.escort.position+Vector2(20,70),reserve)
	await click(reserve.position)
	await click(extra)
	check(reserve.board_row>=0 and game.hero_slots[3]==reserve and game._deployed_count()==4,"new population uses fourth seat, not dead first seat")
	await press(KEY_4)
	await press(KEY_R)
	await click(reserve.position)
	await click(extra+Vector2(0,55))
	check(reserve.board_row<0 and game.carry_hero==reserve,"withdrawal cannot manufacture a second new free location")
	await click(extra,MOUSE_BUTTON_RIGHT)
	await click(reserve.position)
	await click(extra)
	check(reserve.position==extra and game.selected_hero==null,"living new seat refills exactly and releases selection")
	# Full inventory is a boundary fixture; mouse exchange remains real input.
	for hero in game.heroes: hero.merge_locked = true
	while game._free_bench_slot()>=0:
		game.shop_types[0] = "guard_monk"
		game._on_shop_pressed(0)
		game.heroes.back().merge_locked = true
	await frames()
	await press(KEY_2)
	await click(game.withdraw_button.get_global_rect().get_center())
	check(game.selected_hero==living and living.board_row>=0 and game.withdraw_button.disabled,"full bench still refuses living mouse R")
	await click(game.swap_button.get_global_rect().get_center())
	await click(Vector2(362,980))
	check(game.swap_source==living and "本关不可替补" in game.command_note,"F rejects dead card while retaining valid living source")
	var incoming = game._hero_in_bench(7)
	var before := snapshot()
	await click(incoming.position)
	check(game.hero_slots[1]==incoming and living.bench_slot==7 and game.casualties.seats.has(0) and snapshot()==before,"full bench F preserves blocked seat, ownership and money")
	await press(KEY_2)
	await click(game.swap_button.get_global_rect().get_center())
	check(game.swap_source==incoming,"living F feedback remains available after swap")
	check(not game.population_label.get_global_rect().intersects(game.escort_label.get_global_rect()),"two-line population label does not overlap Tang HP")
	await shot("run-casualty-camp-full")
	await press(KEY_ESCAPE)
	await click(game.start_button.get_global_rect().get_center())
	game.intermission = 10000
	check(fallen.run_fallen and not fallen.active_in_battle and fallen.health==0 and game.roster_hud.slots[0].permanent,"next battle does not resurrect casualty")
	game._restart_demo()
	await frames()
	check(game.casualties.seats.is_empty() and game.roster_hud.slots[0].is_empty() and game.coins==3,"complete new run resets persistent loss UI")
	if not await native_roster():
		await finish()
		return
	for hero in game.heroes: await native_combat_loss(hero)
	await native_camp()
	check(game._living_deployed_count()==0 and game.casualties.seats.size()==3 and not game.start_button.disabled,"zero survivors with all capacity blocked still enables camp departure")
	await shot("run-casualty-zero-survivors")
	await click(game.start_button.get_global_rect().get_center())
	game.intermission = 10000
	check(game.state==game.GameState.BATTLE_RUNNING and game.heroes.all(func(hero): return hero.run_fallen and hero.health==0 and not hero.active_in_battle),"native zero-survivor departure continues without revival")
	await finish()

func finish() -> void:
	print("RUN_CASUALTIES_INPUT failures=",failures)
	game.free()
	quit(1 if failures else 0)
