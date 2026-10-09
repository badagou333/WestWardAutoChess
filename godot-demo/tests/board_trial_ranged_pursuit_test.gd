extends "res://tests/board_trial_ai_test.gd"
## Original ranged safety/abilities plus landing-based target refresh live fixtures.
## Six live-AI state-fixture runs, not natural deployment/balance evidence.
const Catalog = preload("res://scripts/data/demo_units.gd")
const OUTPUTS := ["wild_hunter","sparrow_spirit","foxfire_imp"]
var reports := []
var splash_evidence := {}

class AuditedBoard:
	extends "res://scripts/board_trial.gd"
	var observed_key := ""
	var violations: Array[String] = []
	var shots: Array[Dictionary] = []
	var moves: Array[Dictionary] = []
	var resolved_amounts: Array[float] = []
	var max_column := -1
	var max_anchor_distance := 0
	var first_departure := -1.0
	var stationary_since := -1.0
	var stationary_target := ""
	func _brain(actor: Dictionary, delta: float) -> void:
		var before_move: Dictionary = actor.move.duplicate(true)
		var before_target: String = actor.target
		var before_pose: String = actor.node.presentation.pose
		var before_attacks: int = metrics.attack_times.get(actor.id,[]).size()
		super._brain(actor,delta)
		if actor.id!=observed_key and actor.id!="E5": return
		if not before_move.is_empty() and (actor.move!=before_move or actor.target!=before_target): violations.append(actor.id+" changes its in-flight move/target in brain")
		if before_pose=="basic_attack" and actor.target!=before_target: violations.append(actor.id+" changes target during attack activity")
		if metrics.attack_times.get(actor.id,[]).size()>before_attacks:
			var target: Dictionary = _record(actor.target)
			var distance: int = Config.distance(actor.cell,target.cell) if _active(target) else -1
			if not actor.move.is_empty() or distance<0 or distance>actor.reach: violations.append(actor.id+" attacks outside real range or during a move")
			shots.append({"time":elapsed,"id":actor.id,"target":actor.target,"range":distance,"cell":[actor.cell.x,actor.cell.y]})
	func _move(actor: Dictionary, next: Vector2i) -> bool:
		# A production tick now commits collected requests after ALL brains.
		# Audit the actual commit rather than assuming the brain starts movement.
		var before_move: Dictionary = actor.move.duplicate(true)
		var owner_before: Dictionary = _occupant(next,actor.id)
		var committed: bool = super._move(actor,next)
		if not committed or (actor.id!=observed_key and actor.id!="E5"): return committed
		if not before_move.is_empty(): violations.append(actor.id+" replaces an in-flight segment during movement commit")
		if Config.distance(actor.move.from,actor.move.to)!=1 or not Config.valid(actor.move.to): violations.append(actor.id+" issues non-neighbor/outside move")
		if not owner_before.is_empty(): violations.append(actor.id+" claims another body's reservation")
		if not _occupant(actor.move.to,actor.id).is_empty(): violations.append(actor.id+" destination is shared after movement commit")
		moves.append({"time":elapsed,"id":actor.id,"from":[actor.move.from.x,actor.move.from.y],"to":[actor.move.to.x,actor.move.to.y],"target":actor.target})
		return committed
	func _resolve(target, amount: float, healing: bool, event: Dictionary) -> void:
		var source: Dictionary = _by_node(event.source)
		if not source.is_empty() and source.id==observed_key and not healing: resolved_amounts.append(amount)
		super._resolve(target,amount,healing,event)
	func _tick(delta: float) -> void:
		super._tick(delta)
		var source: Dictionary = _record(observed_key)
		var original_target: Dictionary = _record("E5")
		var current_target: Dictionary = _record(source.get("target",""))
		for actor in [source,original_target,current_target]:
			if not _active(actor): continue
			var foot: Vector2 = Config.center(actor.cell)
			if not actor.move.is_empty(): foot = Config.center(actor.move.from).lerp(Config.center(actor.move.to),minf(1,actor.move.time/actor.move.duration))
			if actor.node.position.distance_to(foot)>0.001: violations.append(actor.id+" foot differs from its real grid segment")
		if not _active(source) or not _active(original_target): return
		max_column = maxi(max_column,source.cell.x)
		max_anchor_distance = maxi(max_anchor_distance,Config.distance(source.cell,source.anchor))
		var original_distance: int = Config.distance(source.cell,original_target.cell)
		if first_departure<0 and not metrics.attack_times.get(source.id,[]).is_empty() and original_distance>source.reach: first_departure = elapsed
		# Landing can now choose a cheaper opponent. Measure the final real dwell
		# against the CURRENT combat target, clearing transient earlier dwell.
		var dwelling: bool = _active(current_target) and source.move.is_empty() and current_target.move.is_empty() and Config.distance(source.cell,current_target.cell)<=source.reach
		if dwelling:
			if stationary_since<0 or stationary_target!=current_target.id: stationary_since=elapsed
			stationary_target=current_target.id
		else:
			stationary_since=-1.0
			stationary_target=""

