extends "res://tests/board_trial_ranged_natural_test.gd"
## Uniform tile speed only. Fixtures below are NOT natural combat/balance evidence.
const HeroCatalog = preload("res://scripts/data/demo_units.gd")
const EnemyCatalog = preload("res://scripts/enemy.gd")
const UNIFORM_MOVERS := ["guard_monk","wild_hunter","sparrow_spirit","foxfire_imp","E1","E2","E3","E4","E5","E6"]
const DELAY := [Vector2i(2,4),Vector2i(1,5),Vector2i(2,2),Vector2i(3,4),Vector2i(1,4),Vector2i(2,6)]
const VIDEO_2137 := [Vector2i(2,4),Vector2i(4,4),Vector2i(2,3),Vector2i(2,5),Vector2i(1,4),Vector2i(3,4)]
const CASE_KEYS := ["A","B","C","video","video_d007","video_delay","video_2137"]
var active_key := ""
var completed_segments := {}
var pending_segments := {}
var fixture_evidence := []
var compact_cases := {}

class MotionFixtureGame extends "res://scripts/board_trial.gd":
	# Isolate movement interpolation/lifecycle, explicitly bypassing combat brains.
	# Natural cases use the inherited TraceGame and all twelve production brains.
	func _brain(_actor: Dictionary, _delta: float) -> void: pass

func assert_uniform_roster(game, label: String) -> void:
	check(game.actors.size()==12,"uniform roster retains twelve actors "+label)
	var count := 0
	for actor in game.actors:
		if actor.id in UNIFORM_MOVERS:
			count += 1
			check(is_equal_approx(actor.walk,Config.MOVE_SECONDS_PER_CELL) and is_equal_approx(actor.node.move_interval,Config.MOVE_SECONDS_PER_CELL),"actor/node both use uniform tile duration "+actor.id+" "+label)
		var expected: Dictionary
		if actor.id=="tangseng": expected=Config.CORE
		elif actor.friendly: expected=HeroCatalog.HEROES[actor.key]
		else: expected=EnemyCatalog.ENEMY_DATA[actor.key]
		var hp_factor: float=1.0 if actor.friendly else Config.ENEMY_HP_FACTOR
		var damage_factor: float=1.0 if actor.friendly else Config.ENEMY_DAMAGE_FACTOR
		check(is_equal_approx(actor.hp_max,float(expected.hp)*hp_factor) and is_equal_approx(actor.damage,float(expected.damage)*damage_factor) and is_equal_approx(actor.interval,float(expected.interval)),"uniform move does not replace HP/damage/attack interval "+actor.id+" "+label)
		var reach: int=int(expected.range) if actor.friendly else (3 if actor.key=="rat" else 1)
		check(actor.reach==reach,"uniform move preserves actual attack/heal range "+actor.id+" "+label)
	check(count==10,"all ten and only the expected movable actors are covered "+label)

func fresh():
	var game=super.fresh()
	assert_uniform_roster(game,"fresh")
	return game

func load_case(game, key: String) -> void:
	active_key=key
	completed_segments[key]=[]
	pending_segments.clear()
	if key in ["video_delay","video_2137"]:
		var cells: Array=DELAY if key=="video_delay" else VIDEO_2137
		game.deployment.clear()
		for index in Config.FRIENDS.size(): game.deployment[Config.FRIENDS[index]]=cells[index]-Vector2i.ONE
		game._reset_roster()
	else: super.load_case(game,key)
	assert_uniform_roster(game,"load "+key)

func observe(game) -> void:
	var current := sample(game)
	for index in current.size():
		var old: Dictionary=game.previous[index]
		var now: Dictionary=current[index]
		if now.dead:
			pending_segments.erase(now.id) # Death may legitimately abort a segment.
			continue
		if not old.move.is_empty() and old.move.time+Config.STEP+0.00000001>=old.move.duration:
			check(pending_segments.has(now.id),"completed natural movement has an observed real start "+now.id)
			if pending_segments.has(now.id):
				var issued: Dictionary=pending_segments[now.id]
				var actual_duration: float=game.elapsed-issued.time
				check(now.cell==issued.to and is_equal_approx(actual_duration,Config.MOVE_SECONDS_PER_CELL),"natural movement commits exact destination after 0.5 simulation seconds "+now.id)
				completed_segments[active_key].append({"id":now.id,"start":issued.time,"end":game.elapsed,"seconds":actual_duration,"from":issued.from,"to":issued.to})
			pending_segments.erase(now.id)
		if not now.move.is_empty():
			check(now.id in UNIFORM_MOVERS and is_equal_approx(now.move.duration,Config.MOVE_SECONDS_PER_CELL),"every issued natural segment really uses the uniform duration "+now.id)
			if not pending_segments.has(now.id):
				pending_segments[now.id]={"time":game.elapsed-now.move.time,"from":now.move.from,"to":now.move.to}
	# Preserve every inherited STEP assertion: all-actor ownership, dual-end
	# reservations, full segments, real attack range, interpolated feet and immobility.
	super.observe(game)

func roster_lifecycle() -> void:
	var game=fresh()
	for key in CASE_KEYS:
		load_case(game,key)
		check(game.start_battle(),"lifecycle formation starts "+key)
		game.step(0.3)
		game.retry()
		assert_uniform_roster(game,"retry "+key)
		check(game.actors.all(func(actor): return actor.move.is_empty() and actor.target.is_empty() and actor.cooldown==0),"retry clears motion/target/cooldown with uniform speed "+key)
	game.free()

