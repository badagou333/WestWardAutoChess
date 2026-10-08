extends "res://tests/board_trial_ai_test.gd"
## Five unchanged deployments, all twelve production brains, no historical media.
const MOBILE := ["wild_hunter","sparrow_spirit","foxfire_imp"]
const VIDEO := [Vector2i(1,4),Vector2i(6,4),Vector2i(1,3),Vector2i(1,5),Vector2i(2,4),Vector2i(3,4)]
const VIDEO_D007 := [Vector2i(2,4),Vector2i(4,4),Vector2i(2,3),Vector2i(3,4),Vector2i(1,4),Vector2i(2,5)]
var cases := {}
var current_reports := []

class TraceGame extends "res://scripts/board_trial.gd":
	var observer := Callable()
	var previous := []
	var previous_key := ""
	var states := []
	var observed_steps := 0
	func _tick(delta: float) -> void:
		super._tick(delta)
		if observer.is_valid(): observer.call(self)

func fresh():
	var game = TraceGame.new()
	root.add_child(game)
	game.set_process(false)
	game.audio_feedback.enabled = false
	return game

func load_case(game, key: String) -> void:
	if key in ["video","video_d007"]:
		var cells: Array = VIDEO_D007 if key=="video_d007" else VIDEO
		game.deployment.clear()
		for index in Config.FRIENDS.size(): game.deployment[Config.FRIENDS[index]]=cells[index]-Vector2i.ONE
		game._reset_roster()
	else: game.load_formation(key)

func cell_data(cell: Vector2i) -> Array: return [cell.x+1,cell.y+1]

func sample(game) -> Array:
	var state := []
	for actor in game.actors:
		var move := {}
		if not actor.move.is_empty():
			move = {"from":cell_data(actor.move.from),"to":cell_data(actor.move.to),"time":actor.move.time,"duration":actor.move.duration}
		state.append({"id":actor.id,"cell":cell_data(actor.cell),"target":actor.target,"move":move,
			"pose":actor.node.presentation.pose,"cooldown":actor.cooldown,"dead":actor.dead,"hp":game._hp(actor),
			"attacks":game.metrics.attack_times.get(actor.id,[]).size()})
	return state

func signature(state: Array) -> String:
	var discrete: Array = state.duplicate(true)
	for actor in discrete:
		actor.erase("cooldown")
		if not actor.move.is_empty(): actor.move.erase("time")
	return JSON.stringify(discrete)

func observe(game) -> void:
	var current := sample(game)
	ownership(game) # Unique source/destination, legal hero segments, Tang/healer stationary.
	for index in current.size():
		var old: Dictionary = game.previous[index]
		var now: Dictionary = current[index]
		var actor: Dictionary = game._record(now.id)
		if now.dead: continue
		if not old.move.is_empty():
			if old.move.time+Config.STEP+0.00000001<old.move.duration:
				check(now.cell==old.cell and not now.move.is_empty() and now.move.from==old.move.from and now.move.to==old.move.to,"natural live segment is never canceled/redirected half a cell")
			else: check(now.cell==old.move.to,"natural completed segment commits its reserved destination")
		var target: Dictionary = game._record(now.target)
		if now.attacks>old.attacks:
			check(actor.move.is_empty() and game._active(target) and Config.distance(actor.cell,target.cell)<=actor.reach,"natural new attack uses current real range and no movement")
		if not now.move.is_empty():
			check(Config.distance(actor.move.from,actor.move.to)==1,"natural movements are four-neighbor steps")
			var point: Vector2 = Config.center(actor.move.from).lerp(Config.center(actor.move.to),minf(1,actor.move.time/actor.move.duration))
			check(actor.node.position.distance_to(point)<0.000001,"natural actor foot follows exact current segment interpolation")
			if actor.id in MOBILE:
				check(actor.route.is_empty() and actor.handoff.is_empty() and actor.move_serial==0,"three ranged heroes do not acquire melee cache/handoff")
		else: check(actor.node.position==Config.center(actor.cell),"natural stationary foot remains at its committed cell center")
	var key := signature(current)
	if key!=game.previous_key:
		var changed := []
		for index in current.size():
			if signature([current[index]])!=signature([game.previous[index]]): changed.append(current[index])
		game.states.append({"time":game.elapsed,"actors":changed})
	game.previous = current
	game.previous_key = key
	game.observed_steps += 1

func natural(key: String, fps: int, speed: int, record: bool, pause_once: bool) -> Dictionary:
	var game = fresh()
	load_case(game,key)
	check(game.start_battle(),"natural "+key+" starts unchanged roster/parameters/enemies")
	game.previous = sample(game)
	game.previous_key = signature(game.previous)
	game.states.append({"time":0.0,"actors":game.previous})
	game.observer = Callable(self,"observe")
	game.speed = speed
	var paused_once := false
	while game.phase==game.Phase.BATTLE and game.elapsed<120:
		game.step(1.0/fps)
		if pause_once and not paused_once and game.elapsed>=1.0:
			var before: Dictionary = game.report().duplicate(true)
			var state := sample(game)
			var steps: int = game.observed_steps
			game.paused = true
			game.step(5)
			check(game.report()==before and sample(game)==state and game.observed_steps==steps,"natural pause freezes every actor activity/cooldown/events and clocks")
			game.paused = false
			paused_once = true
	var report: Dictionary = game.report().duplicate(true)
	check(game.phase==game.Phase.RESULT and game.result_count==1,"natural "+key+" reaches one actual result without timeout victory")
	if record:
		cases[key] = {"kind":"natural_all_12_production_AI","coordinate_base":1,"steps":game.observed_steps,
			"trace_encoding":"initial full snapshot then changed actors only; omitted actors/discrete states persist; move time/cooldown sampled at events; every STEP checked",
			"states":game.states,"report":report}
	var initial: Dictionary = game.start_deployment.duplicate()
	game.retry()
	check(game.deployment==initial and game.phase==game.Phase.DEPLOY and game.elapsed==0 and not game.paused and game.speed==1,"natural retry restores deployment rather than final combat cells")
	check(game.actors.all(func(actor): return actor.move.is_empty() and actor.target.is_empty() and actor.route.is_empty() and actor.handoff.is_empty() and actor.cooldown==0 and game._hp(actor)==actor.hp_max),"retry rebuilds all live actors without pursuit/event/death residue")
	check(game.combat.strikes.is_empty() and game.combat.missiles.is_empty(),"retry clears every pending attack event")
	game.free()
	return report

func run() -> void:
	for key in ["A","B","C","video","video_d007"]:
		var first := natural(key,30,1,true,false)
		var second := natural(key,120,2,false,true)
		check(first==second,"full natural "+key+" report and event times repeat exactly across FPS/2x/pause")
		current_reports.append({"formation":key,"report":first})
	var old: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/board-trial-runtime/board-d007-comparisons.json"))
	var file := FileAccess.open("/tmp/board-ranged-20261008-comparisons.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"config":Config.VERSION,"ranged_rule":"ranged-pursuit-d20261008-001",
		"baseline_d007":old.comparisons,"comparisons":current_reports,"failures":failures},"\t"))
	file = FileAccess.open("/tmp/board-ranged-20261008-natural-traces.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"ranged_rule":"ranged-pursuit-d20261008-001","public_schedules":[[30,1],[120,2]],
		"paused_repeat":true,"cases":cases,"failures":failures}))
	print("BOARD_RANGED_NATURAL natural=5 failures=",failures)
	quit(1 if failures else 0)
