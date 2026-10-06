extends "res://tests/board_trial_test.gd"
func isolate(game, ids: Array) -> void:
	for actor in game.actors:
		if actor.id not in ids:
			actor.node.take_damage(actor.hp_max)
			actor.dead = true
func run() -> void:
	var game = fresh()
	var monk: Dictionary = game._record("guard_monk")
	var enemy: Dictionary = game._record("E1")
	var core: Dictionary = game._record("tangseng")
	isolate(game,["guard_monk","E1","E2","tangseng"])
	game._set_cell(monk,Vector2i(5,3))
	game._set_cell(core,Vector2i(0,0))
	game._set_cell(enemy,Vector2i(8,3))
	var second: Dictionary = game._record("E2")
	game._set_cell(second,Vector2i(5,6))
	check(game._best_target(monk).id=="E1","equal-cost target uses stable ID")
	var target: String = game._best_target(monk).id
	game.actors.reverse()
	check(game._best_target(monk).id==target,"target selection independent of storage order")
	game.actors.reverse()
	var path: Array = game._path(monk,enemy.cell,1)
	check(path.back()==Vector2i(7,3) and path.all(func(cell): return Config.distance(cell,monk.anchor)<=2),"legal melee path crosses middle without exceeding anchor radius")
	check(game._move(monk,path[1]),"first adjacent move claimed")
	check(not game._occupant(monk.cell,"E2").is_empty() and not game._occupant(monk.move.to,"E2").is_empty(),"moving monk reserves source and destination")
	check(not game._move(second,monk.move.to),"occupied destination cannot be double claimed")
	# Return never resets the anchor or selects another enemy before arrival.
	monk.cell = monk.move.to
	monk.node.position = Config.center(monk.cell)
	monk.move = {}
	monk.target = "E1"
	monk.node.presentation.reset_visual()
	monk.mode = "接敌"
	enemy.node.take_damage(enemy.hp_max)
	monk.think = 0
	game._brain(monk,Config.STEP)
	check(monk.anchor==Vector2i(5,3) and monk.target.is_empty() and monk.mode=="归位" and monk.move.to==monk.anchor,"dead target returns to original anchor before retargeting")
	game.free()
	game = fresh()
	monk = game._record("guard_monk")
	enemy = game._record("E1")
	var hunter: Dictionary = game._record("wild_hunter")
	isolate(game,["guard_monk","E1","wild_hunter","tangseng"])
	game._set_cell(monk,Vector2i(0,0))
	game._set_cell(hunter,Vector2i(1,0))
	game._set_cell(enemy,Vector2i(2,0))
	check(not game._move(monk,Vector2i(-1,0)),"edge actor cannot move outside board")
	# Add a second friendly blocker; sealed corner cannot pass bodies.
	var healer: Dictionary = game._record("herbal_spirit_child")
	healer.dead = false
	healer.node.battle_dead = false
	healer.node.active_in_battle = true
	healer.node.health = healer.hp_max
	healer.node.presentation.reset_visual()
	game._set_cell(healer,Vector2i(0,1))
	check(game._path(monk,enemy.cell,1).is_empty(),"sealed actor cannot cross allied bodies")
	hunter.node.take_damage(hunter.hp_max)
	check(not game._path(monk,enemy.cell,1).is_empty(),"death releases blocked path immediately")
	game.free()
	game = fresh()
	game.start_battle()
	core = game._record("tangseng")
	monk = game._record("guard_monk")
	enemy = game._record("E1")
	isolate(game,["guard_monk","E1","tangseng"])
	core.node.health = 1
	enemy.node.health = 1
	# Two independently surviving sources, both contacts due within ONE tick.
	game.combat.request(enemy.node,core.node)
	game.combat.request(monk.node,enemy.node)
	for actor in [enemy,monk]: actor.node.presentation.pose_time = actor.node.presentation.impact_delay()-Config.STEP
	game._tick(Config.STEP)
	check(core.node.dead and enemy.node.dead and not game.victory and game.phase==game.Phase.RESULT,"actual same-tick final enemy/core damage settles failure after entire batch")
	check(game.metrics.damage.has("guard_monk") and game.result_count==1,"whole event batch processed before single result")
	game.free()
	game = fresh()
	var heal: Dictionary = game._record("herbal_spirit_child")
	core = game._record("tangseng")
	monk = game._record("guard_monk")
	core.node.health = 150
	monk.node.health = 155
	check(game._healing_target(heal).id=="tangseng","same health ratio prefers nearer target")
	game._set_cell(monk,Vector2i(3,2))
	check(game._healing_target(heal).id=="guard_monk","same health ratio and distance break by stable ID")
	core.node.health = 1
	check(game._healing_target(heal).id=="tangseng","lowest ratio can select injured core")
	core.node.take_damage(1)
	check(game._healing_target(heal).id=="guard_monk","dead core cannot receive healing")
	var rat: Dictionary = game._record("E5")
	game._set_cell(rat,Vector2i(6,2))
	rat.think = 0
	game._brain(rat,Config.STEP)
	check(rat.move.is_empty() and rat.target=="guard_monk" and rat.node.presentation.pose=="basic_attack","rat attacks within range three without closing to melee")
	game.free()
	game = fresh()
	game.start_battle()
	isolate(game,["guard_monk","E1","tangseng"])
	monk = game._record("guard_monk")
	enemy = game._record("E1")
	game._set_cell(enemy,monk.cell+Vector2i(1,0))
	enemy.node.health = 100000
	enemy.node.max_health = 100000
	enemy.cooldown = 100000
	while game.elapsed<4: game.step(Config.STEP)
	var times: Array = game.metrics.attack_times.get("guard_monk",[])
	check(times.size()>=4,"stationary monk repeats production attacks")
	for index in range(1,times.size()): check(is_equal_approx(times[index]-times[index-1],monk.interval),"path scan interval does not quantize original attack cadence")
	game.free()
	print("BOARD_TRIAL_AI failures=",failures)
	quit(1 if failures else 0)
