extends "res://tests/board_trial_ai_test.gd"
## Isolated D-007 decisions plus an independent LIVE-AI road-release fixture.
## Does not replace full twelve-actor natural-deployment evidence.
const Melee = preload("res://scripts/combat/board_trial_melee.gd")
const Stepwise = preload("res://scripts/combat/board_trial_stepwise.gd")
const ENEMY_IDS := ["E1","E2","E3","E4"]
var dynamic_reports := []

func fixture(id: String, friends: Array = ["guard_monk"]):
	var game = fresh()
	game.start_battle()
	var live: Array = [id,"tangseng"]
	live.append_array(friends)
	isolate(game,live)
	var positions := {"tangseng":Vector2i(0,6),"guard_monk":Vector2i(7,3),"wild_hunter":Vector2i(0,0),"sparrow_spirit":Vector2i(0,1),"herbal_spirit_child":Vector2i(0,3),"foxfire_imp":Vector2i(0,2)}
	for key in positions:
		if game._active(game._record(key)): game._set_cell(game._record(key),positions[key])
	var enemy: Dictionary = game._record(id)
	game._set_cell(enemy,Vector2i(3,3))
	enemy.target = "guard_monk"
	for actor in game.actors:
		if game._active(actor): actor.cooldown = 10.0
	return game

func set_at(game, id: String, cell: Vector2i) -> Dictionary:
	var actor: Dictionary = game._record(id)
	game._set_cell(actor,cell)
	return actor

func adjacent_priority() -> void:
	for id in ENEMY_IDS:
		var game = fixture(id,["guard_monk","foxfire_imp","wild_hunter"])
		var enemy: Dictionary = game._record(id)
		set_at(game,"guard_monk",Vector2i(4,3))
		set_at(game,"foxfire_imp",Vector2i(3,2))
		set_at(game,"wild_hunter",Vector2i(3,4))
		enemy.think = Config.SCAN
		game._brain(enemy,Config.STEP)
		check(enemy.target=="guard_monk" and enemy.move.is_empty(),id+" current real range-one target keeps priority over other adjacent enemies")
		check(is_equal_approx(enemy.cooldown,10.0-Config.STEP) and game.metrics.attack_times.get(id,[]).is_empty(),id+" range-one cooldown dwell neither walks nor fabricates an attack")
		game.free()
		game = fixture(id,["guard_monk","sparrow_spirit"])
		enemy = game._record(id)
		set_at(game,"sparrow_spirit",Vector2i(3,4))
		enemy.think = Config.SCAN
		game._brain(enemy,Config.STEP)
		check(enemy.target=="sparrow_spirit" and enemy.move.is_empty(),id+" safe boundary adjacent enemy precedes distant pursuit even before SCAN expires")
		check(is_equal_approx(enemy.cooldown,10.0-Config.STEP),id+" target switch preserves original cooldown")
		game.free()
		game = fixture(id,["guard_monk","foxfire_imp","wild_hunter"])
		enemy = game._record(id)
		set_at(game,"foxfire_imp",Vector2i(3,2))
		set_at(game,"wild_hunter",Vector2i(3,4))
		game.actors.reverse() # Isolated single-brain oracle, not production order.
		game._brain(enemy,Config.STEP)
		check(enemy.target=="foxfire_imp" and enemy.move.is_empty(),id+" multiple adjacent candidates use stable ID, not storage order")
		game.free()

func active_segments() -> void:
	for id in ENEMY_IDS:
		var game = fixture(id,["guard_monk","foxfire_imp"])
		var enemy: Dictionary = game._record(id)
		set_at(game,"foxfire_imp",Vector2i(3,2))
		check(game._move(enemy,Vector2i(4,3)),id+" fixture starts real source move")
		var old_move: Dictionary = enemy.move.duplicate(true)
		game._brain(enemy,Config.STEP)
		check(enemy.target=="guard_monk" and enemy.move==old_move,id+" in-flight source keeps target and emitted segment despite adjacent alternative")
		game.free()
		game = fixture(id,["guard_monk","foxfire_imp"])
		enemy = game._record(id)
		var target := set_at(game,"guard_monk",Vector2i(4,3))
		enemy.cooldown = 0
		game._attack(enemy,target)
		check(enemy.node.presentation.pose=="basic_attack",id+" fixture starts actual production attack activity")
		set_at(game,"guard_monk",Vector2i(7,3))
		set_at(game,"foxfire_imp",Vector2i(3,2))
		game._brain(enemy,Config.STEP)
		check(enemy.target==target.id and enemy.move.is_empty() and enemy.node.presentation.pose=="basic_attack",id+" attack activity is not interrupted to switch to adjacent alternative")
		check(is_equal_approx(enemy.cooldown,enemy.interval-Config.STEP) and game.metrics.attack_times.get(id,[]).size()==1,id+" existing attack clock is not reset or doubled by pursuit policy")
		game.free()

