extends "res://tests/camp_roster_test.gd"
## Boundary fixtures use actual attack requests, pose timing and damage events.
## No direct casualty registration or production balance changes are used.

func kill_in_combat(game, hero) -> void:
	game.combat.clear()
	var cooldowns := {}
	for ally in game.heroes:
		cooldowns[ally] = ally.cooldown
		ally.cooldown = 10000
	game._spawn_enemy("boar",Map.ROUTE[0])
	var enemy = game.enemies.back()
	enemy.position = hero.position+Vector2(20,0)
	hero.health = 1 # Wounded-hero fixture; enemy retains normal production damage.
	game.combat.request(enemy,hero)
	for frame in range(120):
		game.step(1.0/120)
		if hero.run_fallen: break
	check(hero.run_fallen and hero.health==0,"real enemy attack registers death")
	for ally in cooldowns:
		if is_instance_valid(ally): ally.cooldown = cooldowns[ally]
	for threat in game.enemies: threat.queue_free()
	game.enemies.clear()
	game.combat.clear()

func reach_camp(game) -> void:
	game.intermission = 0
	game.spawn_queue.clear()
	game.spawn_entries.clear()
	game.route_index = Map.CHECKPOINTS[game.wave_index]
	game.escort.position = Map.center(Map.ROUTE[game.route_index])
	game.step(1.0/120)
	check(game.state==game.GameState.PREPARING,"checkpoint and cleared threats enter real camp transition")

func run() -> void:
	recovery_and_capacity()
	last_enemy_same_tick(false)
	last_enemy_same_tick(true)
	pending_heal()
	pending_arrow()
	simultaneous_projectiles()
	full_bench_loss()
	zero_survivors()
	legacy_recovery()
	print("RUN_CASUALTIES_TEST failures=",failures)
	quit(1 if failures else 0)

func recovery_and_capacity() -> void:
	var game = fresh()
	recruit(game)
	quiet(game)
	var fallen = game.heroes[0]
	var survivor = game.heroes[1]
	game._select_hero(fallen)
	game.pointer_hero = fallen
	# Stale preparation gesture fixture must also be cleaned synchronously.
	game.swap_source = fallen
	game.swap_star = fallen.star
	kill_in_combat(game,fallen)
	check(game.selected_hero==null and game.swap_source==null and game.pointer_hero==null and not game.brains.has(fallen),"death immediately cancels source selection, exchange and orders")
	var original: Dictionary = game.casualties.seats.duplicate(true)
	var star: int = fallen.star
	var hp_max: float = fallen.max_health
	fallen.heal(10000)
	fallen.upgrade()
	fallen._apply_stats()
	fallen.end_battle()
	fallen.begin_battle()
	var attacks: int = game.combat.counts.attacks
	game.combat.request(fallen,survivor,true)
	fallen.play_attack()
	check(fallen.health==0 and fallen.battle_dead and not fallen.active_in_battle and fallen.star==star and fallen.max_health==hp_max and game.combat.counts.attacks==attacks,"all hero recovery/upgrade/attack/heal entry points retain casualty")
	game._register_casualty(fallen)
	game._sync_casualties()
	check(game.casualties.seats==original,"repeated death registration is idempotent")
	survivor.health = 12.5
	reach_camp(game)
	check(survivor.health==survivor.max_health and fallen.health==0 and game._deployed_count()==3 and game._living_deployed_count()==2,"camp heals living heroes, not loss; occupied population remains three")
	game.coins = 50 # Explicit management boundary wallet, not a natural reward.
	game._select_hero(fallen)
	var wallet: int = game.coins
	var count: int = game.heroes.size()
	game._withdraw_selected()
	game._begin_swap()
	game._sell_selected()
	game._toggle_selected_lock()
	game._place_hero_on_bench(fallen,0)
	check(fallen.board_row>=0 and fallen.bench_slot==-1 and game.heroes.size()==count and game.coins==wallet and game.swap_source==null,"dead R/F/sell/lock/bench paths cannot release seat or refund")
	for i in range(2): purchase(game,"guard_monk")
	check(fallen in game.heroes and fallen.star==1 and game.heroes.size()==5,"two same-identity purchases do not merge with fallen copy")
	var reserve = purchase(game,"guard_monk")
	reserve = game._hero_in_bench(0)
	check(reserve.star==2 and fallen in game.heroes and game.heroes.size()==4,"three new living copies merge separately without consuming casualty")
	var lost_point: Vector2 = original[0].position
	check(not game._place_free(reserve,lost_point) and not game._place_free(fallen,lost_point),"neither new same-identity hero nor fallen hero fills blocked coordinate")
	game._select_hero(survivor)
	game._begin_swap()
	check(not game._swap_heroes(fallen),"living source cannot exchange with casualty target")
	game._cancel_swap()
	# Independent snapshot survives loss of both corpse and its slot reference.
	game.heroes.erase(fallen)
	game.hero_slots[0] = null
	fallen.free()
	game._update_ui()
	check(game.roster_hud.slots[0].permanent and game.roster_hud.slots[0].hp==0 and game._deployed_count()==3,"destroyed corpse retains identity, HUD, number and population")
	for camp in range(3):
		if camp > 0: reach_camp(game)
		check(game.casualties.seats==original and game.camp_positions.points[0]==lost_point,"casualty and blocked coordinate survive camp %d rebuild" % (camp+1))
		game._set_shop_open(false)
		game._set_shop_open(true)
		check(not game._place_free(reserve,lost_point),"shop/camp cannot restore lost seat")
		if camp == 0:
			game._on_level_pressed()
			var extra: Vector2 = game._near_free(game.escort.position+Vector2(20,70),reserve)
			check(game.population==4 and game._place_free(reserve,extra) and game.hero_slots.find(reserve)==3,"true population upgrade creates new seat without reusing blocked number")
			game._select_hero(reserve)
			game._withdraw_selected()
			check(not game._place_free(reserve,extra+Vector2(0,55)) and game._place_free(reserve,extra),"R on new living seat permits only exact original refill")
		game._start_battle()
		game.intermission = 10000
		game._toggle_pause()
		check(game.casualties.seats==original,"pause and next battle do not clear losses")
		game._toggle_pause()
	game._finish_battle(false)
	check(game.casualties.seats==original,"result keeps run loss history")
	game._restart_demo()
	check(game.casualties.seats.is_empty() and game.casualties.actor_seats.is_empty() and game.camp_positions.points.is_empty() and game.coins==3 and game.population==3,"only complete-run restart resets casualties")
	game._on_shop_pressed(0)
	var new_actor = game.heroes[0]
	check(game._place_free(new_actor,game.escort.position+Vector2(50,-30)) and game.hero_slots[0]==new_actor and not new_actor.run_fallen,"new run restores ordinary slot-one deployment")
	game.free()

