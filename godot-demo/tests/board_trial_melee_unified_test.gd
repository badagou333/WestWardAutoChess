extends "res://tests/board_trial_ai_test.gd"
## D-20261008-002 mirrored equal-state boundary fixtures, not natural deployment runs.
## Decisions use production _brain; real completion/renewal uses production _tick.
const Melee = preload("res://scripts/combat/board_trial_melee.gd")
const ROLES := ["guard_monk","E1","E3"]
const ORIGINAL := {"guard_monk":{"hp":310.0,"damage":14.0,"interval":1.15,"walk":0.50},"E1":{"hp":155.0,"damage":14.0,"interval":0.90,"walk":0.52},"E3":{"hp":96.0,"damage":10.0,"interval":1.10,"walk":0.70}}
var evidence := []
var guard_road_reports := []

func point(cell: Vector2i, mirrored: bool) -> Vector2i:
	return Vector2i(Config.COLS-1-cell.x,cell.y) if mirrored else cell

func context(role: String, mirrored: bool) -> Dictionary:
	var game = fresh()
	game.start_battle()
	var ids: Array = ["E3","E1","E2"] if role=="guard_monk" else ["wild_hunter","guard_monk","foxfire_imp"]
	isolate(game,[role,ids[0],ids[1],ids[2],"tangseng"])
	var source: Dictionary = game._record(role)
	game._set_cell(game._record("tangseng"),point(Vector2i(0,6),mirrored))
	game._set_cell(source,point(Vector2i(3,3),mirrored))
	source.anchor = point(Vector2i(0,3),mirrored) # Explicit state already beyond old anchor2.
	var positions := [Vector2i(7,3),Vector2i(5,3),Vector2i(3,6)]
	for index in range(ids.size()): game._set_cell(game._record(ids[index]),point(positions[index],mirrored))
	for actor in game.actors:
		if game._active(actor): actor.cooldown = 10.0
	source.target = ids[0]
	return {"game":game,"source":source,"old":game._record(ids[0]),"near":game._record(ids[1]),"extra":game._record(ids[2]),"role":role,"mirror":mirrored}

func at(ctx: Dictionary, actor: Dictionary, cell: Vector2i) -> void:
	ctx.game._set_cell(actor,point(cell,ctx.mirror))

func route(ctx: Dictionary, cells: Array) -> Array:
	return cells.map(func(cell): return point(cell,ctx.mirror))

func close_case(ctx: Dictionary, label: String) -> void:
	var source: Dictionary = ctx.source
	var original: Dictionary = ORIGINAL[ctx.role]
	check(source.damage==original.damage and source.node.damage==original.damage and source.interval==original.interval and source.walk==original.walk and source.reach==1,ctx.role+" original melee stats remain unchanged in "+label)
	check(source.hp_max==original.hp and source.node.max_health==original.hp,ctx.role+" original maximum HP remains unchanged in "+label)
	evidence.append({"role":ctx.role,"mirrored":ctx.mirror,"case":label,"target":source.target,"cell":[source.cell.x,source.cell.y],"next":str(source.move.get("to","")),"cooldown":source.cooldown,"route_cost":source.route.size()-1,"handoff":source.handoff.duplicate(true)})
	ctx.game.free()

func range_and_neighbors(role: String, mirrored: bool) -> void:
	var ctx := context(role,mirrored)
	at(ctx,ctx.old,Vector2i(4,3))
	at(ctx,ctx.near,Vector2i(3,2))
	at(ctx,ctx.extra,Vector2i(3,4))
	ctx.source.think = Config.SCAN
	ctx.game._brain(ctx.source,Config.STEP)
	check(ctx.source.target==ctx.old.id and ctx.source.move.is_empty(),role+" hittable old target precedes all adjacent alternatives including CD wait")
	check(is_equal_approx(ctx.source.cooldown,10.0-Config.STEP) and ctx.game.metrics.attack_times.get(role,[]).is_empty(),role+" range-one hold does not bypass/reset original cooldown")
	close_case(ctx,"range_current_priority")
	ctx = context(role,mirrored)
	at(ctx,ctx.near,Vector2i(3,2))
	at(ctx,ctx.extra,Vector2i(3,4))
	ctx.source.think = Config.SCAN
	ctx.game.actors.reverse() # Single-brain stable-ID fixture, not natural order.
	ctx.game._brain(ctx.source,Config.STEP)
	var expected: String = ctx.near.id if ctx.near.id<ctx.extra.id else ctx.extra.id
	check(ctx.source.target==expected and ctx.source.move.is_empty(),role+" multiple legal adjacent opponents use stable ID before pursuit SCAN")
	check(is_equal_approx(ctx.source.cooldown,10.0-Config.STEP),role+" adjacent switch retains cooldown")
	close_case(ctx,"adjacent_stable_ID")

