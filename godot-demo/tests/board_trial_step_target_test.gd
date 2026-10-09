extends "res://tests/board_trial_stepwise_test.gd"
## Isolated real-segment target fixtures. Opponent relocation is explicit state
## setup, not natural twelve-AI movement or balance evidence.
const TARGET_ROLES := ["wild_hunter","sparrow_spirit","foxfire_imp","E5","E6"]
const TARGET_STATS := {
	"wild_hunter":[145.0,22.0,0.85],"sparrow_spirit":[90.0,17.0,0.92],
	"foxfire_imp":[96.0,20.0,1.25],"E5":[52.0,7.0,0.95],"E6":[52.0,7.0,0.95]}
var target_evidence := []

func target_point(cell: Vector2i, flipped: bool) -> Vector2i:
	return Vector2i(Config.COLS-1-cell.x,cell.y) if flipped else cell

func target_place(ctx: Dictionary, actor: Dictionary, cell: Vector2i) -> void:
	ctx.game._set_cell(actor,target_point(cell,ctx.flipped))

func target_context(role: String, flipped: bool, barrier := false) -> Dictionary:
	var friendly: bool=not role.begins_with("E")
	var near_id: String="E2" if friendly else "wild_hunter"
	var blocker_id: String="herbal_spirit_child" if friendly else "E1"
	var live: Array=[near_id]
	if barrier: live.append(blocker_id)
	var ctx: Dictionary=context(role,live)
	ctx.role=role
	ctx.flipped=flipped
	ctx.old=ctx.target
	ctx.near=ctx.game._record(near_id)
	ctx.blocker=ctx.game._record(blocker_id) if barrier else {}
	target_place(ctx,ctx.game._record("tangseng"),Vector2i(0,6))
	target_place(ctx,ctx.source,Vector2i(3,3))
	target_place(ctx,ctx.old,Vector2i(8,3))
	target_place(ctx,ctx.near,Vector2i(11,6))
	ctx.source.target=ctx.old.id
	ctx.source.step_target=ctx.old.id
	ctx.game.driven_ids=[role]
	check(not ctx.source.step_retarget,"fresh ranged actor has no invented landing reevaluation "+role)
	return ctx

func at_landing_cost(ctx: Dictionary, target: Dictionary, destination: Vector2i) -> int:
	if not ctx.game._active(target): return -1
	var copy: Dictionary=ctx.source.duplicate(false)
	copy.cell=destination
	copy.move={}
	var path: Array=ctx.game._pursuit_path(copy,target)
	return path.size()-1 if not path.is_empty() else -1

func target_ticks(ctx: Dictionary, count: int) -> void:
	for tick in range(count):
		ctx.game.step(Config.STEP)
		ownership(ctx.game) # Live source/destination uniqueness and Tang/healer hold.

func close_target_case(ctx: Dictionary, label: String, facts: Dictionary) -> void:
	ownership(ctx.game)
	var actor: Dictionary=ctx.source
	var stats: Array=TARGET_STATS[ctx.role]
	check(actor.hp_max==stats[0] and actor.damage==stats[1] and actor.interval==stats[2] and actor.reach==3,"landing target refresh preserves original HP/damage/attack interval/range "+ctx.role)
	check(is_equal_approx(actor.walk,0.5) and is_equal_approx(actor.node.move_interval,0.5),"landing target refresh preserves actual half-second segments "+ctx.role)
	target_evidence.append({"kind":"isolated_real_segment_one_driven_brain","case":label,"role":ctx.role,"mirrored":ctx.flipped,
		"time":ctx.game.elapsed,"cell":cell_data(actor.cell),"target":actor.target,"step_retarget":actor.step_retarget,
		"cooldown":actor.cooldown,"completed":actor.step_completed,"facts":facts})
	ctx.game.free()

