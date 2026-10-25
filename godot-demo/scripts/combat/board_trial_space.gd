extends RefCounted
const Config = preload("res://scripts/data/board_trial_config.gd")
const DIRECTIONS := [Vector2i(-1,0),Vector2i(0,-1),Vector2i(0,1),Vector2i(1,0)]

static func _valid(cell: Vector2i, valid_cell: Callable) -> bool:
	return bool(valid_cell.call(cell)) if valid_cell.is_valid() else Config.valid(cell)

static func path(start: Vector2i, goal: Vector2i, reach: int, blocked: Callable, anchor := Vector2i(-1,-1), radius := -1, valid_cell: Callable = Callable()) -> Array[Vector2i]:
	if not _valid(start,valid_cell) or not _valid(goal,valid_cell): return []
	var queue: Array[Vector2i] = [start]
	var parent := {start:start}
	var cursor := 0
	while cursor<queue.size():
		var cell := queue[cursor]
		cursor += 1
		if Config.distance(cell,goal)<=reach:
			var result: Array[Vector2i] = [cell]
			while cell!=start:
				cell = parent[cell]
				result.push_front(cell)
			return result
		for direction in DIRECTIONS:
			var next: Vector2i = cell+direction
			if not _valid(next,valid_cell) or parent.has(next): continue
			if radius>=0 and Config.distance(anchor,next)>radius: continue
			if blocked.call(next): continue
			parent[next] = cell
			queue.append(next)
	return []