func fresh_cost_and_routes(role: String, mirrored: bool) -> void:
	var ctx := context(role,mirrored)
	ctx.game._brain(ctx.source,Config.STEP)
	check(ctx.source.target==ctx.near.id and not ctx.source.move.is_empty(),role+" strictly shorter fresh reachable cost replaces valid distant old target")
	close_case(ctx,"strictly_shorter_target")
	ctx = context(role,mirrored)
	at(ctx,ctx.old,Vector2i(5,3))
	at(ctx,ctx.near,Vector2i(3,5))
	ctx.source.route = route(ctx,[Vector2i(3,3),Vector2i(3,2),Vector2i(4,2),Vector2i(4,3)])
	ctx.source.route_goal = ctx.old.cell
	check(ctx.near.id<ctx.old.id and ctx.game._path(ctx.source,ctx.old.cell,1).size()==2 and ctx.game._path(ctx.source,ctx.near.cell,1).size()==2,role+" equal fresh cost candidate has smaller ID and stale current cache is longer")
	ctx.game._brain(ctx.source,Config.STEP)
	check(ctx.source.target==ctx.old.id and ctx.source.route.size()==2,role+" equal fresh cost keeps old lock while independently shortening its detour")
	close_case(ctx,"equal_fresh_cost_not_cache_cost")
	for kind in ["shorter","equal","trim","invalid"]:
		ctx = context(role,mirrored)
		at(ctx,ctx.near,Vector2i(11,0))
		at(ctx,ctx.extra,Vector2i(10,6))
		at(ctx,ctx.old,Vector2i(5,2) if kind in ["equal","trim"] else Vector2i(6,3))
		var cells := []
		if kind=="shorter": cells = [Vector2i(3,3),Vector2i(3,2),Vector2i(4,2),Vector2i(5,2),Vector2i(6,2)]
		elif kind=="equal": cells = [Vector2i(3,3),Vector2i(4,3),Vector2i(5,3)]
		elif kind=="trim": cells = [Vector2i(2,3),Vector2i(3,3),Vector2i(4,3),Vector2i(5,3)]
		else: cells = [Vector2i(3,3),Vector2i(3,4)]
		ctx.source.route = route(ctx,cells)
		ctx.source.route_goal = ctx.old.cell
		var kept: Array = ctx.source.route.duplicate()
		if kind=="trim": kept.pop_front()
		var fresh_route: Array = ctx.game._path(ctx.source,ctx.old.cell,1)
		ctx.game._brain(ctx.source,Config.STEP)
		check(ctx.source.target==ctx.old.id,role+" route-only "+kind+" cannot be hidden by target replacement")
		check(ctx.source.route==(kept if kind in ["equal","trim"] else fresh_route),role+" "+kind+" follows strict shorter/equal/trim/invalid cached-route rule")
		check(not ctx.source.move.is_empty(),role+" cached route remains movable beyond old anchor2")
		close_case(ctx,"route_"+kind)

func no_path_and_death(role: String, mirrored: bool) -> void:
	var ctx := context(role,mirrored)
	ctx.old.node.take_damage(ctx.old.hp_max)
	ctx.game._brain(ctx.source,Config.STEP)
	check(ctx.source.target==ctx.near.id and not ctx.source.move.is_empty(),role+" dead old target reselects current closest reachable opponent without returning")
	check(not ctx.source.mode.begins_with("归位"),role+" old deployment anchor is not an active return objective")
	close_case(ctx,"death_current_cell_reselection")
	ctx = context(role,mirrored)
	at(ctx,ctx.source,Vector2i(0,0))
	ctx.source.anchor = point(Vector2i(3,3),mirrored)
	var blocker_ids: Array = ["tangseng","herbal_spirit_child"] if role=="guard_monk" else ["E2","E4"]
	for index in range(2):
		var blocker: Dictionary = ctx.game._record(blocker_ids[index])
		blocker.dead = false
		if blocker.friendly:
			blocker.node.battle_dead = false
			if blocker.key!="tangseng": blocker.node.active_in_battle = true
		else: blocker.node.dead = false
		blocker.node.health = blocker.hp_max
		blocker.node.presentation.reset_visual()
		at(ctx,blocker,Vector2i(1,0) if index==0 else Vector2i(0,1))
	check(not ctx.game._target_legal(ctx.source,ctx.old),role+" alive far opponent has genuinely empty route in sealed corner")
	ctx.game._brain(ctx.source,Config.STEP)
	check(ctx.source.target.is_empty() and ctx.source.move.is_empty() and ctx.source.cell!=ctx.source.anchor and not ctx.source.mode.begins_with("归位"),role+" no path waits at current cell, no anchor/AGGRO/two-second special rule")
	at(ctx,ctx.game._record(blocker_ids[0]),Vector2i(1,4))
	ctx.game._brain(ctx.source,Config.STEP)
	check(ctx.source.target.is_empty() and ctx.source.move.is_empty(),role+" unblocked corner still retries at original SCAN rather than every frame")
	for index in range(30): ctx.game._brain(ctx.source,Config.STEP)
	check(not ctx.source.target.is_empty() and not ctx.source.move.is_empty(),role+" ordinary SCAN resumes freshly reachable full-board pursuit")
	close_case(ctx,"no_path_current_cell_SCAN_retry")