func landing_case(role: String, flipped: bool, kind: String) -> void:
	var ctx:=target_context(role,flipped,kind=="obstacle")
	# Make equal/range cases genuinely distinguish lock retention from fresh ID
	# selection: the newcomer has a smaller ID than the old valid target.
	if kind in ["equal","range"]:
		var original_old: Dictionary=ctx.old
		ctx.old=ctx.near
		ctx.near=original_old
		ctx.source.target=ctx.old.id
		ctx.source.step_target=ctx.old.id
		check(ctx.near.id<ctx.old.id,"equal-cost fixture newcomer really wins a fresh stable-ID tie")
	var from := Vector2i(3,3)
	var to := Vector2i(4,3)
	var old_cell := Vector2i(7,3) if kind=="range" else Vector2i(8,3)
	var near_cell := Vector2i(6,5) if kind=="equal" else (Vector2i(4,4) if kind=="range" else Vector2i(4,5))
	if kind=="obstacle":
		from=Vector2i(1,0)
		to=Vector2i(0,0)
		old_cell=Vector2i(5,0)
		near_cell=Vector2i(0,4)
		target_place(ctx,ctx.blocker,Vector2i(0,1))
	target_place(ctx,ctx.source,from)
	target_place(ctx,ctx.old,old_cell)
	target_place(ctx,ctx.near,Vector2i(11,6))
	var issued_to: Vector2i=target_point(to,flipped)
	var original_target: String=ctx.old.id
	var original_interval: float=ctx.source.interval
	check(ctx.game._move(ctx.source,issued_to),"fixture issues one actual controller movement "+role+" "+kind)
	check(ctx.source.step_serial==1 and ctx.source.step_completed==0 and not ctx.source.step_retarget,"starting movement is not a landing/retarget event "+role)
	target_ticks(ctx,30)
	check(ctx.source.cell==target_point(from,flipped) and not ctx.source.move.is_empty() and is_equal_approx(ctx.source.move.time,0.25),"actor really reaches half segment without committing its cell "+role)
	target_place(ctx,ctx.near,near_cell) # Explicit newcomer state appears mid-segment.
	if kind=="death": ctx.old.node.take_damage(ctx.old.hp_max)
	var old_cost: int=at_landing_cost(ctx,ctx.old,issued_to)
	var new_cost: int=at_landing_cost(ctx,ctx.near,issued_to)
	if kind=="strict":
		check(old_cost>new_cost and new_cost==0 and ctx.game._target_legal(ctx.source,ctx.old),"old target remains alive/reachable while newcomer has a strictly cheaper reachable attack position")
	elif kind=="equal": check(old_cost==new_cost and old_cost>0,"equal fixture compares reachable attack-route cost, not merely target distance")
	elif kind=="range": check(old_cost==0 and new_cost==0,"old actual range position is already zero-cost despite geometrically closer newcomer")
	elif kind=="obstacle":
		check(Config.distance(issued_to,ctx.near.cell)<Config.distance(issued_to,ctx.old.cell) and old_cost==2 and new_cost==3,"nearer straight-line target really requires a longer reachable route around a body")
	else: check(old_cost==-1 and new_cost==0,"dead target releases to a real living in-range alternative")
	target_ticks(ctx,29)
	check(ctx.source.cell==target_point(from,flipped) and ctx.source.target==original_target and not ctx.source.move.is_empty() and ctx.source.move.to==issued_to and not ctx.source.step_retarget,"near/dead target cannot change lock or reverse the unfinished original segment "+role+" "+kind)
	target_ticks(ctx,1)
	check(ctx.source.cell==issued_to and ctx.source.step_completed==1 and not ctx.source.step_retarget,"real landing marks and safely consumes exactly its pending ranged target refresh "+role)
	var expected_target: String=ctx.near.id if kind in ["strict","death"] else original_target
	check(ctx.source.target==expected_target,"landing consumes strictly-cheaper/equal/range/obstacle/dead target rule "+role+" "+kind)
	check(is_equal_approx(ctx.source.cooldown,100.0-0.5) and ctx.source.interval==original_interval,"retarget/hold does not restart cooldown or convert attack interval into move duration "+role)
	var facts := {"from":cell_data(target_point(from,flipped)),"landing":cell_data(issued_to),"old_id":original_target,"new_id":ctx.near.id,
		"old_reachable_cost":old_cost,"new_reachable_cost":new_cost,"landing_selected":ctx.source.target,"incomplete_segment_kept_old":true}
	if kind=="range":
		check(ctx.source.move.is_empty(),"in-range current target holds the cell while original cooldown is pending "+role)
		ctx.source.cooldown=0
		target_ticks(ctx,1)
		check(ctx.source.node.presentation.pose=="basic_attack" and ctx.source.move.is_empty() and ctx.source.target==original_target and is_equal_approx(ctx.source.cooldown,original_interval),"actual ready attack starts on retained in-range target with original cooldown "+role)
		check(ctx.game.metrics.first_engagement.get(role,{}).get("target","")==original_target,"retained attack uses actual old target, not a display-only lock "+role)
		facts.actual_attack_target=original_target
		# Explicit pending-state injection during a REAL attack checks the guard;
		# it is not claimed to be a naturally overlapping landing/attack event.
		ctx.source.step_retarget=true
		var attacks: int=ctx.game.metrics.attack_times.get(role,[]).size()
		target_ticks(ctx,1)
		check(ctx.source.node.presentation.pose=="basic_attack" and ctx.source.step_retarget and ctx.source.target==original_target and ctx.game.metrics.attack_times.get(role,[]).size()==attacks,"actual attack segment defers target-flag consumption without retarget/new attack "+role)
		check(not ctx.game._move(ctx.source,issued_to+Vector2i.UP),"even a free adjacent cell cannot interrupt the real attack activity "+role)
		while ctx.source.step_retarget and ctx.game.elapsed<3.0: target_ticks(ctx,1)
		check(not ctx.source.step_retarget and ctx.source.target==original_target and ctx.source.cell==issued_to,"pending target decision is consumed only after the actual attack safely ends "+role)
		facts.explicit_pending_flag_during_real_attack_deferred=true
	if kind=="death":
		ctx.game.retry()
		check(ctx.game.actors.all(func(actor): return not actor.step_retarget and actor.step_serial==0 and actor.step_completed==0 and actor.target.is_empty() and actor.cooldown==0),"retry rebuilds all actors without pending landing target flags")
		ctx.source=ctx.game._record(role)
		facts.retry_cleared=true
	close_target_case(ctx,kind,facts)