func strict_cost_and_scan() -> void:
	for id in ENEMY_IDS:
		var game = fixture(id,["guard_monk","wild_hunter"])
		var enemy: Dictionary = game._record(id)
		set_at(game,"wild_hunter",Vector2i(7,3))
		set_at(game,"guard_monk",Vector2i(5,3))
		enemy.target = "wild_hunter"
		enemy.think = 0.1
		for index in range(10): game._brain(enemy,Config.STEP)
		check(enemy.target=="wild_hunter" and enemy.move.is_empty(),id+" nonadjacent cheaper candidate is not evaluated every frame before SCAN")
		for index in range(3): game._brain(enemy,Config.STEP)
		check(enemy.target=="guard_monk" and not enemy.move.is_empty(),id+" SCAN strictly cheaper real attack path replaces still-legal distant target")
		check(is_equal_approx(enemy.cooldown,10.0-13*Config.STEP),id+" chase replacement does not reset cooldown")
		game.free()
		game = fixture(id,["wild_hunter","foxfire_imp"])
		enemy = game._record(id)
		set_at(game,"wild_hunter",Vector2i(5,3))
		set_at(game,"foxfire_imp",Vector2i(3,5))
		enemy.target = "wild_hunter"
		enemy.route = [Vector2i(3,3),Vector2i(3,2),Vector2i(4,2),Vector2i(4,3)]
		enemy.route_goal = Vector2i(5,3)
		check(game._path(enemy,Vector2i(5,3),1).size()==2 and game._path(enemy,Vector2i(3,5),1).size()==2,"both real fresh attack costs are one, stale cache cost is three")
		game._brain(enemy,Config.STEP)
		check(enemy.target=="wild_hunter",id+" equal fresh cost keeps old target even though alternative has smaller ID and stale cache is longer")
		check(enemy.route.is_empty() and enemy.move.get("to")==Vector2i(4,3),id+" same-target stale detour cannot constrain the current optimal first step")
		game.free()

func route_comparisons() -> void:
	for id in ENEMY_IDS:
		for kind in ["shorter","equal","trim","invalid"]:
			var game = fixture(id)
			var enemy: Dictionary = game._record(id)
			var target := set_at(game,"guard_monk",Vector2i(5,2) if kind in ["equal","trim"] else Vector2i(6,3))
			if kind=="shorter": enemy.route = [Vector2i(3,3),Vector2i(3,2),Vector2i(4,2),Vector2i(5,2),Vector2i(6,2)]
			elif kind=="equal": enemy.route = [Vector2i(3,3),Vector2i(4,3),Vector2i(5,3)]
			elif kind=="trim": enemy.route = [Vector2i(2,3),Vector2i(3,3),Vector2i(4,3),Vector2i(5,3)]
			else: enemy.route = [Vector2i(3,3),Vector2i(3,4)]
			enemy.route_goal = target.cell
			# Historical caches are deliberate input, not an expected current route.
			var options: Array = Stepwise.candidates(game,enemy,target)
			check(not options.is_empty(),id+" route "+kind+" has current optimal first-step candidates")
			if kind=="invalid": check(not Melee.route_valid(game,enemy,target),id+" invalid short cached endpoint really is outside attack range")
			game._brain(enemy,Config.STEP)
			check(enemy.target==target.id,id+" route "+kind+" test cannot be hidden by target replacement")
			check(enemy.route.is_empty() and enemy.route_goal==Vector2i(-1,-1),id+" "+kind+" historical endpoint is cleared at current decision")
			check(not enemy.move.is_empty() and not options.is_empty() and enemy.move.get("to")==options[0].cell,id+" "+kind+" commits latest complete-search best first step")
			game.free()