func last_enemy_same_tick(final_stage: bool) -> void:
	var game = fresh()
	game.shop_types[1] = "guard_monk"
	recruit(game)
	quiet(game)
	if final_stage: game.wave_index = 3
	game.intermission = 0
	game.route_index = Map.CHECKPOINTS[game.wave_index]
	game.escort.position = Map.center(Map.ROUTE[game.route_index])
	var victim = game.heroes[0]
	var striker = game.heroes[1]
	victim.health = 1
	game._spawn_enemy("boar",Map.ROUTE[0])
	var last_enemy = game.enemies[0]
	last_enemy.position = victim.position+Vector2(20,0)
	last_enemy.health = 1
	game.combat.request(last_enemy,victim)
	game.combat.request(striker,last_enemy)
	last_enemy.presentation.pose_time = last_enemy.presentation.impact_delay()
	striker.presentation.pose_time = striker.presentation.impact_delay()
	game._tick(1.0/120)
	check(victim.run_fallen and victim.health==0 and game.casualties.seats.has(0),"hero and last enemy die in same combat tick before lifecycle transition")
	check(game.state==(game.GameState.RESULT if final_stage else game.GameState.PREPARING),"same-tick death survives %s transition" % ("victory" if final_stage else "camp"))
	game.free()

func pending_heal() -> void:
	var game = fresh()
	recruit(game)
	quiet(game)
	var healer = game.heroes[2]
	var patient = game.heroes[0]
	patient.health = 100
	healer.health = 1
	game.combat.request(healer,patient,true)
	healer.presentation.pose_time = healer.presentation.impact_delay()
	game.combat.tick(0.01)
	check(not game.combat.missiles.is_empty(),"real healing projectile released before source loss")
	game._spawn_enemy("boar",Map.ROUTE[0])
	var enemy = game.enemies[0]
	enemy.position = healer.position+Vector2(20,0)
	game.combat.request(enemy,healer)
	enemy.presentation.pose_time = enemy.presentation.impact_delay()
	game._tick(1.0/120)
	var hp: float = patient.health
	game.combat.tick(0.5)
	check(healer.run_fallen and game.combat.missiles.is_empty() and patient.health==hp and game.combat.counts.heals==0,"fallen healer's already released effect cannot heal later")
	game.free()

