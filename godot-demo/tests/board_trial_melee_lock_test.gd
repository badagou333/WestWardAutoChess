extends "res://tests/board_trial_ai_test.gd"
var traces := {}

func fixture():
	var game = fresh()
	isolate(game,["guard_monk","E1","E2","tangseng"])
	game._set_cell(game._record("guard_monk"),Vector2i(5,3))
	game._set_cell(game._record("tangseng"),Vector2i(0,0))
	game._set_cell(game._record("E1"),Vector2i(8,3))
	game._set_cell(game._record("E2"),Vector2i(7,3))
	game.start_battle()
	var monk: Dictionary = game._record("guard_monk")
	monk.cell = Vector2i(6,3)
	monk.node.position = Config.center(monk.cell)
	monk.target = "E1"
	for actor in game.actors:
		if actor.id in ["E1","E2","tangseng"]:
			actor.think = 100000.0
			actor.cooldown = 100000.0
	return game

func sequence(game, label: String, seconds: float) -> Array:
	var trace := []
	var previous := ""
	var monk: Dictionary = game._record("guard_monk")
	for frame in range(ceili(seconds/Config.STEP)):
		game.step(Config.STEP)
		ownership(game)
		var state := [monk.target,str(monk.cell),str(monk.move.get("to",monk.cell)),monk.mode]
		var key := JSON.stringify(state)
		if key!=previous:
			trace.append({"time":game.elapsed,"state":state,"blocked":monk.blocked_elapsed})
			previous = key
	traces[label] = trace
	return trace

func short_block(fps: int, speed: int) -> Array:
	var game = fixture()
	var monk: Dictionary = game._record("guard_monk")
	var second: Dictionary = game._record("E2")
	check(game._move(second,Vector2i(7,2)),"real E2 segment reserves sole attack cell 7,3")
	var states := []
	var previous := ""
	game.speed = speed
	while game.elapsed<1.5:
		game.step(1.0/fps)
		ownership(game)
		check(monk.target=="E1" and not monk.mode.begins_with("归位"),"short source reservation never releases E1 or returns to anchor")
		var state := [monk.target,str(monk.cell),str(monk.move.get("to",monk.cell))]
		var key := JSON.stringify(state)
		if key!=previous:
			states.append(state)
			previous = key
	check(monk.cell==Vector2i(7,3) and monk.node.presentation.events.basic_attack>0,"after E2 completes, monk advances once to 7,3 and attacks locked E1")
	check(monk.blocked_elapsed==0,"successful progress/attack clears no-progress clock")
	traces["short_block_%d_%d" % [fps,speed]] = states
	game.free()
	return states

