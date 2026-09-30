extends SceneTree

var failures := 0
const Map = preload("res://scripts/data/escort_map.gd")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void: call_deferred("run")

func fresh():
	var game = load("res://scenes/escort_route.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.audio_feedback.enabled = false
	return game

func recruit(game):
	for index in [0,2,3]: game._on_shop_pressed(index)
	var cells := [Vector2i(3,1),Vector2i(5,1),Vector2i(5,2)]
	for i in range(3): game._place_hero_on_board(game.heroes[i],cells[i])

func occupied_unique(game) -> bool:
	var used := {game.escort_tile:true}
	for actor in game.heroes+game.enemies:
		if not game.CombatEvents.alive(actor): continue
		if actor is EscortHero and not actor.active_in_battle: continue
		if used.has(actor.battle_cell): return false
		if not Map.valid(actor.battle_cell): return false
		used[actor.battle_cell] = true
	return true

# A deterministic test driver issuing only the same legal orders as the player.
func direct_team(game) -> void:
	var next: Vector2i = Map.ROUTE[mini(game.route_index+1,Map.ROUTE.size()-1)]
	for hero in game.heroes:
		if not hero.active_in_battle or hero.battle_dead or game._is_moving(hero): continue
		var best := INF
		var chosen: Vector2i = hero.battle_cell
		for cell in Map.cells():
			if cell == next or cell == game.escort_tile or game._cell_blocked(cell,hero): continue
			var path = game._combat_path(hero,cell,0,false)
			if path.is_empty(): continue
			var score: float = path.size()*0.4 + game._cell_distance(cell,game.escort_tile)*0.7
			if hero.unit_type == "herbal_spirit_child":
				for ally in game.heroes+[game.escort]:
					if not game.CombatEvents.alive(ally): continue
					var ally_cell: Vector2i = game.escort_tile if ally == game.escort else ally.battle_cell
					if ally.health < ally.max_health: score += max(0,game._cell_distance(cell,ally_cell)-hero.attack_range_cells)*5
			elif not game.enemies.is_empty():
				var enemy_distance := 999
				for enemy in game.enemies: enemy_distance = mini(enemy_distance,game._cell_distance(cell,enemy.battle_cell))
				score += max(0,enemy_distance-hero.attack_range_cells)*7
			if score < best:
				best = score
				chosen = cell
		if chosen != hero.battle_cell: game._command_move(hero,chosen)

func play_route(active: bool, fps := 60, speed := 1.0) -> Dictionary:
	var game = fresh()
	recruit(game)
	game._start_battle()
	game.battle_speed = speed
	var ticks := 0
	while game.state != game.GameState.RESULT and ticks < fps*300/int(speed):
		if game.state == game.GameState.PREPARING:
			check(game.pending_loot == 0,"Camp loot settles once")
			if game.wave_index == 0:
				# Controlled shop stock: buy two copies with earned gold, no injected money.
				for i in range(2):
					game.shop_types[i] = "guard_monk"
					game._on_shop_pressed(i)
				check(game.heroes[0].star == 2,"Three-of-a-kind merges at camp")
			if game.wave_index == 1:
				game._on_level_pressed()
				check(game.population == 4,"Earned gold buys population upgrade")
				game.shop_types[0] = "foxfire_imp"
				game._on_shop_pressed(0)
				for cell in Map.cells():
					if game._can_deploy(cell) and game._hero_at_cell(cell) == null:
						game._place_hero_on_board(game.heroes.back(),cell)
						break
			game._start_battle()
		if active and ticks % (fps/2/int(speed)) == 0: direct_team(game)
		game.step(1.0/fps)
		check(occupied_unique(game),"No overlapping or off-map living actors")
		ticks += 1
	var result := {"done":game.state == game.GameState.RESULT,"hp":game.escort.health,"route":game.route_index,"wave":game.wave_index,"loot":game.earned_loot,"time":game.battle_elapsed}
	if active: check(result.done and result.hp > 0 and result.route == 12,"Commanded team can finish A to B")
	print("ROUTE_RUN ",active," ",fps,"fps x",speed,": ",result)
	game.free()
	return result

func run() -> void:
	var game = fresh()
	check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/escort_route.tscn","Default entry is new escort mode")
	check(not Map.valid(Vector2i(4,5)),"Water cannot be occupied")
	for cell in Map.cells():
		check(game._screen_to_cell(game._cell_center(cell)) == cell,"Tile draw/pick agreement")
		check(game._navigation_distance(Map.ROUTE[0],cell) < 999,"Every tile is connected")
	for i in range(1,Map.ROUTE.size()): check(game._cell_distance(Map.ROUTE[i-1],Map.ROUTE[i]) == 1,"Escort route uses adjacent land")
	game._start_battle()
	check(game.state == game.GameState.PREPARING,"Cannot start with no units")
	recruit(game)
	check(game.coins == 0 and game._deployed_count() == 3,"Recruitment economy preserved")
	game._start_battle()
	game.intermission = 999
	var hero = game.heroes[0]
	var origin: Vector2 = hero.position
	var target := Vector2i(2,2)
	check(game._command_move(hero,target),"Legal command accepted")
	check(hero.position == origin,"Orders do not teleport")
	check(not game._command_move(hero,Vector2i(4,5)),"Reject water")
	check(not game._command_move(hero,game.escort_tile),"Reject occupied escort tile")
	game._toggle_pause()
	game._select_hero(hero)
	var right_click := InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	right_click.pressed = true
	right_click.position = game._cell_center(Vector2i(2,1))
	game._unhandled_input(right_click)
	check(game.orders[hero] == Vector2i(2,1),"Right-click command accepted while paused")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	game._unhandled_input(escape)
	check(not game.orders.has(hero) and game.selected_hero == null,"Escape cancels order and selection")
	game._command_move(hero,target)
	game.step(2)
	check(hero.position == origin,"Paused movement stays frozen")
	game._toggle_pause()
	game.step(0.02)
	check(game._is_moving(hero),"Order executes after resume")
	check(game._cell_blocked(Vector2i(3,1),game.heroes[1]),"Move reserves source")
	check(game._cell_blocked(hero.battle_cell,game.heroes[1]),"Move reserves destination")
	game.step(4)
	check(hero.battle_cell == target and hero.position == game._cell_center(target),"Multi-tile path reaches destination")
	var idle_cell: Vector2i = hero.battle_cell
	game.step(3)
	check(hero.battle_cell == idle_cell,"Arrival means hold position, no automatic chase")
	# Escort movement and friendly obstruction.
	game._command_move(hero,Vector2i(4,2))
	game.step(4)
	game.escort_clock = Map.STEP_SECONDS
	game._advance_escort(0.1)
	check(game.route_index == 0 and "被占" in game.escort_reason,"Escort waits behind friendly blocker")
	game._command_move(hero,Vector2i(3,2))
	game.step(3)
	game._advance_escort(0.1)
	check(game.route_index == 1 and game._is_moving(game.escort),"Escort advances after route clears")
	check(game._cell_blocked(Map.ROUTE[0],hero),"Moving escort source reserved")
	game.step(1)
	game.escort_hold = true
	game._advance_escort(10)
	check(game.route_index == 1,"Manual hold works")
	# Spawn cannot overlap a unit, and retries after it vacates.
	game.spawn_queue.assign(["rat"])
	game.spawn_entries.assign([hero.battle_cell])
	game.spawn_cooldown = 0
	game.intermission = 0
	game._process_wave(0.1)
	check(game.enemies.is_empty() and game.spawn_queue.size() == 1,"Occupied spawn waits without discarding enemy")
	game._command_move(hero,Vector2i(2,2))
	game.step(2)
	check(game.spawn_queue.is_empty() and (game.enemies.size() == 1 or game.pending_loot == 1) and occupied_unique(game),"Enemy spawns after tile clears (may already be defeated)")
	# Winning requires travel, not only killing the last enemy.
	game.spawn_queue.clear()
	for enemy in game.enemies: enemy.free()
	game.enemies.clear()
	game._process_wave(0.1)
	check(game.state == game.GameState.BATTLE_RUNNING,"Empty map does not finish before reaching checkpoint")
	game.escort.take_damage(9999)
	game.step(0.1)
	check(game.state == game.GameState.RESULT,"Escort death ends route")
	game._restart_demo()
	check(game.route_index == 0 and game.escort.position == game._cell_center(Map.ROUTE[0]) and game.coins == 3 and game.orders.is_empty(),"Restart restores route and economy")
	game.free()
	# Seal the bridge: enemies must approach its defenders, not stall at spawn.
	game = fresh()
	recruit(game)
	game._start_battle()
	game.intermission = 999
	game.escort_tile = Vector2i(2,5)
	game.escort.position = game._cell_center(game.escort_tile)
	for i in range(2):
		game.heroes[i].battle_cell = Vector2i(1+i,4)
		game.heroes[i].position = game._cell_center(game.heroes[i].battle_cell)
	game._spawn_enemy("wolf",Vector2i(1,2))
	var enemy = game.enemies[0]
	check(game._combat_path(enemy,game.escort_tile,1,false).is_empty(),"Bridge defenders seal escort approach")
	game._move_enemy_toward_center(enemy)
	check(game._is_moving(enemy),"Blocked enemy advances toward defender")
	var hp: float = game.heroes[0].health
	game.heroes[0].battle_cell = Vector2i(0,8)
	game._apply_combat_event(game.heroes[0],10,false,{"source":enemy,"splash":false})
	check(game.heroes[0].health == hp,"Out-of-reach melee strike cannot hit a repositioned target")
	game.free()
	var active = play_route(true)
	var idle = play_route(false)
	check(active.hp > idle.hp or active.route > idle.route,"Real commands materially improve escort outcome")
	var slow = play_route(true,30)
	var fast = play_route(true,120,2.0)
	check(is_equal_approx(active.hp,slow.hp) and is_equal_approx(active.hp,fast.hp) and active.loot == fast.loot,"Frame rate / speed outcomes agree")
	print("ESCORT_ROUTE_TEST: failures=",failures)
	quit(1 if failures else 0)