func fixture(key: String, enemies: Array = ["E1","E2"], extra_friends: Array = []):
	var game = fresh()
	game.start_battle()
	var live: Array = [key,"tangseng"]
	live.append_array(enemies)
	live.append_array(extra_friends)
	isolate(game,live)
	game._set_cell(game._record("tangseng"),Vector2i(0,6))
	var source: Dictionary = game._record(key)
	game._set_cell(source,Vector2i(1,3))
	var positions := {"E1":Vector2i(8,3),"E2":Vector2i(8,6),"E3":Vector2i(9,0),"E4":Vector2i(9,6)}
	for id in enemies:
		if positions.has(id): game._set_cell(game._record(id),positions[id])
	for actor in game.actors:
		if game._active(actor): actor.cooldown = 10.0
	return game

func keep_lock_range_and_cost(key: String) -> void:
	var game = fixture(key)
	var source: Dictionary = game._record(key)
	source.target = "E1"
	game._set_cell(game._record("E2"),Vector2i(5,3))
	check(game._target_legal(source,game._record("E1")),key+" out-of-range old target is legal through its reachable attack position")
	game._brain(source,Config.STEP)
	check(source.target=="E1" and not source.move.is_empty(),key+" legal old target survives closer reachable enemy appearance")
	check(source.route.is_empty() and source.handoff.is_empty(),key+" gray-rat pursuit does not enter melee cached-route/handoff policy")
	game.free()
	game = fixture(key)
	source = game._record(key)
	game._set_cell(game._record("E1"),Vector2i(4,3))
	game._set_cell(game._record("E2"),Vector2i(2,3))
	game.actors.reverse() # Single-brain stable-ID boundary, not production order.
	check(game._best_target(source).id=="E1",key+" all real in-range attack costs are zero, so ID precedes Manhattan closeness")
	source.target = "E1"
	var cooldown: float = source.cooldown
	game._brain(source,Config.STEP)
	check(source.target=="E1" and source.move.is_empty() and is_equal_approx(source.cooldown,cooldown-Config.STEP),key+" real range-three cooldown dwell holds position and old target")
	check(game.metrics.attack_times.get(key,[]).is_empty(),key+" cooldown is not reset/bypassed for a closer in-range enemy")
	game.free()
	game = fixture(key)
	source = game._record(key)
	source.target = "E1"
	source.cell = Vector2i(5,3) # Preserve original anchor(1,3) for explicit cross-line boundary.
	source.node.position = Config.center(source.cell)
	game._set_cell(game._record("E1"),Vector2i(10,3))
	game._brain(source,Config.STEP)
	check(not source.move.is_empty() and source.move.get("to")==Vector2i(6,3) and Config.distance(source.anchor,source.move.to)>2,key+" original anchor does not impose LEASH2 or left-half battle restriction")
	game.free()

func death_and_unreachable(key: String) -> void:
	var game = fixture(key,["E1","E2","E3","E4"])
	var source: Dictionary = game._record(key)
	source.target = "E1"
	game._record("E1").node.take_damage(game._record("E1").hp_max)
	game._set_cell(game._record("E2"),Vector2i(6,3))
	game._set_cell(game._record("E3"),Vector2i(1,6))
	game._set_cell(game._record("E4"),Vector2i(1,0))
	game._brain(source,Config.STEP)
	check(source.target=="E3" and source.move.is_empty(),key+" dead target reselects lowest reachable attack cost then stable ID")
	game.free()
	game = fixture(key,["E1","E2"],["herbal_spirit_child"])
	source = game._record(key)
	game._set_cell(source,Vector2i(0,0))
	game._set_cell(game._record("tangseng"),Vector2i(1,0))
	game._set_cell(game._record("herbal_spirit_child"),Vector2i(0,1))
	game._set_cell(game._record("E1"),Vector2i(8,0))
	game._set_cell(game._record("E2"),Vector2i(3,0))
	source.target = "E1"
	check(game._active(game._record("E1")) and not game._target_legal(source,game._record("E1")),key+" alive old target really has no path through sealed corner")
	game._brain(source,Config.STEP)
	check(source.target=="E2" and source.move.is_empty(),key+" unreachable old target releases at SCAN without monk two-second lock")
	game.free()
	game = fixture(key,["E1","E2"],["herbal_spirit_child"])
	source = game._record(key)
	game._set_cell(source,Vector2i(0,0))
	game._set_cell(game._record("tangseng"),Vector2i(1,0))
	game._set_cell(game._record("herbal_spirit_child"),Vector2i(0,1))
	game._set_cell(game._record("E1"),Vector2i(8,0))
	source.target = "E1"
	game._brain(source,Config.STEP)
	check(source.target.is_empty() and source.move.is_empty() and source.cell==Vector2i(0,0),key+" no reachable enemy waits in current cell, never returns/blindly walks")
	game._set_cell(game._record("tangseng"),Vector2i(1,4))
	game._brain(source,Config.STEP)
	check(source.target.is_empty() and source.move.is_empty(),key+" newly opened path still respects original SCAN retry timing")
	for index in range(30): game._brain(source,Config.STEP)
	check(source.target=="E1" and not source.move.is_empty(),key+" next SCAN resumes real reachable pursuit after blocker release")
	game.free()