func idle_case(role: String, flipped: bool) -> void:
	var ctx:=target_context(role,flipped)
	target_place(ctx,ctx.near,Vector2i(4,5))
	ctx.source.think=0
	check(ctx.source.step_completed==0 and not ctx.source.step_retarget,"idle fixture has no completed movement event")
	var old_id: String=ctx.source.target
	ctx.game._brain(ctx.source,Config.STEP)
	check(ctx.source.target==old_id and ctx.source.step_completed==0 and not ctx.source.step_retarget,"ordinary idle SCAN does not invent a landing and steal a still-legal lock "+role)
	check(is_equal_approx(ctx.source.cooldown,100.0-Config.STEP),"idle unchanged targeting retains the original attack countdown "+role)
	close_target_case(ctx,"idle_without_landing",{"kept":old_id,"newcomer":ctx.near.id,"no_landing":true})

func run() -> void:
	check(Config.VERSION=="board-v4-step-target","target suite requires the new actual production version")
	var probe=fresh()
	check(probe.RANGED_RULE=="ranged-step-target-20261009" and probe.actors.all(func(actor): return not actor.step_retarget),"new ranged rule tag and default pending flags are real")
	probe.free()
	for role in TARGET_ROLES:
		for flipped in [false,true]:
			for kind in ["strict","equal","range","obstacle","death"]: landing_case(role,flipped,kind)
			idle_case(role,flipped)
	check(target_evidence.size()==60,"all five ranged actors mirrored through six target boundary cases completed")
	var file:=FileAccess.open("/tmp/board-step-target-20261009-boundaries.json",FileAccess.WRITE)
	check(file!=null,"independent landing target evidence opens")
	if file!=null: file.store_string(JSON.stringify({"config":Config.VERSION,"rule":"ranged-step-target-20261009","coordinate_base":1,
		"kind":"isolated_real_movement_one_driven_brain_not_natural_combat","cases":target_evidence,"failures":failures},"\t"))
	print("BOARD_STEP_TARGET_BOUNDARIES cases=",target_evidence.size()," failures=",failures)
	quit(1 if failures else 0)
