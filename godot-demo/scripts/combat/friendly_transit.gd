extends RefCounted
## Friendly transit owns its last legal stand and next legal landing. Intermediate
## allied cells are traversable, but never become a cancelled/stationary endpoint.
var flights := {}
var game

func _init(host): game = host

func stop_blocked(cell: Vector2i, actor) -> bool:
	if cell == game._escort_cell(): return true
	for hero in game.heroes:
		if hero == actor or hero.battle_dead or not hero.active_in_battle: continue
		if flights.has(hero):
			if cell == flights[hero].origin or cell == flights[hero].landing: return true
		elif hero.battle_cell == cell: return true
	for hero in game.orders:
		if hero != actor and game.orders[hero] == cell: return true
	return hard_blocked(cell, actor)

func hard_blocked(cell: Vector2i, actor) -> bool:
	if not game._valid_cell(cell) or cell == game._escort_cell(): return true
	for enemy in game.enemies:
		if not enemy.dead and enemy.battle_cell == cell: return true
	for move in game.moving:
		if move.node != actor and (move.node == game.escort or move.node is JourneyEnemy):
			if game._screen_to_cell(move.from) == cell or game._screen_to_cell(move.to) == cell: return true
	return false

func path(actor, target: Vector2i) -> Array[Vector2i]:
	var start: Vector2i = flights[actor].landing if flights.has(actor) else actor.battle_cell
	var frontier: Array[Vector2i] = [start]
	var parents := {start:start}
	while not frontier.is_empty():
		var cell: Vector2i = frontier.pop_front()
		if cell == target:
			var result: Array[Vector2i] = [cell]
			while cell != start:
				cell = parents[cell]
				result.push_front(cell)
			return result
		for direction in [Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT,Vector2i.UP]:
			var next: Vector2i = cell+direction
			if parents.has(next) or hard_blocked(next,actor): continue
			parents[next] = cell
			frontier.append(next)
	return []

func begin(actor, route: Array[Vector2i]) -> bool:
	if flights.has(actor): return false
	for index in range(1,route.size()):
		if stop_blocked(route[index],actor): continue
		var points: Array[Vector2i] = []
		points.assign(route.slice(0,index+1))
		flights[actor] = {"origin":route[0],"landing":route[index],"path":points,"time":0.0,"duration":maxf(0.20,actor.move_interval)*index}
		actor.presentation.face(game._cell_center(route[1])-actor.position)
		actor.presentation.move_to(Vector2.ZERO)
		return true
	return false

func blocks_enemy(cell: Vector2i) -> bool:
	for flight in flights.values():
		if cell in flight.path: return true
	return false

func tick(delta: float) -> void:
	for actor in flights.keys():
		if not is_instance_valid(actor) or actor.battle_dead:
			flights.erase(actor)
			continue
		var flight: Dictionary = flights[actor]
		flight.time += delta
		var progress: float = minf(1.0,flight.time/flight.duration)*(flight.path.size()-1)
		var index := mini(int(progress),flight.path.size()-2)
		var from: Vector2 = game._cell_center(flight.path[index])
		var to: Vector2 = game._cell_center(flight.path[index+1])
		actor.position = from.lerp(to,progress-index)
		actor.battle_cell = game._screen_to_cell(actor.position)
		if actor.presentation.pose == "idle": actor.presentation.move_to(Vector2.ZERO)
		actor.presentation.face(to-from)
		if flight.time+0.0000001 >= flight.duration:
			actor.battle_cell = flight.landing
			actor.position = game._cell_center(flight.landing)
			flights.erase(actor)

func clear() -> void: flights.clear()