func movement_fixture(id: String, vertical: bool) -> void:
	var game=MotionFixtureGame.new()
	root.add_child(game)
	game.set_process(false)
	game.audio_feedback.enabled=false
	assert_uniform_roster(game,"isolated "+id)
	var actor: Dictionary=game._record(id)
	var core: Dictionary=game._record("tangseng")
	var healer: Dictionary=game._record("herbal_spirit_child")
	var from := Vector2i(3,3)
	var to := from+(Vector2i.DOWN if vertical else Vector2i.RIGHT)
	game._set_cell(core,Vector2i(0,6))
	game.deployment.tangseng=core.cell
	game._set_cell(healer,Vector2i(0,5))
	game._set_cell(game._record("E6"),Vector2i(11,6))
	game._set_cell(actor,from)
	check(game.start_battle(),"isolated interpolation fixture starts "+id)
	isolate(game,["tangseng","herbal_spirit_child",id,"E6"])
	check(game._move(actor,to),"actual controller issues isolated adjacent movement "+id)
	var started: float=game.elapsed
	for tick in range(30):
		game.step(Config.STEP)
		ownership(game)
	check(game.phase==game.Phase.BATTLE and not actor.move.is_empty() and actor.cell==from,"halfway fixture remains in its reserved segment "+id)
	var midpoint: Vector2=Config.center(from).lerp(Config.center(to),0.5)
	check(actor.node.position.distance_to(midpoint)<0.000001 and is_equal_approx(actor.move.time,0.25),"actual foot reaches exact halfway position after 0.25 seconds "+id)
	check(actor.node.presentation.foot_anchor==Vector2.ZERO,"isolated actor retains board foot origin "+id)
	var paused_report: Dictionary=game.report().duplicate(true)
	var paused_move: Dictionary=actor.move.duplicate(true)
	var paused_position: Vector2=actor.node.position
	game.paused=true
	game.step(3.0)
	check(game.report()==paused_report and actor.move==paused_move and actor.node.position==paused_position,"pause freezes the actual half-complete segment "+id)
	game.paused=false
	for tick in range(29):
		game.step(Config.STEP)
		ownership(game)
	check(actor.cell==from and not actor.move.is_empty() and actor.node.position!=Config.center(to),"fixture cannot commit destination before full 0.5 seconds "+id)
	game.step(Config.STEP)
	ownership(game)
	check(actor.cell==to and actor.move.is_empty() and actor.node.position==Config.center(to) and is_equal_approx(game.elapsed-started,0.5),"actual full tile commits exactly at 0.5 seconds "+id)
	check(core.cell==core.anchor and core.move.is_empty() and healer.cell==healer.anchor and healer.move.is_empty(),"Tang/healer remain stationary through isolated movement "+id)
	check(game.metrics.attack_times.is_empty(),"movement fixture does not masquerade as natural combat evidence "+id)
	fixture_evidence.append({"kind":"isolated_interpolation_brains_disabled","id":id,"axis":"vertical" if vertical else "horizontal","from":cell_data(from),"to":cell_data(to),"half_seconds":0.25,"half_foot":[midpoint.x,midpoint.y],"full_seconds":game.elapsed-started,"paused_mid_segment":true})
	game.free()

func run() -> void:
	check(Config.VERSION=="board-v2-uniform-move" and is_equal_approx(Config.MOVE_SECONDS_PER_CELL,0.5),"uniform movement has its independent configuration version and 0.5-second default")
	roster_lifecycle()
	for id in UNIFORM_MOVERS:
		movement_fixture(id,false)
		movement_fixture(id,true)
	for key in CASE_KEYS:
		var first:=natural(key,30,1,true,false)
		var segments: Array=completed_segments[key].duplicate(true)
		var second:=natural(key,120,2,false,true)
		check(first==second and segments==completed_segments[key],"entire natural report and completed movement timeline repeat across FPS/2x/pause "+key)
		check(not segments.is_empty(),"natural case includes real completed movement "+key)
		var coverage := {}
		for segment in segments: coverage[segment.id]=coverage.get(segment.id,0)+1
		compact_cases[key]={"kind":"natural_all_12_production_AI","steps":cases[key].steps,"completed_segments":segments.size(),"movement_coverage":coverage,
			"every_step_checked":true,"every_completed_duration_seconds":Config.MOVE_SECONDS_PER_CELL,"report_and_timeline_repeat_equal":first==second and segments==completed_segments[key]}
		current_reports.append({"formation":key,"report":first,"public_schedules":[[30,1],[120,2]],"paused_repeat":true})
	check(fixture_evidence.size()==UNIFORM_MOVERS.size()*2,"all twenty isolated horizontal/vertical fixtures completed")
	check(current_reports.size()==CASE_KEYS.size() and compact_cases.size()==CASE_KEYS.size(),"all seven natural comparisons completed")
	var file:=FileAccess.open("/tmp/board-uniform-movement-20261009.json",FileAccess.WRITE)
	check(file!=null,"independent uniform movement report opens")
	if file!=null:
		file.store_string(JSON.stringify({"config":Config.VERSION,"move_seconds_per_cell":Config.MOVE_SECONDS_PER_CELL,"mobile_ids":UNIFORM_MOVERS,
			"natural_kind":"all_12_production_AI_no_stat_or_brain_overrides","comparisons":current_reports,"cases":compact_cases,
			"isolated_motion_fixtures":fixture_evidence,"failures":failures},"\t"))
	print("BOARD_UNIFORM_MOVEMENT natural=7 isolated_motion=",fixture_evidence.size()," failures=",failures)
	quit(1 if failures else 0)
