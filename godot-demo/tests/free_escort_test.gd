extends SceneTree
var failures := 0
const Map = preload("res://scripts/data/escort_map.gd")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func fresh():
	var game = load("res://scenes/free_escort.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.audio_feedback.enabled = false
	return game
func recruit(game) -> void:
	for i in range(3): game._on_shop_pressed(i)
	var origin: Vector2 = game.escort.position
	for i in range(3):
		check(game._place_free(game.heroes[i],origin+Vector2(45+i*32,-35)),"free deployment %d" % i)
	check(Map.tile_at(game.heroes[0].position)==Map.tile_at(game.heroes[1].position),"two heroes coexist within one old cell at spaced continuous positions")
func quiet(game) -> void:
	game._start_battle()
	game.intermission = 10000
func battle(fps: int, speed: float, intervene: bool) -> Dictionary:
	var game = fresh()
	recruit(game)
	game._start_battle()
	game.battle_speed = speed
	var next_order := 3.0
	var camps := 0
	for frame in range(int(240*fps/speed)):
		if game.state == game.GameState.RESULT: break
		if game.state == game.GameState.PREPARING:
			camps += 1
			check(game.shop_types.size()==3,"camp shop three")
			check(game.brains.is_empty() and game.enemy_motion.is_empty(),"camp clears AI")
			check(game.escort.health>0,"camp keeps escort health")
			game._start_battle()
		if intervene and game.battle_elapsed >= next_order:
			next_order += 2.0
			for i in range(game.heroes.size()):
				var hero = game.heroes[i]
				if hero.battle_dead or game._brain(hero).mode == "手动": continue
				# Simulated player issues occasional legal relocation, not auto AI.
				if hero.position.distance_to(game.escort.position) < 120: continue
				var destination: Vector2 = game._near_free(game.escort.position+Vector2(30+i*36,-45),hero)
				if destination != Vector2.INF: game._command_free(hero,destination)
		game.step(1.0/fps)
		if "--trace" in OS.get_cmdline_user_args() and game.wave_index==3 and frame%(fps*4)==0:
			for actor in game.heroes:
				print("TRACE ",game.battle_elapsed," ",actor.unit_type," hp=",actor.health," p=",actor.position," brain=",game.brains.get(actor,{}))
	var result := {"done":game.state==game.GameState.RESULT,"hp":game.escort.health,"route":game.route_index,"wave":game.wave_index,"loot":game.earned_loot,"time":game.battle_elapsed,"camps":camps,"attacks":game.combat.counts.attacks,"engaged":game.auto_engagements,"manual":game.manual_completions}
	print("FREE_RUN %d x%.1f manual=%s: %s" % [fps,speed,intervene,result])
	check(result.done,"four-stage run reaches result")
	if intervene:
		check(result.route==25 and result.camps==3,"four-stage loop reaches B with three camps")
		check(result.hp>0 and result.loot==20,"manual intervention can win all four stages")
	game.free()
	return result

func behaviors() -> void:
	var game = fresh()
	recruit(game)
	quiet(game)
	var center := Map.center(Vector2i(3,8))
	game.escort.position = center
	var monk = game.heroes[0]
	var hunter = game.heroes[1]
	var healer = game.heroes[2]
	monk.position = center+Vector2(0,60)
	hunter.position = center+Vector2(-100,0)
	healer.position = center+Vector2(-80,60)
	for actor in game.heroes: game.guard_anchors[actor] = actor.position
	game._spawn_enemy("boar",Vector2i(3,10))
	var enemy = game.enemies[0]
	enemy.position = center+Vector2(130,0)
	enemy.health = 100000
	enemy.max_health = 100000
	enemy.damage = 0
	enemy.move_interval = 100000
	for i in range(480): game.step(1.0/120)
	check(game.auto_engagements>=2,"melee and ranged acquire automatically")
	check(game._brain(healer).mode != "接战" and game._brain(healer).target==null,"healer never chases an enemy")
	check(hunter.position.distance_to(enemy.position)>game.Rules.RANGE_UNIT,"ranged stops before melee distance")
	check(monk.position.distance_to(enemy.position)<=game._range(monk)+8,"melee approaches")
	var held_target = game._brain(hunter).target
	game.step(0.2)
	check(game._brain(hunter).target==held_target,"target lock persists")
	var retreat := center+Vector2(-190,20)
	check(game._command_free(monk,retreat),"manual retreat during engagement")
	for i in range(60):
		game.step(1.0/120)
		check(game._brain(monk).mode=="手动" and game._brain(monk).goal==retreat,"AI cannot override manual retreat")
	check(not game.combat.strikes.any(func(strike): return strike.source==monk),"manual cancels unreleased attack")
	var heal_destination := center+Vector2(-160,-40)
	monk.health = 50
	check(game._command_free(healer,heal_destination),"healer manual retreat accepted")
	game.step(0.2)
	check(game._brain(healer).mode=="手动" and not game.combat.strikes.any(func(strike): return strike.source==healer),"healing never interrupts manual movement")
	var brain: Dictionary = game._brain(hunter)
	brain.chase = game.Rules.CHASE_SECONDS+1
	game.step(0.02)
	check(brain.mode=="归位" and brain.skip.has(enemy.get_instance_id()),"chase timeout returns and applies retry hysteresis")
	brain.mode = "接战"
	brain.target = enemy
	brain.chase = 0
	enemy.position = center+Vector2(400,0)
	game.step(0.02)
	check(brain.mode=="归位","leash independently limits chase")
	game._finish_battle(false)
	check(game.brains.is_empty() and game.enemy_motion.is_empty(),"result clears AI")
	game._restart_demo()
	check(game.heroes.is_empty() and game.enemies.is_empty() and game.spawn_queue.is_empty(),"restart clears all actors and queued threats")
	game.free()

func economy() -> void:
	var game = fresh()
	game._on_refresh_pressed()
	check(game.coins==1 and game.shop_types.size()==3,"free-mode paid three-slot refresh")
	var stock: Array = game.shop_types.duplicate()
	game._on_refresh_pressed()
	check(game.coins==1 and game.shop_types==stock,"insufficient refresh preserves stock")
	game._restart_demo()
	recruit(game)
	game._start_battle()
	var monk = game.heroes[0]
	var kept: Vector2 = monk.position
	game.heroes[2].take_damage(10000)
	game.pending_loot = 3
	game._enter_wave_preparation()
	check(game.coins==3 and game.heroes[2].run_fallen and game.heroes[2].health==0 and game.casualties.seats.has(2),"camp reward keeps fallen healer and blocked population")
	check(monk.position==kept,"camp preserves continuous position")
	game.shop_types.assign(["guard_monk","guard_monk","foxfire_imp"])
	game._on_shop_pressed(0)
	game._on_shop_pressed(1)
	check(monk.star==2 and game.heroes.size()==3 and monk.position==kept,"three-to-one retains continuous keeper")
	game._start_battle()
	game.pending_loot = 4
	game._enter_wave_preparation()
	game._on_level_pressed()
	check(game.population==4 and game.coins==1,"population upgrade same price")
	game.shop_types[0] = "foxfire_imp"
	game._on_shop_pressed(0)
	var fox = game.heroes.back()
	var point: Vector2 = game._near_free(game.escort.position+Vector2(0,90),fox)
	check(game._place_free(fox,point) and game._deployed_count()==4,"fourth continuous deployment")
	game._select_hero(fox)
	game._toggle_selected_lock()
	check(fox.merge_locked,"merge lock retained")
	game._sell_selected()
	check(game.coins==1 and game.heroes.size()==3,"sale retained")
	game.free()


func obstruction() -> void:
	var game = fresh()
	var center := Map.center(Vector2i(3,8))
	game._on_shop_pressed(0)
	var monk = game.heroes[0]
	check(game._place_free(monk,game.escort.position+Vector2(50,0)),"blocked test deployment")
	quiet(game)
	monk.position = center
	game.escort.position = center+Vector2(-100,0)
	var goal := center+Vector2(130,0)
	check(game._command_free(monk,goal),"accept before dynamic obstruction")
	game._spawn_enemy("boar",Vector2i(3,10))
	var enemy = game.enemies[0]
	enemy.position = goal
	enemy.move_interval = 100000
	enemy.damage = 0
	for i in range(720):
		game.step(1.0/120)
		if game._brain(monk).mode != "手动": break
	check(game._brain(monk).mode != "手动" and "无法抵达" in game.command_note,"persistent dynamic obstruction reports and releases command")
	# Priority transit cannot deadlock the escort behind friendly crowding.
	enemy.take_damage(10000)
	game._restart_demo()
	recruit(game)
	game._start_battle()
	game.intermission = 0
	game.spawn_queue.assign(["wolf"])
	game.spawn_entries.assign([Map.ENTRIES[0][0]])
	game.spawn_cooldown = 999
	var origin: Vector2 = game.escort.position
	for actor in game.heroes: actor.position = origin+Vector2(20,0)
	for i in range(720): game.step(1.0/120)
	check(game.escort.position.distance_to(origin)>70 and game.route_index>=1,"crowded narrow route never permanently blocks escort")
	for actor in game.heroes: check(game.space.valid(actor.position),"crowded actor stays on land")
	# At B, pending waves still prohibit victory.
	game.route_index = Map.CHECKPOINTS[0]
	game._process_wave(0.01)
	check(game.state==game.GameState.BATTLE_RUNNING,"pending spawn prevents premature camp")
	game.escort.take_damage(10000)
	game.step(0.02)
	check(game.state==game.GameState.RESULT and game.earned_loot==0,"failure does not pay uncleared wave")
	game.free()
func run() -> void:
	var game = fresh()
	check(game.coins==3 and game.shop_types.size()==3,"initial economics")
	recruit(game)
	# Isolate precise landing assertions from other allies' autonomous guarding.
	game._place_hero_on_bench(game.heroes[1],0)
	game._place_hero_on_bench(game.heroes[2],1)
	quiet(game)
	var hero = game.heroes[0]
	var center := Map.center(Vector2i(7,2))
	var first := center+Vector2(-15,-5)
	var second := center+Vector2(15,5)
	check(Map.tile_at(first)==Map.tile_at(second),"same old tile fixture")
	for destination in [first,second]:
		check(game._command_free(hero,destination),"accept distinct continuous point")
		for i in range(600):
			game.step(1.0/120)
			if game._brain(hero).mode != "手动": break
		check(hero.position.distance_to(destination)<0.1,"arrive exact non-snapped point")
	check(game.manual_completions==2,"both arrivals resume automatic")
	var route: PackedVector2Array = game.space.path(Map.center(Vector2i(8,2)),Map.center(Vector2i(8,17)))
	check(route.size()>1,"route detours around water")
	var previous := Map.center(Vector2i(8,2))
	for point in route:
		check(game.space.clear(previous,point),"every route segment stays on land")
		previous = point
	check(not game.space.valid(Vector2(1050,680)),"water is invalid")
	# Regression: visibility sampling formerly cut a tiny concave shore corner
	# and stranded the monk forever at (1452.378,269.3621).
	var corner_start := Vector2(1439.96,249.4496)
	var corner_end := Vector2(1540.249,553.898)
	var corner_path: PackedVector2Array = game.space.path(corner_start,corner_end)
	check(not corner_path.is_empty(),"shore corner has a detour")
	var cursor := corner_start
	for point in corner_path:
		while cursor.distance_to(point)>0.01:
			var next := cursor.move_toward(point,0.65)
			check(game.space.clear(cursor,next),"smoothed route must remain clear at each movement increment")
			cursor = next
	var destination := Map.center(Vector2i(3,4))+Vector2(12,-7)
	check(game._command_free(hero,destination),"manual route accepted")
	check(not game._command_free(hero,Vector2(100,100)),"invalid point rejected")
	check(game._brain(hero).goal==destination,"invalid retains prior order")
	game._toggle_pause()
	var frozen: Vector2 = hero.position
	var replacement := center+Vector2(20,10)
	check(game._command_free(hero,replacement),"paused replacement accepted")
	game.step(1)
	check(hero.position==frozen,"pause freezes simulation")
	check(game._brain(hero).goal==replacement,"new command overrides")
	game._toggle_pause()
	game.step(0.1)
	check(hero.position != frozen,"resume moves")
	hero.take_damage(9999)
	game.step(0.02)
	check(not game.brains.has(hero),"death clears command")
	game._restart_demo()
	check(game.brains.is_empty() and game.enemy_motion.is_empty() and game.coins==3 and game.route_index==0,"restart isolates AI")
	game.free()
	behaviors()
	economy()
	obstruction()
	var automatic := battle(60,1,false)
	var sped := battle(120,2,false)
	check(automatic.hp==0 and automatic.manual==0,"stationary formation no longer follows Tang to automatic victory")
	check(automatic.hp==sped.hp and automatic.loot==sped.loot and automatic.route==sped.route,"fixed-clock auto results")
	var guided := battle(60,1,true)
	var guided_fast := battle(120,2,true)
	check(guided.hp==guided_fast.hp and guided.loot==guided_fast.loot,"fixed-clock commanded results")
	print("FREE_ESCORT_TEST failures=%d" % failures)
	quit(1 if failures else 0)
