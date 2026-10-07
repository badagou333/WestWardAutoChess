extends "res://tests/board_trial_melee_handoff_test.gd"
## Five natural deployments, exact public frame repeats and four-type live pairs.
const VIDEO_D007 := [Vector2i(2,4),Vector2i(4,4),Vector2i(2,3),Vector2i(3,4),Vector2i(1,4),Vector2i(2,5)]
var natural_evidence := {}
var current_reports := []

class TraceGame extends "res://scripts/board_trial.gd":
	var step_observer := Callable()
	var previous_sample := []
	var previous_key := ""
	var states := []
	var decisions := []
	var observed_steps := 0
	func cells(path: Array) -> Array:
		var values := []
		for cell in path: values.append([cell.x+1,cell.y+1])
		return values
	func decision(actor: Dictionary) -> Dictionary:
		var target: Dictionary = _record(actor.target)
		var remaining: Array = actor.route.duplicate()
		if remaining.size()>1 and remaining[1]==actor.cell: remaining.pop_front()
		var copy: Dictionary = actor.duplicate()
		copy.route=remaining
		var costs := {}
		for candidate in actors:
			if candidate.friendly==actor.friendly or not _active(candidate): continue
			var path := _path(actor,candidate.cell,actor.reach)
			costs[candidate.id]={"cost":path.size()-1 if not path.is_empty() else -1,"distance":Config.distance(actor.cell,candidate.cell)}
		return {"target":actor.target,"cell":[actor.cell.x+1,actor.cell.y+1],"move_serial":actor.move_serial,
			"remaining":cells(remaining),"remaining_cost":remaining.size()-1 if not remaining.is_empty() else -1,
			"route_valid":not target.is_empty() and Melee.route_valid(self,copy,target),"costs":costs,
			"handoff":actor.handoff.duplicate(),"cooldown":actor.cooldown,"think":actor.think,
			"attacks":metrics.attack_times.get(actor.id,[]).size()}
	func _brain(actor: Dictionary, delta: float) -> void:
		if actor.friendly or not Melee.applies(actor) or not actor.move.is_empty() or actor.node.presentation.pose=="basic_attack":
			super._brain(actor,delta)
			return
		var before := decision(actor)
		super._brain(actor,delta)
		var after := decision(actor)
		var target: Dictionary=_record(before.target)
		var ranged_before: bool=not target.is_empty() and _active(target) and Config.distance(actor.cell,target.cell)<=actor.reach
		var changed: bool=before.target!=after.target
		var route_changed: bool=before.remaining!=after.remaining
		if changed or route_changed or before.move_serial!=after.move_serial or before.attacks!=after.attacks or before.handoff!=after.handoff or (before.think<=delta+0.00000001 and not ranged_before):
			var reason := "keep_current_attack_position" if ranged_before else "keep_valid_route_or_wait"
			if changed:
				var cost: int=before.costs.get(after.target,{"cost":-1}).cost
				reason="neighbor_contact" if cost==0 else "strict_shorter_target_or_invalid_reselect"
			elif route_changed:
				reason="strict_shorter_same_target_route" if before.route_valid and after.remaining_cost<before.remaining_cost else "invalid_route_replan"
			decisions.append({"time":elapsed,"id":actor.id,"reason":reason,"before":before,"after":after})
	func _tick(delta: float) -> void:
		super._tick(delta)
		if step_observer.is_valid(): step_observer.call(self)

func fresh():
	var game=TraceGame.new()
	root.add_child(game)
	game.set_process(false)
	game.audio_feedback.enabled=false
	return game

func load_case(game, key: String) -> void:
	if key in ["video","video_d007"]:
		var deployment_cells: Array=VIDEO_D007 if key=="video_d007" else VIDEO
		game.deployment.clear()
		for index in Config.FRIENDS.size(): game.deployment[Config.FRIENDS[index]]=deployment_cells[index]-Vector2i.ONE
		game._reset_roster()
	else: game.load_formation(key)

func observe(game) -> void:
	var current := sample(game)
	verify_step(game,game.previous_sample,current)
	var key := signature(current)
	if key!=game.previous_key: game.states.append({"time":game.elapsed,"actors":current})
	game.previous_sample=current
	game.previous_key=key
	game.observed_steps+=1

