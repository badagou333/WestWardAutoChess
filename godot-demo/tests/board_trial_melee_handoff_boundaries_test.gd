extends "res://tests/board_trial_ai_test.gd"
## Isolated D-006 boundary fixtures, not a substitute for the full natural-AI trace.
## Each decision enters the production _brain; segment completion enters _tick.
const Melee = preload("res://scripts/combat/board_trial_melee.gd")
const MELEE_IDS := ["guard_monk","E1","E2","E3","E4"]

func pair(source_id: String, target_id := ""):
	var game = fresh()
	game.start_battle()
	if target_id.is_empty(): target_id = "E1" if source_id=="guard_monk" else "guard_monk"
	isolate(game,[source_id,target_id,"tangseng"])
	game._set_cell(game._record("tangseng"),Vector2i(0,6))
	var source: Dictionary = game._record(source_id)
	var target: Dictionary = game._record(target_id)
	game._set_cell(source,Vector2i(3,3))
	game._set_cell(target,Vector2i(5,3))
	source.target = target.id
	target.target = source.id
	source.cooldown = 100.0
	target.cooldown = 100.0
	return game

func route_fixtures() -> void:
	for id in MELEE_IDS:
		var game = pair(id)
		var source: Dictionary = game._record(id)
		var target: Dictionary = game._record(source.target)
		game._set_cell(target,Vector2i(6,3))
		source.route = [Vector2i(3,3),Vector2i(4,3),Vector2i(5,3)]
		source.route_goal = target.cell
		var old_route: Array = source.route.duplicate()
		game._set_cell(target,Vector2i(5,2))
		check(Melee.route_valid(game,source,target),id+" changed target cell leaves old real attack endpoint valid")
		game._brain(source,Config.STEP)
		check(source.route==old_route and source.route_goal==Vector2i(6,3),id+" production brain retains valid route despite stale planning snapshot")
		check(not source.move.is_empty() and source.move.to==Vector2i(4,3),id+" production brain follows cached next step")
		ownership(game)
		game.free()
		game = pair(id)
		source = game._record(id)
		target = game._record(source.target)
		source.route = [Vector2i(3,3),Vector2i(4,3),Vector2i(5,3)]
		source.route_goal = Vector2i(6,3)
		game._set_cell(target,Vector2i(3,1))
		check(not Melee.route_valid(game,source,target),id+" old endpoint outside real range invalidates route")
		game._brain(source,Config.STEP)
		check(source.route_goal==target.cell and source.route!=old_route,id+" production brain replans only after actual endpoint invalidity")
		check(not source.move.is_empty() and source.move.to==Vector2i(3,2),id+" new route approaches real current target without pursuit prediction")
		ownership(game)
		game.free()

func cooldown_fixtures() -> void:
	for id in MELEE_IDS:
		var game = pair(id)
		var source: Dictionary = game._record(id)
		var target: Dictionary = game._record(source.target)
		game._set_cell(target,Vector2i(4,3))
		source.blocked = true
		source.blocked_elapsed = 1.9
		source.route = [source.cell,Vector2i(3,2)]
		source.handoff = {"target":target.id,"segment":999}
		for index in range(300): game._brain(source,Config.STEP)
		check(source.target==target.id and source.move.is_empty() and source.node.presentation.pose=="idle",id+" real range-one attack position remains occupied during cooldown wait")
		check(source.handoff.is_empty(),id+" range-one dwell clears obsolete handoff")
		check(source.blocked_elapsed==1.9 and source.blocked,"obsolete guard-block fields do not control or accrue shared melee cooldown policy")
		check(game.metrics.attack_times.get(id,[]).is_empty(),id+" no early attack bypasses original cooldown")
		game.free()

func waiting_game():
	var game = pair("guard_monk")
	var source: Dictionary = game._record("guard_monk")
	var target: Dictionary = game._record("E1")
	check(game._move(target,Vector2i(5,2)),"isolated target starts a real move activity")
	source.blocked = true
	source.blocked_elapsed = 1.5
	game._brain(source,Config.STEP)
	check(source.handoff=={"target":"E1","segment":1} and source.move.is_empty(),"distance-two mutual melee binds only observed current segment")
	check(game.metrics.attack_times.get(source.id,[]).is_empty(),"distance-two waiting never expands attack range")
	return game

