extends RefCounted
## Board-only melee activity handoff. Guard lock rules and enemy selection stay distinct.
const Config = preload("res://scripts/data/board_trial_config.gd")
const RULE := "melee-pursuit-d007"

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

static func route_valid(game, actor: Dictionary, target: Dictionary) -> bool:
	var route: Array = actor.route
	if route.is_empty() or route[0]!=actor.cell: return false
	if Config.distance(route.back(),target.cell)>actor.reach: return false
	for index in range(route.size()):
		var cell: Vector2i = route[index]
		if not Config.valid(cell): return false
		if actor.friendly and Config.distance(actor.anchor,cell)>Config.LEASH: return false
		if index>0 and (Config.distance(route[index-1],cell)!=1 or not game._occupant(cell,actor.id).is_empty()): return false
	return true

static func route_to(game, actor: Dictionary, target: Dictionary) -> void:
	if actor.route.size()>1 and actor.route[1]==actor.cell: actor.route.pop_front()
	if not route_valid(game,actor,target):
		actor.route = game._path(actor,target.cell,actor.reach)
		actor.route_goal = target.cell # Planning snapshot only, NOT a validity oracle.

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

static func tick_enemy(game, actor: Dictionary) -> void:
	if not actor.move.is_empty() or actor.node.presentation.pose=="basic_attack": return
	var target: Dictionary = game._record(actor.target)
	var valid: bool = game._target_legal(actor,target) # Preserve enemy unreachable retargeting.
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
	var waiting: bool = valid and boundary_wait(game,actor,target)
	if not valid and not actor.handoff.is_empty():
		actor.handoff = {}
		actor.think = 0.0
	if actor.think>0.00000001: return
	actor.think = Config.SCAN
	# Compare BOTH targets using fresh reachable attack costs, never a stale
	# cached cost or straight-line distance. Equal cost preserves the old lock.
	var fresh: Array = game._path(actor,target.cell,actor.reach) if valid else []
	var candidate: Dictionary = game._best_target(actor)
	var candidate_path: Array = game._path(actor,candidate.cell,actor.reach) if not candidate.is_empty() else []
	var changed: bool = not valid or (not candidate_path.is_empty() and candidate_path.size()<fresh.size())
	if changed:
		release(actor)
		target = candidate
		actor.target = target.get("id","")
		fresh = candidate_path
		waiting = false
	if target.is_empty():
		actor.mode = "无可达目标"
		return
	actor.mode = "接敌 → "+target.id
	if Config.distance(actor.cell,target.cell)<=actor.reach:
		game._attack(actor,target)
		return
	# Same-target shortening must not cancel an observed activity; only a real
	# target change binds the new target's current activity. Completion consumed
	# above cannot be rebound to its next activity in this same simulation step.
	if changed: waiting = boundary_wait(game,actor,target)
	if actor.route.size()>1 and actor.route[1]==actor.cell: actor.route.pop_front()
	if not route_valid(game,actor,target) or (not fresh.is_empty() and fresh.size()<actor.route.size()):
		actor.route = fresh
		actor.route_goal = target.cell
	if waiting:
		actor.mode = "格段交接 → "+target.id
		return
	if actor.route.size()>1: game._move(actor,actor.route[1])

static func tick(game, actor: Dictionary, delta: float) -> void:
	# Neither a moving segment nor an attack segment can change its target.
	if not actor.move.is_empty(): return
	if actor.node.presentation.pose=="basic_attack":
		actor.blocked_elapsed = 0.0
		actor.blocked = false
		return
	var target: Dictionary = game._record(actor.target)
	var valid: bool = game._target_legal(actor,target)
	if valid and Config.distance(actor.cell,target.cell)<=actor.reach:
		actor.handoff = {}
		actor.blocked_elapsed = 0.0
		actor.blocked = false
		actor.mode = "接敌 → "+target.id
		game._attack(actor,target) # Original cooldown, not SCAN-quantized.
		return
	if not valid and not actor.handoff.is_empty():
		actor.handoff = {}
		actor.think = 0.0
	if valid and boundary_wait(game,actor,target): return # NOT long obstruction.
	# Count every sim step needing movement with no actual progress, including
	# SCAN wait; do not charge a step in which the root just finished moving.
	if valid and actor.progress_time!=game.elapsed: actor.blocked_elapsed += delta
	# Invalid target releases immediately at a segment boundary, not half a cell.
	if actor.think>0.00000001 and (actor.target.is_empty() or (valid and actor.blocked_elapsed+0.00000001<Config.LONG_BLOCK_SECONDS)): return
	actor.think = Config.SCAN
	if not valid: release(actor)
	if valid:
		# Trim only completed movement; retain a still-valid old route over BFS ties.
		route_to(game,actor,target)
		if actor.route.is_empty():
			if not actor.blocked:
				actor.blocked = true
			actor.mode = "接敌受阻 → "+target.id
			if actor.blocked_elapsed+0.00000001<Config.LONG_BLOCK_SECONDS: return
			# The path was freshly recomputed and is STILL empty after 2 sim seconds.
			release(actor)
			target = {}
		else:
			actor.mode = "接敌 → "+target.id
			actor.blocked = false
			if actor.route.size()>1: game._move(actor,actor.route[1])
			return
	# Death/range/long-block release: choose from CURRENT cell, not the anchor.
	target = game._best_target(actor)
	if not target.is_empty():
		actor.target = target.id
		actor.mode = "接敌 → "+target.id
		actor.route = game._path(actor,target.cell,actor.reach)
		actor.route_goal = target.cell
		if Config.distance(actor.cell,target.cell)<=actor.reach: game._attack(actor,target)
		elif not boundary_wait(game,actor,target) and actor.route.size()>1: game._move(actor,actor.route[1])
		return
	game._return(actor) # Every later scan may interrupt return at a grid boundary.
