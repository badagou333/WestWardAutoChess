extends "res://tests/board_trial_ai_test.gd"
## Isolated state/queue fixtures, NOT natural combat or balance conclusions.
const Stepwise = preload("res://scripts/combat/board_trial_stepwise.gd")
const MOVERS := ["guard_monk","wild_hunter","sparrow_spirit","foxfire_imp","E1","E2","E3","E4","E5","E6"]
var evidence := []

class BoundaryGame extends "res://scripts/board_trial.gd":
	var driven_ids := []
	func _brain(actor: Dictionary, delta: float) -> void:
		if actor.id in driven_ids: super._brain(actor,delta)
		# Other brains are deliberately held only in the labelled boundary fixtures.

func context(role := "guard_monk", extra: Array = []) -> Dictionary:
	var game=BoundaryGame.new()
	root.add_child(game)
	game.set_process(false)
	game.audio_feedback.enabled=false
	check(game.start_battle(),"stepwise isolated fixture starts")
	var source: Dictionary=game._record(role)
	var target: Dictionary=game._record("E1" if source.friendly else "guard_monk")
	var live: Array=[role,target.id,"tangseng"]
	live.append_array(extra)
	isolate(game,live)
	game._set_cell(game._record("tangseng"),Vector2i(0,6))
	game._set_cell(source,Vector2i(3,3))
	game._set_cell(target,Vector2i(8,3))
	source.target=target.id
	source.step_target=target.id
	source.cooldown=100.0 # Explicit cooldown isolation; natural runs never do this.
	return {"game":game,"source":source,"target":target}

func dispatch(game, actors: Array) -> void:
	game.collecting_steps=true
	for actor in actors: game._request_step(actor)
	game.collecting_steps=false
	game._dispatch_steps()

func cell_data(cell: Vector2i) -> Array: return [cell.x+1,cell.y+1]

func close_case(ctx: Dictionary, label: String) -> void:
	ownership(ctx.game)
	var actor: Dictionary=ctx.source
	evidence.append({"kind":"isolated_state_or_request_fixture","case":label,"id":actor.id,"cell":cell_data(actor.cell),
		"next":cell_data(actor.move.to) if not actor.move.is_empty() else [],"target":actor.target,"age":actor.step_age,
		"wait_reason":actor.step_wait_reason,"wait":actor.step_wait.duplicate(true),"serial":actor.step_serial})
	ctx.game.free()

func all_mobile_and_static() -> void:
	for id in MOVERS:
		var ctx:=context(id)
		var choices: Array=Stepwise.candidates(ctx.game,ctx.source,ctx.target)
		check(not choices.is_empty() and choices[0].cell==Vector2i(4,3),"all ten mobile roles plan their actual range toward the same current target "+id)
		dispatch(ctx.game,[ctx.source])
		check(not ctx.source.move.is_empty() and ctx.source.move.to==Vector2i(4,3) and is_equal_approx(ctx.source.move.duration,Config.MOVE_SECONDS_PER_CELL),"all ten mobile roles commit one real uniform segment "+id)
		close_case(ctx,"mobile_"+id)
	var ctx:=context("guard_monk",["herbal_spirit_child"])
	var healer: Dictionary=ctx.game._record("herbal_spirit_child")
	ctx.game._set_cell(healer,Vector2i(0,5))
	for id in ["tangseng","herbal_spirit_child"]:
		var actor: Dictionary=ctx.game._record(id)
		actor.target=ctx.target.id
		dispatch(ctx.game,[actor])
		check(actor.move.is_empty() and actor.cell==actor.anchor and actor.step_serial==0,"Tang/healer cannot enter mobile step dispatch "+id)
	close_case(ctx,"stationary_roles")