func run() -> void:
	var a := short_block(30,1)
	check(a==short_block(120,2),"short-block target/grid sequence stable across FPS and speed")
	var game = fixture()
	var monk: Dictionary = game._record("guard_monk")
	var first: Dictionary = game._record("E1")
	var second: Dictionary = game._record("E2")
	game._set_cell(second,Vector2i(6,2))
	sequence(game,"near_enemy_does_not_steal",0.75)
	check(monk.target=="E1","new adjacent E2 never steals a valid E1 lock")
	first.node.take_damage(first.hp_max)
	monk.node.presentation.reset_visual()
	monk.think = 0
	game._brain(monk,Config.STEP)
	check(monk.target=="E2" and not monk.mode.begins_with("归位"),"kill selects nearby E2 from current cell, not via anchor")
	game.free()
	# Death and out-of-aggro during a half-finished segment cannot reverse that cell.
	for died in [true,false]:
		game = fixture()
		monk = game._record("guard_monk")
		first = game._record("E1")
		second = game._record("E2")
		game._set_cell(second,Vector2i(6,2))
		game.step(Config.STEP)
		var to: Vector2i = monk.move.to
		game.step(monk.walk*0.45)
		if died: first.node.take_damage(first.hp_max)
		else: game._set_cell(first,Vector2i(11,6))
		game.step(Config.STEP)
		check(monk.target=="E1" and monk.move.to==to,"half segment preserves target/destination before death/range release")
		game.step(monk.walk-float(monk.move.time)+Config.STEP)
		check(monk.cell==to and monk.target=="E2" and monk.anchor==Vector2i(5,3),"exact original segment commits before current-cell retarget")
		sequence(game,"segment_death" if died else "segment_range",0.8)
		check(monk.target=="E2" and monk.anchor==Vector2i(5,3),"later pursuit follows new E2 without anchor drift")
		game.free()
	# Permanent snapshot block is only a safety release after TWO sim seconds.
	game = fixture()
	monk = game._record("guard_monk")
	game._set_cell(game._record("E2"),Vector2i(7,3))
	sequence(game,"long_block_before_threshold",1.9)
	check(monk.target=="E1" and monk.cell==Vector2i(6,3) and monk.blocked_elapsed<2,"1.9-second obstruction retains E1")
	var held: float = monk.blocked_elapsed
	game.paused = true
	game.step(10)
	check(monk.blocked_elapsed==held and monk.target=="E1","pause freezes no-progress clock and lock")
	game.paused = false
	sequence(game,"long_block_release",0.2)
	check(monk.target=="E2" and monk.node.presentation.events.basic_attack>0,"2s still-unreachable E1 releases safely to adjacent reachable E2")
	check(monk.blocked_elapsed==0,"normal attack wait never counts as long obstruction")
	sequence(game,"attack_wait_is_not_block",3.0)
	check(monk.target=="E2" and monk.blocked_elapsed==0,"repeated attacks/cooldown wait longer than 2 seconds never release a reachable target")
	game.retry()
	monk = game._record("guard_monk")
	check(monk.target.is_empty() and monk.route.is_empty() and monk.blocked_elapsed==0 and not monk.blocked and monk.progress_time==-1,"retry clears every new route/clock/progress field")
	game.free()
	game = fixture()
	monk = game._record("guard_monk")
	sequence(game,"block_recovers_at_1_9",1.9)
	game._set_cell(game._record("E2"),Vector2i(7,2))
	sequence(game,"recovery_keeps_original",0.8)
	check(monk.target=="E1" and monk.cell==Vector2i(7,3) and monk.blocked_elapsed==0,"late path recovery retains original lock and clears continuous clock")
	game.free()
	# Preserve a valid cached route even when another equal BFS route exists.
	game = fixture()
	monk = game._record("guard_monk")
	game._set_cell(game._record("E1"),Vector2i(5,1))
	game._set_cell(game._record("E2"),Vector2i(9,6))
	monk.target = "E1"
	monk.route_goal = Vector2i(5,1)
	monk.route = [Vector2i(6,3),Vector2i(6,2),Vector2i(5,2)]
	game.step(Config.STEP)
	check(monk.move.to==Vector2i(6,2),"valid cached path wins over different BFS tie route")
	game.free()
	# No legal enemies -> return; a new enemy may interrupt at the next boundary.
	game = fixture()
	monk = game._record("guard_monk")
	monk.cell = Vector2i(7,3)
	monk.node.position = Config.center(monk.cell)
	game._set_cell(game._record("E1"),Vector2i(11,6))
	game._set_cell(game._record("E2"),Vector2i(10,6))
	game.step(Config.STEP)
	check(monk.move.to==Vector2i(6,3) and monk.target.is_empty(),"out-of-aggro targets start only one return cell, never global chase")
	game.step(monk.walk*0.45)
	game._set_cell(game._record("E2"),Vector2i(6,2))
	check(monk.target.is_empty(),"return segment does not retarget half a cell")
	sequence(game,"return_then_engage",0.8)
	check(monk.cell==Vector2i(6,3) and monk.cell!=monk.anchor and monk.target=="E2" and not monk.mode.begins_with("归位"),"return boundary accepts new enemy BEFORE reaching anchor")
	game.free()
	# A legal deployment ally seals the sole attack cell; no alternate enemy.
	game = fixture()
	monk = game._record("guard_monk")
	monk.cell = Vector2i(5,2)
	monk.node.position = Config.center(monk.cell)
	game._set_cell(game._record("E1"),Vector2i(5,0))
	game._set_cell(game._record("E2"),Vector2i(11,6))
	var blocker: Dictionary = game._record("wild_hunter")
	blocker.dead = false
	blocker.node.battle_dead = false
	blocker.node.active_in_battle = true
	blocker.node.health = blocker.hp_max
	blocker.node.presentation.reset_visual()
	blocker.think = 100000.0
	blocker.cooldown = 100000.0
	game._set_cell(blocker,Vector2i(5,1))
	sequence(game,"long_block_no_alternate",1.9)
	check(monk.target=="E1","friendly block never causes premature lock release")
	sequence(game,"long_block_no_enemy_return",0.8)
	check(monk.target.is_empty() and monk.cell==monk.anchor,"2s safety release with no reachable enemy returns, never attacks/passes ally")
	game.free()
	for key in ["A","B","C"]:
		var reference := simulate(key,30,1)
		game = fresh()
		game.load_formation(key)
		game.start_battle()
		game.speed = 2
		var paused_once := false
		while game.phase==game.Phase.BATTLE and game.elapsed<60:
			game.step(1.0/120)
			ownership(game)
			if not paused_once and game.elapsed>=2:
				monk = game._record("guard_monk")
				var before: Dictionary = game.report()
				var blocked: float = monk.blocked_elapsed
				var route: Array = monk.route.duplicate()
				game.paused = true
				game.step(20)
				check(game.report()==before and monk.blocked_elapsed==blocked and monk.route==route,"natural pause freezes full result/events plus new route/obstruction state")
				game.paused = false
				paused_once = true
		check(paused_once and comparable(reference)==comparable(game.report()) and is_equal_approx(reference.seconds,game.elapsed),"new natural "+key+" full result stable under FPS/pause/2x")
		game.free()
	var file := FileAccess.open("/tmp/board-d004-melee-traces.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"rule":"monk-lock-d004","traces":traces,"failures":failures},"\t"))
	print("BOARD_TRIAL_MELEE_LOCK failures=",failures)
	quit(1 if failures else 0)