func handoff_policy() -> void:
	for id in ENEMY_IDS:
		var game = fixture(id,["guard_monk","foxfire_imp"])
		var enemy: Dictionary = game._record(id)
		var target := set_at(game,"guard_monk",Vector2i(5,3))
		target.target = enemy.id
		check(game._move(target,Vector2i(4,3)),id+" opposite monk starts observed approach segment")
		game._brain(enemy,Config.STEP)
		var observed: Dictionary = enemy.handoff.duplicate(true)
		check(not observed.is_empty() and enemy.move.is_empty(),id+" begins finite mutual segment wait")
		enemy.route = [Vector2i(3,3),Vector2i(3,2),Vector2i(4,2),Vector2i(5,2)]
		enemy.route_goal = target.cell
		enemy.think = 0
		game._brain(enemy,Config.STEP)
		check(enemy.target==target.id and enemy.handoff==observed and enemy.move.is_empty(),id+" same-target shorter route does not cancel observed current segment wait")
		while target.move_completed<observed.segment and game.elapsed<1: game._tick(Config.STEP)
		check(target.move_completed==observed.segment and Config.distance(enemy.cell,target.cell)==1 and enemy.move.is_empty() and enemy.handoff.is_empty(),id+" actual completed approach resumes real range-one cooldown dwell, not an extra step")
		game.free()
		game = fixture(id,["guard_monk","foxfire_imp"])
		enemy = game._record(id)
		target = set_at(game,"guard_monk",Vector2i(5,3))
		target.target = enemy.id
		check(game._move(target,Vector2i(4,3)),id+" neighbor-release fixture starts observed approach")
		game._brain(enemy,Config.STEP)
		check(not enemy.handoff.is_empty(),id+" neighbor-release fixture has pending handoff")
		set_at(game,"foxfire_imp",Vector2i(3,2))
		var cd: float = enemy.cooldown
		game._brain(enemy,Config.STEP)
		check(enemy.target=="foxfire_imp" and enemy.handoff.is_empty() and enemy.move.is_empty(),id+" legal adjacent new enemy clears old handoff at safe source boundary")
		check(is_equal_approx(enemy.cooldown,cd-Config.STEP),id+" adjacency ending handoff does not reset cooldown")
		game.free()

func exclusions() -> void:
	var game = fresh()
	game.start_battle()
	isolate(game,["guard_monk","E1","E2","tangseng"])
	set_at(game,"tangseng",Vector2i(0,6))
	var monk := set_at(game,"guard_monk",Vector2i(3,3))
	set_at(game,"E1",Vector2i(5,3))
	set_at(game,"E2",Vector2i(3,4))
	monk.target = "E1"
	monk.route = [Vector2i(3,3),Vector2i(3,2),Vector2i(4,2),Vector2i(4,3)]
	monk.route_goal = Vector2i(5,3)
	game._brain(monk,Config.STEP)
	check(monk.target=="E2" and monk.move.is_empty() and monk.route.is_empty(),"guard now shares the real adjacent-enemy contact policy instead of old permanent guard lock/detour")
	game.free()
	game = fixture("E5",["guard_monk","foxfire_imp"])
	var rat: Dictionary = game._record("E5")
	set_at(game,"guard_monk",Vector2i(8,3))
	set_at(game,"foxfire_imp",Vector2i(3,4))
	game._brain(rat,Config.STEP)
	check(not Melee.applies(rat) and rat.target=="guard_monk" and rat.move.to==Vector2i(4,3),"gray rat excludes new adjacent/cheaper pursuit policy and retains original range-three old target")
	game.free()