func fresh_attack_position() -> void:
	var ctx:=context()
	ctx.game._set_cell(ctx.source,Vector2i(6,1))
	ctx.game._set_cell(ctx.target,Vector2i(3,0))
	ctx.source.route=[Vector2i(6,1),Vector2i(6,2),Vector2i(5,2),Vector2i(4,2),Vector2i(3,2),Vector2i(3,1)]
	ctx.source.route_goal=ctx.target.cell
	ctx.source.step_hint=Vector2i(6,2)
	check(Config.distance(ctx.source.route.back(),ctx.target.cell)==ctx.source.reach,"old endpoint is still a legal attack position")
	var choices: Array=Stepwise.candidates(ctx.game,ctx.source,ctx.target)
	check(not choices.is_empty() and choices[0].cost==int(round(3*Config.MOVE_SECONDS_PER_CELL/Config.STEP)),"planner compares all current attack positions rather than insisting on the old endpoint")
	dispatch(ctx.game,[ctx.source])
	check(not ctx.source.move.is_empty() and ctx.source.move.to in [Vector2i(5,1),Vector2i(6,0)],"strictly shorter current attack position replaces a still-valid old detour")
	close_case(ctx,"old_attack_position_valid_but_longer")
	ctx=context()
	ctx.game._set_cell(ctx.source,Vector2i(2,2))
	ctx.game._set_cell(ctx.target,Vector2i(5,2))
	ctx.game.driven_ids=[ctx.source.id]
	check(ctx.game._move(ctx.source,Vector2i(3,2)),"range-boundary fixture begins a real segment")
	ctx.game.step(0.25)
	var held: Dictionary=ctx.source.move.duplicate(true)
	ctx.game._set_cell(ctx.target,Vector2i(4,2)) # Explicit target-state fixture.
	ctx.game._brain(ctx.source,Config.STEP)
	check(ctx.source.move==held and ctx.source.cell==Vector2i(2,2),"new range opportunity cannot interrupt an in-flight half segment")
	ctx.game.step(0.25)
	check(ctx.source.cell==Vector2i(3,2) and ctx.source.move.is_empty(),"real landing at current range immediately holds instead of following the old route")
	var cooldown: float=ctx.source.cooldown
	ctx.source.cooldown=0
	ctx.source.think=Config.SCAN
	ctx.game._brain(ctx.source,Config.STEP)
	check(ctx.source.node.presentation.pose=="basic_attack" and is_equal_approx(ctx.source.cooldown,ctx.source.interval),"actual in-range attack keeps the original attack clock, not the movement cadence")
	check(cooldown>99.0,"isolated range wait did not reset the existing cooldown")
	close_case(ctx,"current_range_after_safe_landing")

func complete_route_not_greedy() -> void:
	var ctx:=context("guard_monk",["herbal_spirit_child"])
	ctx.game._set_cell(ctx.source,Vector2i(4,2))
	ctx.game._set_cell(ctx.target,Vector2i(7,2))
	ctx.game._set_cell(ctx.game._record("herbal_spirit_child"),Vector2i(6,2))
	ctx.source.step_hint=Vector2i(4,1)
	var choices: Array=Stepwise.candidates(ctx.game,ctx.source,ctx.target)
	var cells: Array=choices.map(func(choice): return choice.cell)
	check(Vector2i(5,2) in cells and Vector2i(4,1) in cells,"original right/up comparison contains genuinely equal full-route first steps, not an empty-board shortcut")
	check(choices.all(func(choice): return choice.cost==choices[0].cost),"only globally equal minimum full-route costs are returned")
	check(choices[0].cell==Vector2i(5,2),"closer-to-current-target first step precedes equal old vertical hint")
	dispatch(ctx.game,[ctx.source])
	check(ctx.source.move.to==Vector2i(5,2),"equal-route orientation preference is actually executed")
	close_case(ctx,"equal_full_routes_prefer_target_progress")
	ctx=context()
	ctx.game._set_cell(ctx.source,Vector2i(2,2))
	ctx.game._set_cell(ctx.target,Vector2i(4,4))
	ctx.source.step_hint=Vector2i(2,3)
	choices=Stepwise.candidates(ctx.game,ctx.source,ctx.target)
	check(choices.size()>=2 and choices[0].cell==Vector2i(2,3),"equal full cost and equal target distance preserve a valid equivalent old hint")
	var repeated: Array=Stepwise.candidates(ctx.game,ctx.source,ctx.target)
	ctx.game.actors.reverse()
	check(choices==repeated and choices==Stepwise.candidates(ctx.game,ctx.source,ctx.target),"equivalent candidate ordering is stable and not actor-array order")
	close_case(ctx,"equivalent_hint_and_stable_order")
	ctx=context()
	ctx.game._set_cell(ctx.source,Vector2i(0,0))
	ctx.game._set_cell(ctx.target,Vector2i(2,0))
	ctx.game._set_cell(ctx.game._record("tangseng"),Vector2i(1,0))
	choices=Stepwise.candidates(ctx.game,ctx.source,ctx.target)
	check(not choices.is_empty() and choices[0].cell==Vector2i(0,1),"necessary full-route detour can increase immediate target distance")
	dispatch(ctx.game,[ctx.source])
	check(ctx.source.move.to==Vector2i(0,1),"planner does not replace shortest complete paths with greedy target-vector motion")
	close_case(ctx,"necessary_obstacle_detour")