func activity_and_reservations(key: String) -> void:
	var game = fixture(key)
	var source: Dictionary = game._record(key)
	source.target = "E1"
	check(game._move(source,Vector2i(2,3)),key+" starts real adjacent source segment")
	var segment: Dictionary = source.move.duplicate(true)
	game._record("E1").node.take_damage(game._record("E1").hp_max)
	game._brain(source,Config.STEP)
	check(source.target=="E1" and source.move==segment,key+" target death cannot cancel or turn an in-flight source half a cell")
	while source.cell==Vector2i(1,3) and game.elapsed<source.walk+0.2: game._tick(Config.STEP)
	check(source.cell==Vector2i(2,3) and source.target=="E2" and (source.move.is_empty() or source.move.from==source.cell),key+" original segment completes before dead-target reselect/new movement")
	game.free()
	game = fixture(key)
	source = game._record(key)
	game._set_cell(game._record("E1"),Vector2i(4,3))
	game._set_cell(game._record("E2"),Vector2i(2,3))
	source.target = "E1"
	source.cooldown = 0
	game._brain(source,Config.STEP)
	check(source.node.presentation.pose=="basic_attack",key+" starts a real production projectile attack")
	game._record("E1").node.take_damage(game._record("E1").hp_max)
	game._brain(source,Config.STEP)
	check(source.target=="E1" and source.move.is_empty(),key+" attack activity safely finishes before changing dead target")
	while source.node.presentation.pose=="basic_attack" and game.elapsed<2: game._tick(Config.STEP)
	source.think = 0
	game._brain(source,Config.STEP)
	check(source.target=="E2" and source.move.is_empty(),key+" completed attack activity permits the next original-SCAN target decision")
	game.free()
	var buddy: String = "wild_hunter" if key!="wild_hunter" else "foxfire_imp"
	game = fixture(key,["E1"],[buddy])
	source = game._record(key)
	var other: Dictionary = game._record(buddy)
	game._set_cell(other,Vector2i(2,2))
	check(game._move(source,Vector2i(2,3)),key+" reserves source and destination for real ranged movement")
	check(game._occupant(Vector2i(1,3),buddy).id==key and game._occupant(Vector2i(2,3),buddy).id==key,key+" both endpoints remain owned until segment completes")
	check(not game._move(other,Vector2i(2,3)),key+" another ranged hero cannot double-claim occupied destination")
	var path: Array = game._path(source,game._record("E1").cell,source.reach)
	check(not path.is_empty() and path.back()!=game._record("E1").cell and Config.distance(path.back(),game._record("E1").cell)==3,key+" route ends at a real empty range-three attack cell, never target body")
	check(not game._move(source,Vector2i(-1,0)),key+" no movement outside board")
	ownership(game)
	game.free()

func clock_snapshot(game) -> Dictionary:
	var state := {"report":game.report(),"actors":[]}
	for actor in game.actors:
		if not game._active(actor): continue
		state.actors.append({"id":actor.id,"cell":actor.cell,"target":actor.target,"move":actor.move.duplicate(true),"cooldown":actor.cooldown,"think":actor.think,"position":actor.node.position,"pose_time":actor.node.presentation.pose_time})
	return state

