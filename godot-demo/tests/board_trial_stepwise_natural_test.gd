extends "res://tests/board_trial_uniform_movement_test.gd"
## Seven unmodified formations, all twelve real production brains, separate from fixtures.
var stepwise_cases := {}

class StepwiseTraceGame extends "res://scripts/board_trial.gd":
	var observer := Callable()
	var previous := []
	var previous_key := ""
	var states := []
	var observed_steps := 0
	var issued_steps := []
	var wait_events := []
	var last_segments := {}
	var last_waits := {}
	func coordinates(cell: Vector2i) -> Array: return [cell.x+1,cell.y+1]
	func _move(actor: Dictionary, next: Vector2i) -> bool:
		var from: Vector2i=actor.cell
		var target: Dictionary=_record(actor.target)
		var before_distance: int=Config.distance(from,target.cell) if not target.is_empty() else -1
		var after_distance: int=Config.distance(next,target.cell) if not target.is_empty() else -1
		var previous_segment: Dictionary=last_segments.get(actor.id,{})
		var issued: bool=super._move(actor,next)
		if issued:
			var reverse: bool=not previous_segment.is_empty() and previous_segment.from==next and previous_segment.to==from
			issued_steps.append({"time":elapsed,"id":actor.id,"from":coordinates(from),"to":coordinates(next),"target":actor.target,
				"target_cell":coordinates(target.cell) if not target.is_empty() else [],"serial":actor.step_serial,
				"reverses_previous_segment":reverse,"increases_current_target_distance":before_distance>=0 and after_distance>before_distance})
			last_segments[actor.id]={"from":from,"to":next}
		return issued
	func _tick(delta: float) -> void:
		super._tick(delta)
		for actor in actors:
			var value: Dictionary={"reason":actor.step_wait_reason,"dependency":actor.step_wait.duplicate(true)}
			var previous_value: Dictionary=last_waits.get(actor.id,{"reason":"","dependency":{}})
			if value!=previous_value:
				wait_events.append({"time":elapsed,"id":actor.id,"cell":coordinates(actor.cell),"target":actor.target,
					"age":actor.step_age,"reason":value.reason,"dependency":value.dependency})
			last_waits[actor.id]=value
		if observer.is_valid(): observer.call(self)

func fresh():
	var game=StepwiseTraceGame.new()
	game.enemy_profile="legacy"
	root.add_child(game)
	game.set_process(false)
	game.audio_feedback.enabled=false
	assert_uniform_roster(game,"stepwise fresh")
	return game

func request_snapshot(game) -> Array:
	var values := []
	for actor in game.actors:
		values.append({"id":actor.id,"age":actor.step_age,"hint":[actor.step_hint.x,actor.step_hint.y],
			"reason":actor.step_wait_reason,"dependency":actor.step_wait.duplicate(true),"serial":actor.step_serial,"completed":actor.step_completed,"retarget":actor.step_retarget})
	return values