func simultaneous_claims() -> void:
	for reversed in [false,true]:
		for older_guard in [false,true]:
			var ctx:=context()
			ctx.game._set_cell(ctx.source,Vector2i(2,2))
			ctx.game._set_cell(ctx.target,Vector2i(4,2))
			ctx.target.target=ctx.source.id
			ctx.target.step_target=ctx.source.id
			ctx.game.elapsed=1.0 # Explicit request-age fixture, not natural time.
			if older_guard:
				ctx.source.step_age=0.0
				ctx.target.step_age=0.5
			var queue: Array=[ctx.target,ctx.source] if reversed else [ctx.source,ctx.target]
			dispatch(ctx.game,queue)
			var winner: Dictionary=ctx.source if older_guard else ctx.target # E1 wins equal ages by stable ID.
			var loser: Dictionary=ctx.target if older_guard else ctx.source
			check(not winner.move.is_empty() and winner.move.to==Vector2i(3,2) and loser.move.is_empty(),"same-tick single destination uses oldest request then ID independently of collection order")
			check(loser.step_age>=0 and not loser.step_wait_reason.is_empty(),"losing request remains observable and ages rather than silently disappearing")
			var age: float=loser.step_age
			ctx.game.collecting_steps=true
			ctx.game._request_step(loser)
			check(loser.step_age==age and loser.move.is_empty(),"renewing a denied request does not reset age or bypass snapshot collection")
			ctx.game.collecting_steps=false
			ctx.game._dispatch_steps()
			close_case(ctx,"same_cell_order_%s_older_%s" % [reversed,older_guard])
	var ctx:=context("guard_monk",["E2","sparrow_spirit"])
	ctx.game._set_cell(ctx.source,Vector2i(2,2))
	ctx.game._set_cell(ctx.target,Vector2i(5,3))
	var other: Dictionary=ctx.game._record("E2")
	ctx.game._set_cell(other,Vector2i(3,1))
	ctx.game._set_cell(ctx.game._record("sparrow_spirit"),Vector2i(3,5))
	other.target="sparrow_spirit"
	other.step_target="sparrow_spirit"
	ctx.source.step_hint=Vector2i(3,2)
	ctx.game.elapsed=1.0
	other.step_age=0.0
	ctx.source.step_age=0.5
	dispatch(ctx.game,[ctx.source,other])
	check(other.move.to==Vector2i(3,2) and ctx.source.move.to==Vector2i(2,3),"snapshot contention tries an equal-cost free alternative before waiting")
	close_case(ctx,"equal_cost_conflict_alternative")
	ctx=context()
	ctx.game._set_cell(ctx.source,Vector2i(2,2))
	ctx.game._set_cell(ctx.target,Vector2i(3,2))
	ctx.target.target=ctx.source.id
	dispatch(ctx.game,[ctx.source,ctx.target])
	check(ctx.source.move.is_empty() and ctx.target.move.is_empty(),"opposite adjacent contact cannot create a swap or movement while already in actual range")
	check(not ctx.game._move(ctx.source,ctx.target.cell) and not ctx.game._move(ctx.target,ctx.source.cell),"execution gate independently refuses both opposing occupied source cells")
	close_case(ctx,"opposite_sources_do_not_swap")