func safe_activity_and_reservation(role: String, mirrored: bool) -> void:
	var ctx := context(role,mirrored)
	var emitted: Vector2i = point(Vector2i(4,3),mirrored)
	check(ctx.game._move(ctx.source,emitted),role+" emits real move beyond previous anchor2")
	var held: Dictionary = ctx.source.move.duplicate(true)
	check(ctx.game._occupant(ctx.source.cell,ctx.near.id).id==role and ctx.game._occupant(emitted,ctx.near.id).id==role,role+" source and destination stay reserved together")
	check(not ctx.game._move(ctx.near,emitted),role+" competing body cannot claim source destination")
	ctx.old.node.take_damage(ctx.old.hp_max)
	ctx.game._brain(ctx.source,Config.STEP)
	check(ctx.source.target==ctx.old.id and ctx.source.move==held,role+" in-flight activity and its lock cannot change on target death")
	var from: Vector2i = ctx.source.cell
	while ctx.source.cell==from and ctx.game.elapsed<1.2: ctx.game._tick(Config.STEP)
	check(ctx.source.cell==emitted and ctx.source.target!=ctx.old.id and ctx.game._active(ctx.game._record(ctx.source.target)),role+" real original segment completes before legal current-cell retargeting")
	close_case(ctx,"move_finish_before_target_release")
	ctx = context(role,mirrored)
	at(ctx,ctx.old,Vector2i(4,3))
	ctx.source.cooldown = 0
	ctx.game._brain(ctx.source,Config.STEP)
	check(ctx.source.node.presentation.pose=="basic_attack",role+" starts actual original melee attack activity")
	ctx.old.node.take_damage(ctx.old.hp_max)
	ctx.game._brain(ctx.source,Config.STEP)
	check(ctx.source.target==ctx.old.id and ctx.source.move.is_empty() and is_equal_approx(ctx.source.cooldown,ctx.source.interval-Config.STEP),role+" attack activity finishes safely without changing lock or resetting original cooldown")
	while ctx.source.node.presentation.pose=="basic_attack" and ctx.game.elapsed<2: ctx.game._tick(Config.STEP)
	ctx.source.think = 0
	ctx.game._brain(ctx.source,Config.STEP)
	check(ctx.source.target!=ctx.old.id and ctx.game._active(ctx.game._record(ctx.source.target)),role+" after attack completion normal safe-boundary target decision resumes")
	close_case(ctx,"attack_finish_before_target_release")

func observed_segment(role: String, mirrored: bool) -> void:
	var ctx := context(role,mirrored)
	isolate(ctx.game,[role,ctx.near.id,"tangseng"])
	ctx.source.target = ctx.near.id
	ctx.near.target = role
	check(ctx.game._move(ctx.near,point(Vector2i(5,2),mirrored)),role+" opposite eligible melee starts actual observed activity")
	ctx.game._brain(ctx.source,Config.STEP)
	var observed: Dictionary = ctx.source.handoff.duplicate(true)
	check(observed=={"target":ctx.near.id,"segment":1} and ctx.source.move.is_empty(),role+" mirrored mutually locked distance2 waits only observed segment")
	check(ctx.game.metrics.attack_times.get(role,[]).is_empty(),role+" distance2 wait never invents range2 attack")
	ctx.game.paused = true
	var elapsed: float = ctx.game.elapsed
	var move: Dictionary = ctx.near.move.duplicate(true)
	var cooldown: float = ctx.source.cooldown
	ctx.game.step(2)
	check(ctx.game.elapsed==elapsed and ctx.near.move==move and ctx.source.handoff==observed and ctx.source.cooldown==cooldown,role+" pause freezes real observed activity and source clocks")
	ctx.game.paused = false
	ctx.near.move.time = ctx.near.move.duration-Config.STEP # Explicit near-completion state fixture.
	ctx.game._tick(Config.STEP)
	check(ctx.near.move_completed==observed.segment and ctx.near.move_serial==2 and not ctx.near.move.is_empty(),role+" real tick persists old completion even when opposite brain emits next segment")
	check(ctx.source.handoff.is_empty() and ctx.source.target==ctx.near.id and not ctx.source.move.is_empty(),role+" observed completion consumed once, no rebinding to new activity or waiting entire path")
	ownership(ctx.game)
	close_case(ctx,"observed_complete_same_tick_renewal")

