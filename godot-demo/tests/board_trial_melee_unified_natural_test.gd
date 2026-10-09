extends "res://tests/board_trial_ranged_natural_test.gd"
## Current six natural cases; original fixed-anchor reports remain immutable.
## Historical D-20261008-002 report runner. Current stepwise production uses
## board_trial_stepwise_natural_test.gd; do not label its results with this old tag.
const DELAY := [Vector2i(2,4),Vector2i(1,5),Vector2i(2,2),Vector2i(3,4),Vector2i(1,4),Vector2i(2,6)]
var active_key := ""
var pursuit := {}

func load_case(game, key: String) -> void:
	active_key=key
	pursuit[key]={"moves":[],"max_column":-1,"max_anchor_distance":0}
	if key=="video_delay":
		game.deployment.clear()
		for index in Config.FRIENDS.size(): game.deployment[Config.FRIENDS[index]]=DELAY[index]-Vector2i.ONE
		game._reset_roster()
	else: super.load_case(game,key)

func observe(game) -> void:
	var old: Dictionary=game.previous[1]
	var monk: Dictionary=game._record("guard_monk")
	if game._active(monk):
		pursuit[active_key].max_column=maxi(pursuit[active_key].max_column,monk.cell.x+1)
		pursuit[active_key].max_anchor_distance=maxi(pursuit[active_key].max_anchor_distance,Config.distance(monk.cell,monk.anchor))
		if not monk.move.is_empty() and (old.move.is_empty() or old.move.to!=cell_data(monk.move.to)):
			pursuit[active_key].moves.append({"time":game.elapsed,"from":cell_data(monk.move.from),"to":cell_data(monk.move.to),"target":monk.target})
	super.observe(game) # All 12 brains, every STEP segment/foot/range/reservation checks.

func run() -> void:
	for key in ["A","B","C","video","video_d007","video_delay"]:
		var first:=natural(key,30,1,true,false)
		var first_pursuit: Dictionary=pursuit[key].duplicate(true)
		var repeated:=natural(key,120,2,false,true)
		check(first==repeated and first_pursuit==pursuit[key],"entire natural report/guard movements repeat under FPS/2x/pause "+key)
		cases[key].guard_pursuit=first_pursuit
		current_reports.append({"formation":key,"report":first})
		if key=="video_delay":
			check(not first_pursuit.moves.is_empty() and is_equal_approx(first_pursuit.moves[0].time,Config.STEP),"same recorded initial deployment now starts guard pursuit on the first actual simulation STEP")
			check(first_pursuit.max_anchor_distance>2,"new recorded deployment really pursues beyond its historical anchor radius")
	var old: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/board-trial-runtime/board-ranged-20261008-comparisons.json"))
	var baseline: Array=old.comparisons.duplicate(true)
	var delay_path: String="/tmp/board-melee-unified-20261008-old-delay.json"
	var old_delay: Dictionary={}
	if FileAccess.file_exists(delay_path): old_delay=JSON.parse_string(FileAccess.get_file_as_string(delay_path))
	else:
		var committed := "res://tests/board-trial-runtime/board-melee-unified-20261008-comparisons.json"
		if FileAccess.file_exists(committed): old_delay=JSON.parse_string(FileAccess.get_file_as_string(committed)).old_delay_provenance
	check(not old_delay.is_empty() and old_delay.get("failures",1)==0,"old sixth case has a verified complete original-source baseline, not diagnosis snapshot")
	if not old_delay.is_empty(): baseline.append({"formation":"video_delay","report":old_delay.report})
	var file:=FileAccess.open("/tmp/board-melee-unified-20261008-comparisons.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"config":Config.VERSION,"melee_rule":"melee-unified-d20261008-002","baseline_ranged_d001":baseline,
		"old_delay_provenance":old_delay,"comparisons":current_reports,"failures":failures},"\t"))
	file=FileAccess.open("/tmp/board-melee-unified-20261008-natural-traces.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"melee_rule":"melee-unified-d20261008-002","public_schedules":[[30,1],[120,2]],"paused_repeat":true,"cases":cases,"failures":failures}))
	print("BOARD_MELEE_UNIFIED_NATURAL natural=6 failures=",failures)
	quit(1 if failures else 0)