func five_melee_observation_fixtures() -> void:
	for id in MELEE_IDS:
		var game = pair(id)
		var source: Dictionary = game._record(id)
		var target: Dictionary = game._record(source.target)
		check(game._move(target,target.cell+Vector2i(0,-1)),id+" observes a real eligible opposite melee activity")
		game._brain(source,Config.STEP)
		check(source.handoff=={"target":target.id,"segment":target.move_serial} and source.move.is_empty(),id+" production brain binds current mutually-locked distance-two segment")
		check(game.metrics.attack_times.get(id,[]).is_empty(),id+" distance-two observation does not attack")
		game.free()

func wait_and_pause_fixtures() -> void:
	var game = waiting_game()
	var source: Dictionary = game._record("guard_monk")
	var target: Dictionary = game._record("E1")
	for index in range(300): game._brain(source,Config.STEP)
	check(source.target=="E1" and source.move.is_empty() and source.blocked_elapsed==1.5,"isolated observed-segment wait keeps the real target/activity and ignores obsolete guard-block fields")
	var elapsed: float = game.elapsed
	var movement: Dictionary = target.move.duplicate(true)
	var handoff: Dictionary = source.handoff.duplicate(true)
	game.paused = true
	game.step(2.5)
	check(game.elapsed==elapsed and target.move==movement and source.handoff==handoff and source.blocked_elapsed==1.5,"production paused step freezes observed activity and handoff/blocked clocks")
	game.free()

func completion_serial_fixture() -> void:
	# Guard brain runs before E1. Guard completes its observed activity and starts
	# another in one _tick; the later E1 brain must consume the old completion ID.
	var game = pair("E1")
	var source: Dictionary = game._record("E1")
	var target: Dictionary = game._record("guard_monk")
	game._set_cell(source,Vector2i(5,3))
	game._set_cell(target,Vector2i(3,3))
	check(game._move(target,Vector2i(3,2)),"earlier guard brain owns first observed segment")
	game._brain(source,Config.STEP)
	check(source.handoff=={"target":"guard_monk","segment":1},"later enemy brain observes guard segment one")
	target.move.time = target.move.duration-Config.STEP
	game._tick(Config.STEP)
	check(target.cell==Vector2i(3,2) and target.move_completed==1 and target.move_serial==2 and not target.move.is_empty(),"actual tick persists segment-one completion despite starting segment two")
	check(source.handoff.is_empty() and not source.move.is_empty() and source.target==target.id,"later production brain consumes old completion and pursues real now-distant target, not new activity")
	check(Config.distance(source.cell,target.cell)==3 and game.metrics.attack_times.get(source.id,[]).is_empty(),"target truly moved away; no predicted endpoint or expanded-range attack")
	ownership(game)
	game.free()

func cancelled_activity_fixture() -> void:
	# Explicit state-cancellation fixture: the real _move exists, then a future
	# cleanup cancels it without a completion counter or changing the live lock.
	for id in MELEE_IDS:
		var game = pair(id)
		var source: Dictionary = game._record(id)
		var target: Dictionary = game._record(source.target)
		check(game._move(target,target.cell+Vector2i(0,-1)),id+" real observed activity starts before explicit state cancellation")
		game._brain(source,Config.STEP)
		check(not source.handoff.is_empty() and source.move.is_empty(),id+" has a real pending handoff before cancellation")
		target.move = {}
		check(target.move_serial==1 and target.move_completed==0 and game._active(target) and target.target==source.id,id+" fixture cancels activity without fabricating completion/death/unlock")
		game._brain(source,Config.STEP)
		check(source.handoff.is_empty() and source.target==target.id and not source.move.is_empty() and source.move.to==Vector2i(4,3),id+" production brain clears canceled observed activity and chases actual current cell without rebinding")
		check(Config.distance(source.cell,target.cell)==2 and game.metrics.attack_times.get(id,[]).is_empty(),id+" canceled activity is not an invented range-one attack")
		ownership(game)
		game.free()

func cancellation_fixtures() -> void:
	for reason in ["mutual","death","departed"]:
		var game = waiting_game()
		var source: Dictionary = game._record("guard_monk")
		var target: Dictionary = game._record("E1")
		if reason=="mutual": target.target = "tangseng"
		elif reason=="death": target.node.take_damage(target.hp_max)
		else:
			target.move = {}
			game._set_cell(target,Vector2i(7,3))
		game._brain(source,Config.STEP)
		check(source.handoff.is_empty(),reason+" production target invalidation/lock release clears handoff immediately")
		if reason=="mutual":
			check(source.target==target.id and not source.move.is_empty(),"loss of mutuality resumes original same-target chase")
		elif reason=="death":
			check(source.target.is_empty() and source.move.is_empty() and source.cell==source.anchor,"dead last enemy clears waiting and stays at current cell; no automatic-return policy")
		else:
			check(source.target==target.id and not source.move.is_empty(),"target leaving historical AGGRO is still reachable, so shared melee resumes actual pursuit")
		game.free()
	var game = waiting_game()
	var source: Dictionary = game._record("guard_monk")
	source.node.take_damage(source.hp_max)
	game._tick(Config.STEP)
	check(source.dead and source.handoff.is_empty() and source.target.is_empty(),"actual death tick clears actor handoff and target")
	game.free()