func dynamic_road_release(id: String, fps: int, sim_speed: int) -> Dictionary:
	var game = fresh()
	game.start_battle()
	var others: Array = ENEMY_IDS.filter(func(candidate): return candidate!=id)
	var blocker_id: String = others[0]
	var holder_id: String = others[1]
	isolate(game,[id,blocker_id,holder_id,"guard_monk","tangseng"])
	set_at(game,"tangseng",Vector2i(0,6))
	var target := set_at(game,"guard_monk",Vector2i(3,0))
	var enemy := set_at(game,id,Vector2i(6,0))
	var blocker := set_at(game,blocker_id,Vector2i(5,0))
	var holder := set_at(game,holder_id,Vector2i(2,0))
	for actor in [target,enemy,blocker,holder]: actor.cooldown = 100.0
	for actor in [enemy,blocker,holder]: actor.target = target.id
	target.target = holder.id # Legal range-one cooldown dwell, not a frozen brain.
	check(game._move(blocker,Vector2i(5,1)),id+" live road blocker reserves source and destination")
	var initial_route: Array = game._path(enemy,target.cell,enemy.reach)
	check(initial_route.size()==7,"reserved road creates six-step detour to same best target")
	enemy.route = initial_route.duplicate()
	enemy.route_goal = target.cell
	game._brain(enemy,Config.STEP)
	var waited: Dictionary=enemy.step_wait.duplicate(true)
	check(enemy.target==target.id and enemy.move.is_empty() and waited=={"blocker":blocker.id,"serial":blocker.step_serial},id+" waits for actual road-source release instead of taking the slower historical detour")
	game.speed = sim_speed
	# Every surviving actor's actual _brain runs in each production _tick.
	# No target/opponent is stopped, overwritten, or ticked only on demand here.
	while enemy.move.is_empty() and game.phase==game.Phase.BATTLE and game.elapsed<3:
		game.step(1.0/fps)
		ownership(game)
	var fresh_route: Array = game._path(enemy,target.cell,enemy.reach)
	check(enemy.move_completed==0 and enemy.cell==Vector2i(6,0) and enemy.move.get("to")==Vector2i(5,0),id+" first actual enemy segment starts directly into the truly released source")
	check(blocker.move_completed>=1 and blocker.move_serial>=2,"road blocker completes observed segment and keeps running its own movement AI")
	check(target.cell==Vector2i(3,0) and target.target==holder.id and game._best_target(enemy).id==target.id,"same live target is still best; changing target cannot hide shortening failure")
	check(is_equal_approx(game.elapsed-float(enemy.move.get("time",0.0)),Config.MOVE_SECONDS_PER_CELL) and blocker.step_completed==waited.serial,id+" source release wakes waiting enemy at the real 0.5-second boundary")
	check(fresh_route.size()==3 and enemy.route.is_empty(),id+" live road release creates the current direct two-step attack route without cached-endpoint commitment")
	check(game._occupant(enemy.cell,blocker.id).id==enemy.id and game._occupant(Vector2i(5,0),blocker.id).id==enemy.id,id+" direct committed segment preserves both endpoint locks")
	var issued_to: Vector2i=enemy.move.get("to",enemy.cell)
	var report := {"id":id,"fps":fps,"speed":sim_speed,"same_target":enemy.target,"first_boundary":game.elapsed-float(enemy.move.get("time",0.0)),"current":[enemy.cell.x,enemy.cell.y],"next":[issued_to.x,issued_to.y],"old_static_cost":initial_route.size()-1,"fresh_cost":fresh_route.size()-1,"waited":waited,"route":enemy.route.map(func(cell): return [cell.x,cell.y]),"blocker_completed":blocker.move_completed,"blocker_serial":blocker.move_serial}
	game.free()
	return report

func run() -> void:
	adjacent_priority()
	active_segments()
	strict_cost_and_scan()
	route_comparisons()
	handoff_policy()
	exclusions()
	for id in ENEMY_IDS:
		var first := dynamic_road_release(id,30,1)
		var second := dynamic_road_release(id,120,2)
		check(first.same_target==second.same_target and first.current==second.current and first.next==second.next and first.route==second.route and is_equal_approx(first.first_boundary,second.first_boundary),id+" independent live-road-release result repeats across 30x1/120x2")
		dynamic_reports.append(first)
		dynamic_reports.append(second)
	var output := FileAccess.open("/tmp/board-enemy-pursuit-boundaries.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"rule":Melee.RULE,"coordinate_base":0,"isolated_boundaries":true,"road_release_opponents_AI_live":true,"dynamic_cooldown_fixture":100.0,"dynamic":dynamic_reports,"failures":failures},"\t"))
	print("BOARD_TRIAL_ENEMY_PURSUIT isolated_boundaries=true road_release_AI_live=true failures=",failures)
	quit(1 if failures else 0)
