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
	for index in range(3): game._on_shop_pressed(index)
	var cells := [Vector2i(7,1),Vector2i(9,1),Vector2i(9,2)]
	for i in range(3): game._place_hero_on_board(game.heroes[i],cells[i])
func put(game,hero,cell: Vector2i):
	hero.battle_cell = cell
	hero.position = game._cell_center(cell)
func key(game,code):
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = code
	game._unhandled_input(event)
func occupied_unique(game) -> bool:
	var used := {game.escort_tile:true}
	for actor in game.heroes+game.enemies:
		if not game.CombatEvents.alive(actor): continue
		if actor is EscortHero and not actor.active_in_battle: continue
		if not Map.valid(actor.battle_cell): return false
		# Moving allies may overlap; stopped actors must always have unique cells.
		if actor is EscortHero and game.transit.flights.has(actor): continue
		if used.has(actor.battle_cell): return false
		used[actor.battle_cell] = true
	return true

# This is a test input driver, never an in-game follow/auto-move feature.
func direct_team(game) -> void:
	var next: Vector2i = Map.ROUTE[mini(game.route_index+1,Map.ROUTE.size()-1)]
	for hero in game.heroes:
		if not hero.active_in_battle or hero.battle_dead or game._is_moving(hero): continue
		var target: Vector2i = game.escort_tile
		if hero.unit_type != "herbal_spirit_child" and not game.enemies.is_empty():
			var nearest := 999
			for enemy in game.enemies:
				var distance: int = game._cell_distance(hero.battle_cell,enemy.battle_cell)
				if distance < nearest:
					nearest = distance
					target = enemy.battle_cell
		var best := INF
		var chosen: Vector2i = hero.battle_cell
		for cell in Map.cells():
			if cell == next or cell in game.spawn_entries or game.transit.stop_blocked(cell,hero): continue
			var distance: int = game._cell_distance(cell,target)
			if distance > hero.attack_range_cells: continue
			var route: Array = game.transit.path(hero,cell)
			if route.is_empty(): continue
			var score: float = route.size() + game._cell_distance(cell,game.escort_tile)*0.25
			if score < best:
				best = score
				chosen = cell
		if chosen != hero.battle_cell: game._command_move(hero,chosen)

func play_route(fps := 60, speed := 1.0) -> Dictionary:
	var game = fresh()
	recruit(game)
	game._start_battle()
	game.battle_speed = speed
	var ticks := 0
	while game.state != game.GameState.RESULT and ticks < fps*240/int(speed):
		if game.state == game.GameState.PREPARING:
			check(game.pending_loot == 0 and game.shop_types.size()==3,"Camp pays once and stocks three")
			if game.wave_index == 0:
				for i in range(2):
					game.shop_types[i] = "guard_monk"
					game._on_shop_pressed(i)
				check(game.heroes[0].star == 2,"Camp purchases merge")
			elif game.wave_index == 1:
				game._on_level_pressed()
				check(game.population == 4,"Earned gold expands population")
				game.shop_types[0] = "foxfire_imp"
				game._on_shop_pressed(0)
				for cell in Map.cells():
					if game._can_deploy(cell) and game._hero_at_cell(cell)==null:
						game._place_hero_on_board(game.heroes.back(),cell)
						break
			game._start_battle()
		if ticks % maxi(1,fps/2/int(speed)) == 0: direct_team(game)
		game.step(1.0/fps)
		if not occupied_unique(game):
			check(false,"No stationary overlap/off-map actors")
			break
		ticks += 1
	var result := {"done":game.state==game.GameState.RESULT,"hp":game.escort.health,"route":game.route_index,"wave":game.wave_index,"loot":game.earned_loot,"time":game.battle_elapsed}
	check(result.done and result.hp>0 and result.route==Map.CHECKPOINTS[-1],"Legal input strategy finishes A to B")
	print("ROUTE_RUN ",fps," x",speed,": ",result)
	if not result.done:
		print("REMAINING queue=",game.spawn_queue," entries=",game.spawn_entries," flights=",game.transit.flights.size()," orders=",game.orders)
		for actor in game.heroes+game.enemies: print(actor.name," ",actor.battle_cell," hp=",actor.health)
	game.free()
	return result