func exclusion_fixtures() -> void:
	for reason in ["distance3","nonmutual","rat"]:
		var game = pair("guard_monk","E5" if reason=="rat" else "E1")
		var source: Dictionary = game._record("guard_monk")
		var target: Dictionary = game._record(source.target)
		if reason=="distance3": game._set_cell(target,Vector2i(6,3))
		if reason=="nonmutual": target.target = "tangseng"
		check(game._move(target,target.cell+Vector2i(0,-1)),reason+" target owns an actual unfinished segment")
		game._brain(source,Config.STEP)
		check(source.handoff.is_empty() and not source.move.is_empty(),reason+" never triggers melee mutual distance-two waiting")
		if reason=="rat": check(not Melee.applies(target),"gray rat remains outside shared melee activity logic")
		ownership(game)
		game.free()

func enemy_original_rules_fixtures() -> void:
	for id in ["E1","E2","E3","E4"]:
		var game = pair(id,"tangseng")
		var enemy: Dictionary = game._record(id)
		var core: Dictionary = game._record("tangseng")
		game._set_cell(enemy,Vector2i(0,3))
		enemy.cell = Vector2i(2,3)
		enemy.node.position = Config.center(enemy.cell)
		game._set_cell(core,Vector2i(5,3))
		enemy.blocked_elapsed = 4.5
		enemy.blocked = true
		game._brain(enemy,Config.STEP)
		check(enemy.target==core.id and not enemy.move.is_empty() and enemy.move.to==Vector2i(3,3),id+" retains reachable old target and moves beyond anchor LEASH2")
		check(enemy.blocked_elapsed==4.5,id+" does not inherit monk long-block timer or two-second release")
		game.free()
		game = fresh()
		game.start_battle()
		isolate(game,[id,"guard_monk","wild_hunter","herbal_spirit_child","tangseng"])
		enemy = game._record(id)
		var old: Dictionary = game._record("guard_monk")
		game._set_cell(game._record("tangseng"),Vector2i(0,6))
		game._set_cell(enemy,Vector2i(0,0))
		game._set_cell(old,Vector2i(3,0))
		game._set_cell(game._record("wild_hunter"),Vector2i(1,0))
		game._set_cell(game._record("herbal_spirit_child"),Vector2i(0,1))
		enemy.target = old.id
		enemy.cooldown = 100
		enemy.handoff = {"target":old.id,"segment":999}
		check(game._path(enemy,old.cell,enemy.reach).is_empty(),id+" isolated old target really has no reachable attack position")
		game._brain(enemy,Config.STEP)
		check(enemy.target=="herbal_spirit_child" and enemy.handoff.is_empty() and enemy.move.is_empty(),id+" unreachable old target immediately retargets nearest reachable ally with original ID tie-break")
		game.free()

func retry_fixture() -> void:
	var game = fresh()
	game.start_battle()
	for id in MELEE_IDS:
		var actor: Dictionary = game._record(id)
		actor.handoff = {"target":"E1" if actor.friendly else "guard_monk","segment":4}
		actor.move_serial = 5
		actor.move_completed = 4
		actor.blocked_elapsed = 1.7
		actor.route = [actor.cell]
	game.retry()
	for id in MELEE_IDS:
		var actor: Dictionary = game._record(id)
		check(actor.handoff.is_empty() and actor.move_serial==0 and actor.move_completed==0 and actor.route.is_empty() and actor.blocked_elapsed==0 and actor.move.is_empty() and actor.target.is_empty(),id+" actual retry creates clean handoff/segment/cached-route/blocked state")
	game.free()

func run() -> void:
	route_fixtures()
	cooldown_fixtures()
	five_melee_observation_fixtures()
	wait_and_pause_fixtures()
	completion_serial_fixture()
	cancelled_activity_fixture()
	cancellation_fixtures()
	exclusion_fixtures()
	enemy_original_rules_fixtures()
	retry_fixture()
	print("BOARD_TRIAL_MELEE_HANDOFF_BOUNDARIES isolated_fixtures=true failures=",failures)
	quit(1 if failures else 0)