func live_case(key: String, fps: int, speed: int, record: bool, pause_once: bool) -> Dictionary:
	var game=fresh()
	load_case(game,key)
	check(game.start_battle(),"natural "+key+" starts with unchanged stats/enemies and all 12 real brains")
	game.previous_sample=sample(game)
	game.previous_key=signature(game.previous_sample)
	game.states.append({"time":0.0,"actors":game.previous_sample})
	game.step_observer=Callable(self,"observe")
	game.speed=speed
	var paused_once := false
	while game.phase==game.Phase.BATTLE and game.elapsed<120:
		game.step(1.0/fps)
		if pause_once and not paused_once and game.elapsed>=2.0:
			var before: Dictionary=game.report().duplicate(true)
			var actors_before:=sample(game)
			var count: int=game.observed_steps
			game.paused=true
			game.step(10)
			check(game.report()==before and sample(game)==actors_before and count==game.observed_steps,"natural pause freezes every route/wait/clock and combat event")
			game.paused=false
			paused_once=true
	var report: Dictionary=game.report().duplicate(true)
	check(game.phase==game.Phase.RESULT and game.result_count==1,"natural "+key+" reaches its real single result, no timeout/persistent circulation")
	if key=="video":
		var first: Dictionary=game.metrics.first_engagement.get("guard_monk",{})
		check(first.get("target","")=="E3" and is_equal_approx(first.get("time",0),169*Config.STEP),"old video retains original monk/E3 grid handoff and first real contact")
	if key=="video_d007":
		var reselected := false
		for event in game.decisions:
			if event.id=="E4" and event.before.target=="guard_monk" and event.after.target=="foxfire_imp":
				reselected=true
				check(event.before.costs.foxfire_imp.cost<event.before.costs.guard_monk.cost,"new video E4 really selects a cheaper reachable target")
		check(reselected and game.metrics.attack_times.get("E4",[]).size()>0,"new video E4 leaves wasted monk pursuit and executes actual attacks")
	if record:
		natural_evidence[key]={"kind":"natural_all_12_AI","coordinate_base":1,"steps":game.observed_steps,
			"trace_encoding":"all discrete state changes, continuous move/cooldown sampled at each event; every STEP invariants checked",
			"states":game.states,"enemy_decisions":game.decisions,"report":report}
	game.retry()
	check(game.actors.all(func(actor): return actor.target.is_empty() and actor.route.is_empty() and actor.handoff.is_empty() and actor.move.is_empty() and actor.move_serial==0 and actor.cooldown==0),"natural retry clears target/route/handoff without stale pursuit")
	game.free()
	return report

func old_new_video_facts() -> Dictionary:
	var path := "/tmp/qa-e4-20261007.7b6ub7/live-trace.json"
	if not FileAccess.file_exists(path):
		# Cross-machine reruns use the committed compact diagnosis, not ephemeral
		# attachments or the original 8 MiB per-STEP temporary recording.
		var saved := "res://tests/board-trial-runtime/board-d007-enemy-traces.json"
		if FileAccess.file_exists(saved): return JSON.parse_string(FileAccess.get_file_as_string(saved)).old_new_video_facts
		return {}
	var old: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	var facts := []
	for event in old.e4_decisions:
		if not event.before_brain.actor.move.is_empty(): continue
		var cell := Vector2i(int(event.before_brain.actor.cell[0]),int(event.before_brain.actor.cell[1]))
		if cell not in [Vector2i(5,5),Vector2i(5,4),Vector2i(6,2),Vector2i(5,2)]: continue
		var raw: Array=event.before_brain.actor.route.duplicate(true)
		if raw.size()>1 and raw[1]==event.before_brain.actor.cell: raw.pop_front()
		facts.append({"time":event.time,"cell":event.before_brain.actor.cell,"target":event.before_brain.actor.target,
			"remaining":raw,"remaining_cost":raw.size()-1,"fresh_candidates":event.before_brain.candidates,
			"occupancy":event.before_brain.monk_attack_cell_occupancy,"issued_move":event.after_brain.move})
	var landing_count := 0
	for step in old.every_step_actors:
		for actor in step.actors:
			if actor.id=="E4" and int(actor.cell[0])==4 and int(actor.cell[1])==2: landing_count+=1
	return {"source_baseline":old.baseline,"all_AI_live":old.all_AI_live,"initial":old.initial,
		"old_report":old.report,"old_E4_moves":old.e4_moves,"old_key_decisions":facts,
		"old_steps":old.every_step_actors.size(),"old_ownership_failures":old.ownership_failures,
		"old_attack_attempts":old.e4_attack_attempts.size(),"old_4_2_landing_count":landing_count}

func run() -> void:
	for key in ["A","B","C","video","video_d007"]:
		var first:=live_case(key,30,1,true,false)
		var second:=live_case(key,120,2,false,true)
		check(first==second,"full natural "+key+" reports and event times exactly repeat across public FPS/2x/pause")
		current_reports.append({"formation":key,"report":first})
	live_pairs() # Same 32 mirrored/unequal-speed/opposite-order live AI fixtures.
	var previous: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/board-trial-runtime/board-d006-comparisons.json"))
	var facts:=old_new_video_facts()
	var file:=FileAccess.open("/tmp/board-d007-comparisons.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"config":Config.VERSION,"baseline_d006":previous,"new_video_baseline":facts.get("old_report",{}),"comparisons":current_reports,"failures":failures},"\t"))
	file=FileAccess.open("/tmp/board-d007-enemy-traces.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"rule":Melee.RULE,"old_new_video_facts":facts,"cases":natural_evidence,"live_pair_cases":evidence,"failures":failures}))
	print("BOARD_ENEMY_PURSUIT_NATURAL natural=5 live_pairs=32 failures=",failures)
	quit(1 if failures else 0)