func zero_survivors() -> void:
	var game = fresh()
	recruit(game)
	quiet(game)
	for hero in game.heroes: kill_in_combat(game,hero)
	reach_camp(game)
	game._update_ui()
	check(game._living_deployed_count()==0 and game._deployed_count()==3 and not game.start_button.disabled and game._free_bench_slot()==0,"zero survivors and no usable population do not disable departure")
	game._start_battle()
	check(game.state==game.GameState.BATTLE_RUNNING and game.casualties.seats.size()==3,"zero-survivor camp can continue without reviving actors")
	for frame in range(120*90):
		game.step(1.0/120)
		if game.state==game.GameState.RESULT: break
	print("ZERO_SURVIVORS result=",game.state," TangHP=",game.escort.health," stage=",game.wave_index+1)
	check(game.state==game.GameState.RESULT and game.escort.dead and game.casualties.seats.size()==3,"ordinary enemies and Tang death still resolve the loss")
	game.free()

func pending_arrow() -> void:
	var game = fresh()
	recruit(game)
	quiet(game)
	var hunter = game.heroes[1]
	hunter.health = 1
	game._spawn_enemy("boar",Map.ROUTE[0])
	var target = game.enemies[0]
	target.position = hunter.position+Vector2(140,0)
	var hp: float = target.health
	game.combat.request(hunter,target)
	hunter.presentation.pose_time = hunter.presentation.impact_delay()
	game.combat.tick(0.01)
	check(game.combat.missiles.size()==1,"real arrow is in flight before source loss")
	game._spawn_enemy("boar",Map.ROUTE[0])
	var killer = game.enemies[1]
	killer.position = hunter.position+Vector2(20,0)
	game.combat.request(killer,hunter)
	killer.presentation.pose_time = killer.presentation.impact_delay()
	game._tick(1.0/120)
	game.combat.tick(0.5)
	check(hunter.run_fallen and target.health==hp and game.combat.missiles.is_empty(),"fallen archer's released arrow never damages its target")
	game.free()

func simultaneous_projectiles() -> void:
	var game = fresh()
	recruit(game)
	quiet(game)
	var healer = game.heroes[2]
	var patient = game.heroes[0]
	healer.health = 1
	patient.health = 100
	game._spawn_enemy("rat",Map.ROUTE[0])
	var killer = game.enemies[0]
	killer.position = healer.position+Vector2(100,0)
	game.combat.request(killer,healer)
	game.combat.request(healer,patient,true)
	killer.presentation.pose_time = killer.presentation.impact_delay()
	healer.presentation.pose_time = healer.presentation.impact_delay()
	game.combat.tick(0.01)
	check(game.combat.missiles.size()==2,"enemy stone and healing projectile coexist")
	game.combat.tick(0.25)
	check(healer.run_fallen and patient.health==100 and game.combat.counts.heals==0,"source death cancels later copied projectile in the same event batch")
	game.free()

func full_bench_loss() -> void:
	var game = fresh()
	recruit(game)
	quiet(game)
	var fallen = game.heroes[0]
	var living = game.heroes[1]
	kill_in_combat(game,fallen)
	reach_camp(game)
	game.coins = 50
	for actor in game.heroes: actor.merge_locked = true
	for i in range(8):
		var reserve = purchase(game,"guard_monk")
		reserve.merge_locked = true
	var incoming = game._hero_in_bench(7)
	var wallet: int = game.coins
	var copies: int = game.heroes.size()
	var losses: Dictionary = game.casualties.seats.duplicate(true)
	game._select_hero(fallen)
	game._begin_swap()
	check(not game._swap_with_bench(incoming),"full bench cannot exchange a fallen source")
	game._select_hero(living)
	game._withdraw_selected()
	check(living.board_row>=0 and game._free_bench_slot()<0,"living R still refuses full bench")
	game._begin_swap()
	check(not game._swap_heroes(fallen) and game._swap_with_bench(incoming),"full bench preserves living F while rejecting dead target")
	check(game.casualties.seats==losses and game._deployed_count()==3 and game.coins==wallet and game.heroes.size()==copies and living.bench_slot==7 and game.hero_slots[1]==incoming,"full-bench exchange cannot free loss or mint ownership/coins")
	game.free()

func legacy_recovery() -> void:
	for scene in ["res://scenes/escort_route.tscn","res://scenes/main.tscn"]:
		var game = load(scene).instantiate()
		root.add_child(game)
		game.set_process(false)
		game._on_shop_pressed(0)
		var hero = game.heroes[0]
		hero.take_damage(10000)
		hero.end_battle()
		check(not hero.run_fallen and not hero.battle_dead and hero.health==hero.max_health,"legacy mode retains original recovery: "+scene)
		game.free()