func activity_waits() -> void:
	for kind in ["completion","death","destination"]:
		var ctx:=context("guard_monk",["wild_hunter"])
		var blocker: Dictionary=ctx.game._record("wild_hunter")
		ctx.game._set_cell(ctx.source,Vector2i(6,0))
		ctx.game._set_cell(ctx.target,Vector2i(3,0))
		ctx.game._set_cell(blocker,Vector2i(5,1) if kind=="destination" else Vector2i(5,0))
		check(ctx.game._move(blocker,Vector2i(5,0) if kind=="destination" else Vector2i(5,1)),"finite-wait fixture begins a real blocker segment")
		blocker.move.time=blocker.move.duration-Config.STEP # Labelled near-completion state fixture.
		blocker.node.position=Config.center(blocker.move.from).lerp(Config.center(blocker.move.to),blocker.move.time/blocker.move.duration)
		var serial: int=blocker.step_serial
		var choices: Array=Stepwise.candidates(ctx.game,ctx.source,ctx.target)
		if kind=="destination":
			check(choices.all(func(choice): return choice.cell!=Vector2i(5,0) and choice.wait.is_empty()),"a soon-arriving destination is never assumed to be a soon-free source")
			dispatch(ctx.game,[ctx.source])
			check(ctx.source.move.is_empty() or ctx.source.move.to!=Vector2i(5,0),"actual step cannot enter another actor's reserved destination")
		else:
			check(not choices.is_empty() and choices[0].cell==Vector2i(5,0) and choices[0].wait=={"blocker":blocker.id,"serial":serial} and choices[0].wait_ticks>0,"shorter finite wait binds the real in-flight source and its universal activity serial")
			dispatch(ctx.game,[ctx.source])
			check(ctx.source.move.is_empty() and ctx.source.step_wait=={"blocker":blocker.id,"serial":serial},"finite wait cannot release the occupied source early")
			var held: Dictionary=ctx.source.step_wait.duplicate(true)
			var age: float=ctx.source.step_age
			ctx.game.paused=true
			ctx.game.step(2)
			check(ctx.source.step_wait==held and ctx.source.step_age==age and blocker.step_completed<serial,"pause freezes waiting dependency/age and real blocker activity")
			ctx.game.paused=false
			if kind=="death": blocker.node.take_damage(blocker.hp_max)
			ctx.game.driven_ids=[ctx.source.id]
			while ctx.source.move.is_empty() and ctx.game.elapsed<Config.SCAN+2*Config.STEP: ctx.game.step(Config.STEP)
			check(not ctx.source.move.is_empty() and ctx.source.move.to==Vector2i(5,0) and ctx.source.step_wait.is_empty(),"completion/death releases finite source wait without a full-route waiting loop")
			if kind=="completion": check(blocker.step_completed==serial,"universal blocker completion is persisted for ranged actors too")
		close_case(ctx,"finite_activity_"+kind)
	var ctx:=context("guard_monk",["wild_hunter","herbal_spirit_child"])
	ctx.game._set_cell(ctx.source,Vector2i(0,0))
	ctx.game._set_cell(ctx.target,Vector2i(3,0))
	ctx.game._set_cell(ctx.game._record("wild_hunter"),Vector2i(1,0))
	ctx.game._set_cell(ctx.game._record("herbal_spirit_child"),Vector2i(0,1))
	check(Stepwise.candidates(ctx.game,ctx.source,ctx.target).is_empty(),"permanent sealed corner has no invented future vacancy")
	dispatch(ctx.game,[ctx.source])
	check(ctx.source.move.is_empty() and ctx.source.step_wait.is_empty(),"no-path waiting never manufactures an activity dependency")
	ctx.game._record("wild_hunter").node.take_damage(10000)
	dispatch(ctx.game,[ctx.source])
	check(not ctx.source.move.is_empty() and ctx.source.move.to==Vector2i(1,0),"real death frees a sealed path for the next request")
	ctx.game.retry()
	check(ctx.game.actors.all(func(actor): return actor.step_age<0 and actor.step_wait.is_empty() and actor.step_wait_reason.is_empty() and actor.step_serial==0 and actor.step_completed==0),"retry removes every old request/finite wait/universal activity")
	ctx.source=ctx.game._record("guard_monk")
	ctx.target=ctx.game._record("E1")
	close_case(ctx,"sealed_corner_death_and_retry")

func run() -> void:
	check(Config.VERSION=="board-v3-stepwise","stepwise tests require the actual new production version")
	all_mobile_and_static()
	fresh_attack_position()
	complete_route_not_greedy()
	simultaneous_claims()
	activity_waits()
	check(evidence.size()==26,"all twenty-six isolated stepwise cases completed")
	var file:=FileAccess.open("/tmp/board-stepwise-20261009-boundaries.json",FileAccess.WRITE)
	check(file!=null,"independent stepwise boundary evidence opens")
	if file!=null: file.store_string(JSON.stringify({"config":Config.VERSION,"kind":"isolated_state_and_queue_fixtures_not_natural_combat","coordinate_base":1,"cases":evidence,"failures":failures},"\t"))
	print("BOARD_STEPWISE_BOUNDARIES cases=",evidence.size()," failures=",failures)
	quit(1 if failures else 0)
