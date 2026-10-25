extends RefCounted
## Full-board approach search; only the selected first segment is ever committed.
const Config = preload("res://scripts/data/board_trial_config.gd")
const Space = preload("res://scripts/combat/board_trial_space.gd")
const NEVER := 1000000000

static func releases(game, actor: Dictionary, target: Dictionary) -> Dictionary:
	var result := {}
	for other in game.actors:
		if other.id==actor.id or not game._active(other): continue
		if other.move.is_empty(): result[other.cell]=NEVER
		else:
			# Only an actual in-flight SOURCE has a known release. Its destination
			# remains occupied after landing; do not predict a subsequent departure.
			result[other.cell]=maxi(1,int(ceil((other.move.duration-other.move.time-0.00000001)/Config.STEP)))
			result[other.move.to]=NEVER
	# Attack positions surround the CURRENT target. Never plan into its cell.
	result[target.cell]=NEVER
	return result

static func route(first: Vector2i, actor: Dictionary, target: Dictionary, occupied: Dictionary, valid_cell: Callable = Callable()) -> Dictionary:
	var release: int=occupied.get(first,0)
	if release>=NEVER or not Space._valid(first,valid_cell): return {}
	var duration: int=int(round(actor.walk/Config.STEP))
	var times := {first:release+duration}
	var parents := {first:actor.cell}
	var frontier: Array[Vector2i]=[first]
	while not frontier.is_empty():
		var best := 0
		for index in range(1,frontier.size()):
			if int(times[frontier[index]])<int(times[frontier[best]]): best=index
		var cell: Vector2i=frontier[best]
		frontier.remove_at(best)
		var time: int=times[cell]
		if cell!=target.cell and Config.distance(cell,target.cell)<=actor.reach:
			var path: Array[Vector2i]=[cell]
			while cell!=actor.cell:
				cell=parents[cell]
				path.push_front(cell)
			return {"cell":first,"cost":time,"path":path,"wait_ticks":release,"wait":{}}
		for direction in Space.DIRECTIONS:
			var next: Vector2i=cell+direction
			if not Space._valid(next,valid_cell) or next==actor.cell: continue
			var available: int=occupied.get(next,0)
			if available>=NEVER: continue
			# Dual-end locking means the destination must be free when the
			# segment STARTS, not merely when its 0.5-second interpolation ends.
			var arrival: int=maxi(time,available)+duration
			if times.has(next) and int(times[next])<=arrival: continue
			times[next]=arrival
			parents[next]=cell
			if not frontier.has(next): frontier.append(next)
	return {}

static func candidates(game, actor: Dictionary, target: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	if not game._active(actor) or not game._active(target) or actor.friendly==target.friendly: return result
	if Config.distance(actor.cell,target.cell)<=actor.reach: return result
	var occupied := releases(game,actor,target)
	var best := NEVER
	for direction in Space.DIRECTIONS:
		var option := route(actor.cell+direction,actor,target,occupied,game.valid_cell)
		if option.is_empty(): continue
		if option.cost<best:
			best=option.cost
			result.clear()
		if option.cost!=best: continue
		if option.wait_ticks>0:
			var holder: Dictionary=game._occupant(option.cell,actor.id)
			if not holder.is_empty() and not holder.move.is_empty() and holder.cell==option.cell:
				option.wait={"blocker":holder.id,"serial":holder.step_serial}
		result.append(option)
	result.sort_custom(func(a,b):
		var ad: int=Config.distance(a.cell,target.cell)
		var bd: int=Config.distance(b.cell,target.cell)
		if ad!=bd: return ad<bd
		var ah: bool=a.cell==actor.step_hint
		var bh: bool=b.cell==actor.step_hint
		if ah!=bh: return ah
		return Space.DIRECTIONS.find(a.cell-actor.cell)<Space.DIRECTIONS.find(b.cell-actor.cell))
	return result