func run() -> void:
	var game = fresh()
	check(game.shop_types.size()==3 and game.shop_buttons.size()==3 and game.DemoUnits.SHOP.size()==5,"Three slots, five identities")
	for cell in Map.cells():
		check(game._screen_to_cell(game._cell_center(cell))==cell,"Draw/pick centre agreement")
		check(Map.tile_at(Map.rect(cell).position+Vector2(2,2))==cell,"Draw/pick corner agreement")
		check(game._navigation_distance(Map.ROUTE[0],cell)<999,"Map connected")
	for i in range(1,Map.ROUTE.size()): check(game._cell_distance(Map.ROUTE[i-1],Map.ROUTE[i])==1,"Adjacent route")
	check(not Map.valid(Vector2i(7,9)),"Chasm not walkable")
	game._set_shop_open(true)
	key(game,KEY_4); key(game,KEY_5)
	check(game.coins==3 and game.heroes.is_empty(),"4/5 cannot purchase")
	key(game,KEY_R)
	check(game.coins==1 and game.shop_types.size()==3,"First manual refresh charges two")
	var stock = game.shop_types.duplicate()
	key(game,KEY_R)
	check(game.coins==1 and game.shop_types==stock,"Unaffordable refresh preserves stock and money")
	game._restart_demo()
	game._on_refresh_pressed()
	check(game.coins==1,"Restart cannot grant free refresh")
	game._restart_demo()
	recruit(game)
	game._start_battle()
	game.intermission = 999
	var a = game.heroes[0]; var b = game.heroes[1]; var c = game.heroes[2]
	put(game,a,Vector2i(4,3)); put(game,b,Vector2i(4,4)); put(game,c,Vector2i(4,5))
	check(not game._command_move(a,b.battle_cell),"Occupied final cell rejected")
	check(game._command_move(a,Vector2i(4,6)),"Can route through two allies")
	var origin: Vector2 = a.position
	game.step(.6)
	check(a.position!=origin and game.transit.flights.has(a),"Continuous movement started")
	check(a.battle_cell==b.battle_cell,"Pause fixture is actually inside an allied tile")
	game._toggle_pause()
	var frozen: Vector2 = a.position
	game._select_hero(a); key(game,KEY_ESCAPE)
	game.step(2)
	check(a.position==frozen and not game.orders.has(a),"Pause freezes transit; Escape cancels future order")
	game._toggle_pause(); game.step(2)
	check(a.battle_cell==Vector2i(4,6) and not game._is_moving(a),"Cancel lands beyond allies, never overlaps")
	check(b.battle_cell==Vector2i(4,4) and c.battle_cell==Vector2i(4,5),"Stationary allies never pushed")
	put(game,a,Vector2i(4,3)); put(game,b,Vector2i(4,6)); put(game,c,Vector2i(4,4))
	check(game._command_move(a,Vector2i(4,8)) and game._command_move(b,Vector2i(4,2)),"Opposite direction orders accepted")
	check(not game._command_move(c,Vector2i(4,8)),"Competing endpoint rejected")
	for i in range(360):
		game.step(1.0/60)
		check(occupied_unique(game),"Opposite transit keeps unique legal stops")
	check(a.battle_cell==Vector2i(4,8) and b.battle_cell==Vector2i(4,2),"Opposite movers arrive")
	put(game,a,Vector2i(4,3)); put(game,b,Vector2i(4,4)); put(game,c,Vector2i(4,5))
	check(game._command_move(a,Vector2i(4,8)) and game._command_move(b,Vector2i(4,9)),"Same direction convoy orders")
	game.step(.25)
	check(game.transit.blocks_enemy(Vector2i(4,5)),"In-transit cells block enemies and escort")
	game._toggle_pause()
	game._select_hero(a); key(game,KEY_ESCAPE)
	game._select_hero(b); key(game,KEY_ESCAPE)
	game._toggle_pause()
	game.step(3)
	check(occupied_unique(game) and game.transit.flights.is_empty(),"Convoy cancellation resolves to distinct safe landings")
	put(game,a,Vector2i(4,8)); put(game,b,Vector2i(4,2))
	game._spawn_enemy("boar",Vector2i(4,7))
	check(not game._command_move(a,Vector2i(4,7)),"Enemy blocks destination")
	var detour = game.transit.path(a,Vector2i(4,6))
	check(not detour.has(Vector2i(4,7)),"Cannot transit enemy cell")
	game.enemies[0].take_damage(9999)
	game._command_move(a,Vector2i(4,10)); game.step(.1)
	a.take_damage(9999); game.step(.1)
	check(not game.transit.flights.has(a),"Death releases transit reservations")
	game._restart_demo(); recruit(game); game._start_battle(); game.intermission=999
	put(game,game.heroes[0],Map.ROUTE[1])
	game.escort_clock=Map.STEP_SECONDS
	game._advance_escort(.1)
	check(game.route_index==0,"Escort still respects actual friendly occupation")
	put(game,game.heroes[0],Vector2i(7,1))
	game._spawn_enemy("boar",Vector2i(8,0))
	game._advance_escort(.1)
	check(game.route_index==1,"Adjacent enemy alone cannot stop escort")
	# Final checkpoint cannot win with a pending enemy, even at zero on-screen threats.
	for enemy in game.enemies: enemy.free()
	game.enemies.clear(); game.moving.clear()
	game.route_index=Map.CHECKPOINTS[-1]; game.escort_tile=Map.ROUTE[-1]; game.wave_index=3
	game.escort.position=Map.center(game.escort_tile); game.intermission=0
	game.spawn_queue.assign(["rat"]); game.spawn_entries.assign([Vector2i(8,18)]); game.spawn_cooldown=10
	game._process_wave(.1)
	check(game.state==game.GameState.BATTLE_RUNNING,"Pending threats prevent final victory")
	game.escort.take_damage(9999); game.step(.1)
	check(game.state==game.GameState.RESULT,"Escort death is failure")
	game._restart_demo()
	check(game.coins==3 and game.transit.flights.is_empty() and game.orders.is_empty() and game.route_index==0,"Restart resets all movement/economy")
	game.free()
	var normal = play_route()
	var slow = play_route(30)
	var fast = play_route(120,2.0)
	check(is_equal_approx(normal.hp,slow.hp) and is_equal_approx(normal.hp,fast.hp) and normal.loot==fast.loot,"Frame rate and speed outcomes agree")
	print("ESCORT_ROUTE_TEST failures=",failures," cells=",Map.cells().size())
	quit(1 if failures else 0)
