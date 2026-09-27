extends SceneTree
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	if not value:
		failures.append(label)
		push_error(label)

func make_game():
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	return game

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var game = make_game()
	check(game.coins == 10 and game.population == 3 and game.shop_types.size() == 5,"Initial economy")
	for key in game.shop_types:
		check(game.HeroScene.UNIT_DATA[key].quality == "white","One-cost shop")
	game._on_refresh_pressed()
	check(game.coins == 10 and game.refresh_token == 0,"Free refresh once")
	game._on_refresh_pressed()
	check(game.coins == 8,"Paid refresh")
	game._restart_demo()
	game.shop_types.assign(["guard_monk","guard_monk","guard_monk","guard_monk","guard_monk"])
	game._on_shop_pressed(0)
	var locked = game.heroes[0]
	game._select_hero(locked)
	game._toggle_selected_lock()
	game._on_shop_pressed(1)
	game._on_shop_pressed(2)
	check(game.heroes.size() == 3,"Locked hero excluded")
	game._toggle_selected_lock()
	check(game.heroes.size() == 1 and locked.star == 2 and game.coins == 7,"Unlock triggers exact merge")
	check(locked.presentation.role == "guard_monk","Merge keeps role")
	game._begin_pointer_action(locked.position)
	game.dragging = true
	game._end_pointer_action(game._cell_center(Vector2i(2,2)))
	check(locked.board_row == 2 and locked.board_col == 2,"Drag placement")
	game._place_hero_on_board(locked,game.CENTER_CELL)
	check(locked.board_col == 2,"Center cannot be occupied")
	game._select_hero(locked)
	game._sell_selected()
	check(game.coins == 9 and game.heroes.is_empty(),"Two-star refund")
	game.coins = 20
	game._on_level_pressed()
	check(game.population == 4 and game.coins == 10,"Population cost")
	game._restart_demo()
	for n in range(8):
		game.shop_types[0] = game.DemoUnits.SHOP[n%5]
		game._on_shop_pressed(0)
		game.heroes.back().merge_locked = true
	var before: int = game.coins
	game.shop_types[0] = "guard_monk"
	game._on_shop_pressed(0)
	check(game.heroes.size() == 8 and game.coins == before,"Full bench no charge")
	game._restart_demo()
	game.coins = 0
	game._on_shop_pressed(0)
	check(game.heroes.is_empty(),"Insufficient coins")
	game.queue_free()
	await process_frame

	# Delivery events tested independently of automatic targeting.
	game = make_game()
	for i in range(5): game._on_shop_pressed(i)
	for hero in game.heroes: hero.active_in_battle = true
	var fox = game.heroes[4]
	var healer = game.heroes[3]
	var patient = game.heroes[0]
	game._spawn_enemy("bear_lord",Vector2i(0,3))
	var boss = game.enemies[0]
	var hp: float = boss.health
	game.combat.request(fox,boss,false,true)
	fox.tick_visual(fox.presentation.impact_delay()-0.01)
	game.combat.tick(0)
	check(boss.health == hp and game.combat.missiles.is_empty(),"Windup does not hit")
	fox.tick_visual(0.011)
	game.combat.tick(0)
	check(boss.health == hp and game.combat.missiles.size() == 1,"One projectile at release")
	game.combat.tick(0.25)
	game.combat.tick(0.25)
	check(boss.health == hp-fox.damage,"Projectile hits once")
	patient.health -= 50
	var patient_hp: float = patient.health
	game.combat.request(healer,patient,true)
	healer.tick_visual(healer.presentation.impact_delay()+0.001)
	game.combat.tick(0)
	check(patient.health == patient_hp,"Healing waits for arrival")
	game.combat.tick(0.25)
	game.combat.tick(0.25)
	check(patient.health == patient_hp+healer.damage,"Healing once")
	fox.presentation.reset_visual()
	game.combat.request(fox,boss)
	fox.tick_visual(fox.presentation.impact_delay()+0.001)
	game.combat.tick(0)
	boss.take_damage(boss.max_health)
	game.combat.tick(0.3)
	check(game.combat.missiles.is_empty(),"Dead target cancels projectile")
	game.queue_free()
	await process_frame

	var reference := {}
	for rate in [30,60,120]:
		for speed in [1.0,2.0]:
			game = make_game()
			for i in [0,1,3]: game._on_shop_pressed(i)
			var cells := [Vector2i(2,2),Vector2i(1,3),Vector2i(3,3)]
			for i in range(3): game._place_hero_on_board(game.heroes[i],cells[i])
			game._start_battle()
			game.battle_speed = speed
			var ticks := 0
			while game.state == game.GameState.BATTLE_RUNNING and ticks < rate*180:
				game.step(1.0/rate)
				ticks += 1
				if ticks == rate*5:
					var clock: float = game.battle_elapsed
					var phase: float = game.heroes[0].presentation.pose_time
					var pos: Vector2 = game.heroes[0].position
					var coins: int = game.coins
					var count: int = game.heroes.size()
					game._on_shop_pressed(2)
					check(game.coins == coins and game.heroes.size() == count,"No purchases in battle")
					game._toggle_pause()
					game.step(3)
					check(game.battle_elapsed == clock and game.heroes[0].presentation.pose_time == phase and game.heroes[0].position == pos,"Pause freezes clock, movement, pose")
					game._toggle_pause()
			check(game.state == game.GameState.RESULT and not game.escort.dead,"Four-wave victory")
			check(game.wave_index == 3 and game.pending_loot == 20,"Four waves exact rewards")
			check(game.combat.counts.heals > 0 and game.combat.counts.projectiles > 0,"Healer participates")
			var result := {"hp":game.escort.health,"coins":game.coins,"counts":game.combat.counts.duplicate(),"elapsed":game.battle_elapsed}
			if reference.is_empty(): reference = result
			else:
				check(result.hp == reference.hp and result.coins == reference.coins and result.counts == reference.counts,"FPS/speed same outcomes")
				check(absf(result.elapsed-reference.elapsed)<0.001,"FPS/speed same simulated duration")
			var reward_coins: int = game.coins
			game._finish_battle(true)
			check(game.coins == reward_coins,"No duplicate victory payout")
			game._restart_demo()
			check(game.heroes.is_empty() and game.enemies.is_empty() and game.combat.missiles.is_empty() and game.moving.is_empty() and game.coins == 10 and game.battle_speed == 1 and not game.battle_paused,"Restart clears transient state")
			game.queue_free()
			await process_frame
	game = make_game()
	game._on_shop_pressed(3)
	game._place_hero_on_board(game.heroes[0],Vector2i(4,6))
	game._start_battle()
	game.escort.health = 1
	for tick in range(60*90):
		game.step(1.0/60)
		if game.state == game.GameState.RESULT: break
	check(game.escort.dead and game.state == game.GameState.RESULT and game.coins == 9,"Loss grants no loot")
	game.queue_free()
	await process_frame
	print("DEMO_INTEGRATION: failures=%d result=%s" % [failures.size(),reference])
	quit(0 if failures.is_empty() else 1)