func stepwise_natural(key: String, fps: int, sim_speed: int, pause_once: bool) -> Dictionary:
	var game=fresh()
	load_case(game,key)
	check(game.start_battle(),"stepwise natural starts with twelve real AI and original HP/damage/CD "+key)
	game.previous=sample(game)
	game.previous_key=signature(game.previous)
	game.states.append({"time":0.0,"actors":game.previous})
	game.observer=Callable(self,"observe")
	game.speed=sim_speed
	var paused_once := false
	while game.phase==game.Phase.BATTLE and game.elapsed<120:
		game.step(1.0/fps)
		if pause_once and not paused_once and game.elapsed>=1.0:
			var before: Dictionary=game.report().duplicate(true)
			var actors_before:=sample(game)
			var requests_before:=request_snapshot(game)
			var count: int=game.observed_steps
			var move_count: int=game.issued_steps.size()
			var wait_count: int=game.wait_events.size()
			game.paused=true
			game.step(5)
			check(game.report()==before and sample(game)==actors_before and request_snapshot(game)==requests_before and count==game.observed_steps and move_count==game.issued_steps.size() and wait_count==game.wait_events.size(),"natural pause freezes full AI/request/age/activity/movement/combat clocks "+key)
			game.paused=false
			paused_once=true
	var report: Dictionary=game.report().duplicate(true)
	check(game.phase==game.Phase.RESULT and game.result_count==1,"natural stepwise battle reaches one real result, never timeout victory "+key)
	var coverage := {}
	var reversals := {}
	var away_steps := {}
	for event in game.issued_steps:
		check(event.id in UNIFORM_MOVERS,"only ten permitted mobile actors emit natural grid movement")
		coverage[event.id]=coverage.get(event.id,0)+1
		if event.reverses_previous_segment: reversals[event.id]=reversals.get(event.id,0)+1
		if event.increases_current_target_distance: away_steps[event.id]=away_steps.get(event.id,0)+1
	var wait_reasons := {}
	for event in game.wait_events:
		if not event.reason.is_empty(): wait_reasons[event.reason]=wait_reasons.get(event.reason,0)+1
	var result := {"report":report,"steps":game.observed_steps,"issued_steps":game.issued_steps.duplicate(true),"wait_events":game.wait_events.duplicate(true),
		"movement_coverage":coverage,"reverse_counts":reversals,"target_distance_increase_counts":away_steps,"wait_reason_counts":wait_reasons,
		"completed_uniform_segments":completed_segments[key].duplicate(true)}
	var deployment: Dictionary=game.start_deployment.duplicate()
	game.retry()
	assert_uniform_roster(game,"stepwise natural retry "+key)
	check(game.deployment==deployment and game.elapsed==0 and not game.paused and game.speed==1,"natural retry restores original deployment/clock/speed "+key)
	check(game.actors.all(func(actor): return actor.move.is_empty() and actor.target.is_empty() and actor.route.is_empty() and actor.handoff.is_empty() and actor.cooldown==0 and actor.step_age<0 and actor.step_wait.is_empty() and actor.step_wait_reason.is_empty() and actor.step_serial==0 and actor.step_completed==0 and not actor.step_retarget),"natural retry clears legacy plus universal step request/activity state "+key)
	check(game.combat.strikes.is_empty() and game.combat.missiles.is_empty(),"natural retry clears actual pending strikes/missiles "+key)
	game.free()
	return result

func run() -> void:
	check(Config.VERSION=="board-v5-bear" and Config.version_for("legacy")=="board-v5-legacy","legacy natural stepwise suite requires the current profile-aware version")
	for key in CASE_KEYS:
		var first:=stepwise_natural(key,30,1,false)
		var repeated:=stepwise_natural(key,120,2,true)
		check(first==repeated,"entire report/issued movement/wait reasons/segment timelines repeat across FPS/2x/pause "+key)
		check(not first.issued_steps.is_empty(),"natural formation contains real issued segments "+key)
		stepwise_cases[key]={"kind":"natural_all_12_unmodified_production_AI","coordinate_base":1,"steps":first.steps,
			"movement_coverage":first.movement_coverage,"reverse_counts":first.reverse_counts,"target_distance_increase_counts":first.target_distance_increase_counts,
			"wait_reason_counts":first.wait_reason_counts,"issued_steps":first.issued_steps,"wait_events":first.wait_events,
			"completed_uniform_segment_count":first.completed_uniform_segments.size(),"repeat_equal":first==repeated}
		comparisons.append({"formation":key,"report":first.report})
	check(comparisons.size()==7 and stepwise_cases.size()==7,"all seven complete natural cases ran, no early success")
	var file:=FileAccess.open("/tmp/board-step-target-20261009-natural.json",FileAccess.WRITE)
	check(file!=null,"independent natural stepwise evidence opens")
	if file!=null: file.store_string(JSON.stringify({"config":Config.version_for("legacy"),"enemy_profile":"legacy","scope":"legacy_twelve_actor_technical_comparison_not_default_bear_balance","public_schedules":[[30,1],[120,2]],"paused_repeat":true,
		"every_STEP_invariants":true,"no_historical_result_assertions":true,"comparisons":comparisons,"cases":stepwise_cases,"failures":failures},"\t"))
	print("BOARD_STEPWISE_NATURAL natural=",comparisons.size()," failures=",failures)
	quit(1 if failures else 0)