func live_departure_and_pursuit(key: String, fps: int, sim_speed: int) -> Dictionary:
	var game = AuditedBoard.new()
	# Preserve the original exact-stat pursuit fixture, not default-bear balance.
	game.enemy_profile = "legacy"
	root.add_child(game)
	game.set_process(false)
	game.audio_feedback.enabled = false
	game.start_battle()
	isolate(game,[key,"E5","E1","guard_monk","tangseng"])
	var source: Dictionary = game._record(key)
	var target: Dictionary = game._record("E5")
	var holder: Dictionary = game._record("E1")
	var guard: Dictionary = game._record("guard_monk")
	var core: Dictionary = game._record("tangseng")
	# Explicit post-start state fixture: the initial rat actually departs range3.
	# Landing-based cheaper-target reevaluation applies to BOTH pursuers; this
	# fixture no longer requires the rat to retain a distant core forever.
	# Every survivor runs its actual brain. HP/CD fixture prevents settlement;
	# guard/E1 hold each other at real range1, Tang remains stationary at (11,6).
	for placement in [[source,Vector2i(4,0)],[target,Vector2i(7,0)],[holder,Vector2i(8,6)],[guard,Vector2i(9,6)],[core,Vector2i(11,6)]]: game._set_cell(placement[0],placement[1])
	for actor in [source,target,holder,guard,core]:
		actor.node.max_health = 10000.0
		actor.node.health = 10000.0
		actor.hp_max = 10000.0
	source.target = target.id
	target.target = core.id
	holder.target = guard.id
	guard.target = holder.id
	for actor in [holder,guard,core]: actor.cooldown = 100.0
	game.observed_key = key
	game.speed = sim_speed
	var paused_once := false
	while game.phase==game.Phase.BATTLE and game.elapsed+0.00000001<12:
		game.step(1.0/fps)
		ownership(game)
		if not paused_once and game.elapsed>=2:
			game.paused = true
			var before := clock_snapshot(game)
			game.step(5)
			check(clock_snapshot(game)==before,key+" live moving/attack clocks, reservations, targets and HP freeze when paused")
			game.paused = false
			paused_once = true
	check(game.phase==game.Phase.BATTLE and game._active(source) and game._active(target),key+" explicit high-HP live fixture remains active, not frozen/dead-target simulation")
	check(game.violations.is_empty(),key+" all actual STEP attack ranges, safe activities, neighbor reservations and grid foot points: "+str(game.violations))
	var pursuit_steps: Array = game.moves.filter(func(row): return row.id==key and row.time+0.00000001>=game.first_departure)
	check(game.first_departure>0 and not pursuit_steps.is_empty(),key+" actual initial range3 target leaves and source commits real pursuit movement afterward")
	check(not game.moves.filter(func(row): return row.id=="E5").is_empty(),key+" opponent really moves under its existing live gray-rat brain")
	var settled_target: Dictionary = game._record(source.target)
	check(game._active(settled_target) and game._target_legal(source,settled_target) and source.move.is_empty() and settled_target.move.is_empty() and Config.distance(source.cell,settled_target.cell)<=3,key+" live pursuit ends at the current actual legal range3 target with original cooldown/attack dwell")
	var expected: Dictionary = Catalog.HEROES[key]
	check(source.damage==expected.damage and source.node.damage==expected.damage and source.interval==expected.interval and source.reach==3,key+" original damage/attack interval/reach data unchanged")
	check(source.walk==Config.MOVE_SECONDS_PER_CELL and source.node.move_interval==Config.MOVE_SECONDS_PER_CELL,key+" uses shared trial movement duration")
	var damage: float = game.metrics.damage.get(key,0)
	var actual_loss: float = (10000.0-target.node.health)+(10000.0-holder.node.health)
	check(damage>0 and is_equal_approx(damage,actual_loss) and is_equal_approx(fmod(damage,source.damage),0),key+" actual resolved HP loss uses original per-hit damage, including genuine fox splash if adjacent")
	check(game.resolved_amounts.size()>0 and game.resolved_amounts.all(func(amount): return is_equal_approx(amount,expected.damage)),key+" each real projectile resolution retains original damage")
	var times: Array = game.metrics.attack_times.get(key,[]).filter(func(time): return time+0.00000001>=game.stationary_since)
	check(game.stationary_since>0 and times.size()>=3,key+" actual stationary tail contains repeated production attacks")
	var cadence: float = ceilf((source.interval-0.00000001)/Config.STEP)*Config.STEP
	for index in range(1,times.size()): check(is_equal_approx(times[index]-times[index-1],cadence),key+" original cooldown is only fixed-step rounded, never SCAN-quantized")
	var settled_cell: Vector2i = settled_target.get("cell",Vector2i(-1,-1))
	var result := {"key":key,"fps":fps,"speed":sim_speed,"seconds":game.elapsed,"departure":game.first_departure,"settled":game.stationary_since,"cell":[source.cell.x,source.cell.y],"target":source.target,"target_cell":[settled_cell.x,settled_cell.y],"original_target_cell":[target.cell.x,target.cell.y],"pursuit_steps":pursuit_steps.size(),"max_column":game.max_column,"max_anchor_distance":game.max_anchor_distance,"damage":damage,"hp_loss":actual_loss,"resolved_amounts":game.resolved_amounts.duplicate(),"attack_times":game.metrics.attack_times.get(key,[]).duplicate(),"moves":game.moves.duplicate(true),"shots":game.shots.duplicate(true)}
	var deployment: Dictionary = game.start_deployment.duplicate()
	game.retry()
	source = game._record(key)
	check(game.deployment==deployment and game.phase==game.Phase.DEPLOY and game.elapsed==0 and game.speed==1 and not game.paused,key+" actual retry restores original saved deployment and clocks, not post-start fixture state")
	check(source.target.is_empty() and source.move.is_empty() and source.cooldown==0 and source.cell==source.anchor and source.hp_max==expected.hp and source.node.health==expected.hp,key+" retry clears ranged pursuit and high-HP fixture override")
	check(game.combat.strikes.is_empty() and game.combat.missiles.is_empty(),key+" retry clears actual pending projectile/attack state")
	game.free()
	return result