func guard_road_release(fps: int, sim_speed: int) -> Dictionary:
	# Live same-target fixture: a hunter really frees its reserved source before
	# guard completes one original-speed segment, then dwells at real range3.
	# All five survivors keep their production brains; CD100 is isolation only.
	var game = fresh()
	game.start_battle()
	isolate(game,["guard_monk","E1","wild_hunter","foxfire_imp","tangseng"])
	var source: Dictionary=game._record("guard_monk")
	var target: Dictionary=game._record("E1")
	var blocker: Dictionary=game._record("wild_hunter")
	var holder: Dictionary=game._record("foxfire_imp")
	for placement in [[source,Vector2i(6,0)],[target,Vector2i(3,0)],[blocker,Vector2i(5,0)],[holder,Vector2i(2,0)],[game._record("tangseng"),Vector2i(0,6)]]:
		game._set_cell(placement[0],placement[1])
	source.anchor=Vector2i(1,0) # Explicit already-far state, not natural deployment.
	for actor in [source,target,blocker,holder]: actor.cooldown=100.0
	for actor in [source,blocker,holder]: actor.target=target.id
	target.target=holder.id
	check(game._move(blocker,Vector2i(5,1)),"live hunter actually starts its source-freeing segment")
	var initial: Array=game._path(source,target.cell,1)
	check(initial.size()==7,"hunter double reservation creates original six-step detour")
	source.route=initial.duplicate()
	source.route_goal=target.cell
	game._brain(source,Config.STEP)
	check(source.move.to==Vector2i(6,1),"guard starts the actual valid detour before release")
	game.speed=sim_speed
	while source.move_completed<1 and game.phase==game.Phase.BATTLE and game.elapsed<2:
		game.step(1.0/fps)
		ownership(game)
	var remaining: Array=initial.slice(1)
	var copy: Dictionary=source.duplicate(false)
	copy.route=remaining
	var fresh_path: Array=game._path(source,target.cell,1)
	check(blocker.cell==Vector2i(5,1) and blocker.move.is_empty() and blocker.target==target.id,"hunter completes its real segment and original ranged AI legally dwells, not frozen")
	check(source.target==target.id and target.target==holder.id and target.cell==Vector2i(3,0),"same live enemy remains best and holds its actual range-one cooldown position")
	check(Melee.route_valid(game,copy,target) and remaining.size()==6,"guard old remaining five-step detour stays physically valid after release")
	check(source.cell==Vector2i(6,1) and fresh_path.size()==4 and source.route==fresh_path and source.move.to==Vector2i(6,0),"guard independently shortens same-target valid cache from five to three steps after actual road release")
	var result := {"fps":fps,"speed":sim_speed,"boundary":game.elapsed-float(source.move.time),"target":source.target,
		"current":[source.cell.x,source.cell.y],"next":[source.move.to.x,source.move.to.y],"old_remaining_cost":remaining.size()-1,"fresh_cost":fresh_path.size()-1,
		"route":source.route.map(func(cell): return [cell.x,cell.y]),"blocker_current":[blocker.cell.x,blocker.cell.y]}
	game.free()
	return result

func run() -> void:
	for role in ROLES:
		for mirrored in [false,true]:
			range_and_neighbors(role,mirrored)
			fresh_cost_and_routes(role,mirrored)
			no_path_and_death(role,mirrored)
			safe_activity_and_reservation(role,mirrored)
			observed_segment(role,mirrored)
	check(evidence.size()==78,"all 78 mirrored boundary cases executed completely, not an exit-zero early script-error result")
	var first:=guard_road_release(30,1)
	var repeated:=guard_road_release(120,2)
	check(first.target==repeated.target and first.current==repeated.current and first.next==repeated.next and first.route==repeated.route and is_equal_approx(first.boundary,repeated.boundary),"guard real same-target road release repeats under both public schedules")
	guard_road_reports=[first,repeated]
	var output := FileAccess.open("/tmp/board-melee-unified-20261008-boundaries.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"rule":Melee.RULE,"coordinate_base":0,"fixture":"three original-stat roles, mirrored equal-state isolated boundaries; real _brain/_tick; not natural deployment evidence","cases":evidence,"guard_road_release_live_AI":guard_road_reports,"road_fixture_cooldown":100,"failures":failures},"\t"))
	print("BOARD_TRIAL_MELEE_UNIFIED isolated_mirrored_boundaries=true failures=",failures)
	quit(1 if failures else 0)
