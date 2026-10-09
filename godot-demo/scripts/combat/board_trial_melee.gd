extends RefCounted
## Board-only shared pursuit and activity handoff for guard, wolves and boars.
const Config = preload("res://scripts/data/board_trial_config.gd")
const RULE := "melee-stepwise-20261009"

static func applies(actor: Dictionary) -> bool:
	return (actor.friendly and actor.key=="guard_monk") or (not actor.friendly and actor.key in ["wolf","boar"])

static func release(actor: Dictionary) -> void:
	actor.target = ""
	actor.route = []
	actor.route_goal = Vector2i(-1,-1)
	actor.blocked = false
	actor.blocked_elapsed = 0.0
	actor.progress_time = -1.0
	actor.handoff = {}
	actor.step_age = -1.0
	actor.step_wait = {}
	actor.step_wait_reason = ""
	actor.step_target = ""
	actor.step_hint = Vector2i(-1,-1)

static func route_valid(game, actor: Dictionary, target: Dictionary) -> bool:
	var route: Array = actor.route
	if route.is_empty() or route[0]!=actor.cell: return false
	if Config.distance(route.back(),target.cell)>actor.reach: return false
	for index in range(route.size()):
		var cell: Vector2i = route[index]
		if not Config.valid(cell): return false
		if index>0 and (Config.distance(route[index-1],cell)!=1 or not game._occupant(cell,actor.id).is_empty()): return false
	return true

static func boundary_wait(game, actor: Dictionary, target: Dictionary) -> bool:
	var mutual: bool = applies(target) and game._active(target) and target.target==actor.id
	if not actor.handoff.is_empty():
		var observed: Dictionary = actor.handoff
		if not mutual or observed.target!=target.id:
			actor.handoff = {}
			actor.think = 0.0
		elif target.move_completed>=observed.segment or target.move.is_empty():
			# A durable completion survives the other brain starting a new move in
			# this very tick. A cleared activity also cannot be waited on forever.
			# Consume once; do not bind that subsequent activity.
			actor.handoff = {}
			actor.think = 0.0
			return false
		else:
			actor.mode = "格段交接 → "+target.id
			return true
	if mutual and Config.distance(actor.cell,target.cell)==2 and not target.move.is_empty():
		actor.handoff = {"target":target.id,"segment":target.move_serial}
		actor.mode = "格段交接 → "+target.id
		return true
	return false

static func tick(game, actor: Dictionary) -> void:
	if not actor.move.is_empty() or actor.node.presentation.pose=="basic_attack": return
	var target: Dictionary = game._record(actor.target)
	var valid: bool = game._target_legal(actor,target)
	if valid and Config.distance(actor.cell,target.cell)<=actor.reach:
		actor.handoff = {}
		actor.mode = "接敌 → "+target.id
		game._attack(actor,target)
		return
	# An actually adjacent ally is a legal attack NOW, not a prediction. Keep a
	# hittable old lock above; otherwise stable ID picks among current neighbors.
	var neighbor := {}
	for candidate in game.actors:
		if candidate.friendly==actor.friendly or not game._active(candidate): continue
		if Config.distance(actor.cell,candidate.cell)>actor.reach: continue
		if neighbor.is_empty() or candidate.id<neighbor.id: neighbor = candidate
	if not neighbor.is_empty():
		release(actor) # Never changes the original attack cooldown.
		actor.target = neighbor.id
		actor.mode = "接敌 → "+neighbor.id
		game._attack(actor,neighbor)
		return
	if not valid and not actor.handoff.is_empty():
		actor.handoff = {}
		actor.think = 0.0
	elif not actor.handoff.is_empty():
		# Completion/cancellation is an activity event, not a throttled SCAN.
		# Consume the handoff in dispatch, after this batch's target intents.
		var observed: Dictionary=actor.handoff
		if target.target!=actor.id or target.move.is_empty() or target.move_completed>=observed.segment:
			actor.think=0.0
	if actor.think>0.00000001: return
	actor.think = Config.SCAN
	# Compare BOTH targets using fresh reachable attack costs, never a stale
	# cached cost or straight-line distance. Equal cost preserves the old lock.
	var fresh: Array = game._pursuit_path(actor,target) if valid else []
	var candidate: Dictionary = game._best_target(actor)
	var candidate_path: Array = game._pursuit_path(actor,candidate) if not candidate.is_empty() else []
	var changed: bool = not valid or (not candidate_path.is_empty() and candidate_path.size()<fresh.size())
	if changed:
		release(actor)
		target = candidate
		actor.target = target.get("id","")
		fresh = candidate_path
	if target.is_empty():
		actor.mode = "无可达目标"
		return
	actor.mode = "接敌 → "+target.id
	if Config.distance(actor.cell,target.cell)<=actor.reach:
		game._attack(actor,target)
		return
	# The combat target is persistent; an old attack endpoint is not a command.
	actor.route = []
	actor.route_goal = Vector2i(-1,-1)
	game._request_step(actor)
