extends RefCounted
## Only guard_monk uses this simple locked-target brain; no global AI changes.
const Config = preload("res://scripts/data/board_trial_config.gd")
const RULE := "monk-lock-d004"

static func release(actor: Dictionary) -> void:
	actor.target = ""
	actor.route = []
	actor.route_goal = Vector2i(-1,-1)
	actor.blocked = false
	actor.blocked_elapsed = 0.0
	actor.progress_time = -1.0

static func route_valid(game, actor: Dictionary, target: Dictionary) -> bool:
	var route: Array = actor.route
	if route.is_empty() or route[0]!=actor.cell or actor.route_goal!=target.cell: return false
	if Config.distance(route.back(),target.cell)>actor.reach: return false
	for index in range(route.size()):
		var cell: Vector2i = route[index]
		if not Config.valid(cell) or Config.distance(actor.anchor,cell)>Config.LEASH: return false
		if index>0 and (Config.distance(route[index-1],cell)!=1 or not game._occupant(cell,actor.id).is_empty()): return false
	return true

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
		actor.blocked_elapsed = 0.0
		actor.blocked = false
		actor.mode = "接敌 → "+target.id
		game._attack(actor,target) # Original cooldown, not SCAN-quantized.
		return
	# Count every sim step needing movement with no actual progress, including
	# SCAN wait; do not charge a step in which the root just finished moving.
	if valid and actor.progress_time!=game.elapsed: actor.blocked_elapsed += delta
	# Invalid target releases immediately at a segment boundary, not half a cell.
	if actor.think>0.00000001 and (actor.target.is_empty() or (valid and actor.blocked_elapsed+0.00000001<Config.LONG_BLOCK_SECONDS)): return
	actor.think = Config.SCAN
	if not valid: release(actor)
	if valid:
		# Trim only completed movement; retain a still-valid old route over BFS ties.
		if actor.route.size()>1 and actor.route[1]==actor.cell: actor.route.pop_front()
		if not route_valid(game,actor,target):
			actor.route = game._path(actor,target.cell,actor.reach)
			actor.route_goal = target.cell
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
		elif actor.route.size()>1: game._move(actor,actor.route[1])
		return
	game._return(actor) # Every later scan may interrupt return at a grid boundary.