func comparable_live(report: Dictionary) -> Dictionary:
	var result := report.duplicate(true)
	result.erase("fps")
	result.erase("speed")
	result.erase("seconds")
	return result

func real_fox_splash() -> void:
	# Ability isolation only: two real range-three rat brains dwell on the fox.
	# Explicit high HP/CD prevents settlement/counterdamage, not movement locks.
	var game = fixture("foxfire_imp",["E5","E6"])
	var source: Dictionary = game._record("foxfire_imp")
	var first: Dictionary = game._record("E5")
	var adjacent: Dictionary = game._record("E6")
	game._set_cell(source,Vector2i(3,3))
	game._set_cell(first,Vector2i(5,3))
	game._set_cell(adjacent,Vector2i(5,4))
	for target in [first,adjacent]:
		target.node.max_health = 10000
		target.node.health = 10000
		target.hp_max = 10000
	source.cooldown = 0
	while game.elapsed<0.8:
		game.step(Config.STEP)
		ownership(game)
	check(game.metrics.attack_times.get(source.id,[]).size()==1 and source.target==first.id,"fox executes one real original projectile attack")
	check(is_equal_approx(10000-first.node.health,source.damage) and is_equal_approx(10000-adjacent.node.health,source.damage),"real range-one fox splash applies original damage to the adjacent enemy exactly once")
	check(is_equal_approx(game.metrics.damage.get(source.id,0),2*source.damage) and first.move.is_empty() and adjacent.move.is_empty(),"both active gray-rat brains retain legal ranged dwell; splash metrics equal actual HP loss")
	splash_evidence = {"kind":"live_ability_fixture","fixture_hp":10000,"rat_cooldown":10,
		"seconds":game.elapsed,"attack_times":game.metrics.attack_times.get(source.id,[]),
		"damage":game.metrics.damage.get(source.id,0),"primary_hp_loss":10000-first.node.health,"adjacent_hp_loss":10000-adjacent.node.health}
	game.free()

func run() -> void:
	real_fox_splash()
	for key in OUTPUTS:
		keep_lock_range_and_cost(key)
		death_and_unreachable(key)
		activity_and_reservations(key)
		var first := live_departure_and_pursuit(key,30,1)
		var second := live_departure_and_pursuit(key,120,2)
		check(comparable_live(first)==comparable_live(second),key+" all actual live activity/attack/HP evidence reproduces across 30x1 and120x2 with pause")
		reports.append(first)
		reports.append(second)
	var output := FileAccess.open("/tmp/board-ranged-20261008-boundaries.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"coordinate_base":0,"config":Config.version_for("legacy"),"enemy_profile":"legacy","scope":"legacy_exact_stat_technical_fixtures","rule":"ranged-step-target-20261009","isolated_boundaries":true,"live_AI_state_fixture":true,"fixture_hp":10000,"stationary_holder_core_cooldown":100,"reports":reports,"foxfire_splash":splash_evidence,"failures":failures},"\t"))
	print("BOARD_TRIAL_RANGED_PURSUIT isolated_boundaries=true live_AI_fixture=true failures=",failures)
	quit(1 if failures else 0)
