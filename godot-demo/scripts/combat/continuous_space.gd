extends RefCounted
## Continuous terrain union. The old calibrated rectangles only describe LAND;
## there are no actor cells, cell occupancy or snapped command destinations.
## A private 24px graph finds detours; visibility smoothing removes stair steps.
const Map = preload("res://scripts/data/escort_map.gd")
const Rules = preload("res://scripts/data/free_escort_rules.gd")
const STEP := 24.0
var land: Array[Rect2] = []
var edges: Array = []
var graph := AStar2D.new()
var ids := {}
var points := PackedVector2Array()

func _init() -> void:
	for row in range(Map.SPANS.size()):
		for span in Map.SPANS[row]:
			var a := Map.rect(Vector2i(row,span[0]))
			var b := Map.rect(Vector2i(row,span[1]))
			land.append(Rect2(a.position,Vector2(b.end.x-a.position.x,a.size.y)))
	for cell in Map.cells():
		var area := Map.rect(cell)
		var tl := area.position
		var br := area.end
		var tr := Vector2(br.x,tl.y)
		var bl := Vector2(tl.x,br.y)
		for side in [[Vector2i(-1,0),tl,tr],[Vector2i(1,0),bl,br],[Vector2i(0,-1),tl,bl],[Vector2i(0,1),tr,br]]:
			if not Map.valid(cell+side[0]):
				edges.append({"a":side[1],"b":side[2],"bounds":Rect2(side[1],side[2]-side[1]).abs().grow(Rules.BODY_RADIUS)})
	for y in range(6,36):
		for x in range(12,70):
			var point := Vector2(x,y)*STEP
			if not valid(point): continue
			var id := points.size()
			ids[Vector2i(x,y)] = id
			points.append(point)
			graph.add_point(id,point)
	for key in ids:
		for offset in [Vector2i(1,0),Vector2i(0,1),Vector2i(1,1),Vector2i(-1,1)]:
			if ids.has(key+offset) and clear(points[ids[key]],points[ids[key+offset]]):
				graph.connect_points(ids[key],ids[key+offset])

func on_land(point: Vector2) -> bool:
	for area in land:
		if area.has_point(point): return true
	return false

func valid(point: Vector2) -> bool:
	if not on_land(point): return false
	for edge in edges:
		if edge.bounds.has_point(point) and point.distance_squared_to(Geometry2D.get_closest_point_to_segment(point,edge.a,edge.b)) < Rules.BODY_RADIUS*Rules.BODY_RADIUS: return false
	return true

func clear(a: Vector2, b: Vector2, obstacles: Array = []) -> bool:
	if not valid(a) or not valid(b): return false
	# Exact swept disc vs external shore edges: sampled visibility can miss a
	# subpixel corner then strand the actor when its next movement tick sees it.
	var bounds := Rect2(a,b-a).abs().grow(0.01)
	for edge in edges:
		if not bounds.intersects(edge.bounds): continue
		if Geometry2D.segment_intersects_segment(a,b,edge.a,edge.b) != null: return false
		for pair in [[edge.a,a,b],[edge.b,a,b],[a,edge.a,edge.b],[b,edge.a,edge.b]]:
			if pair[0].distance_squared_to(Geometry2D.get_closest_point_to_segment(pair[0],pair[1],pair[2])) < Rules.BODY_RADIUS*Rules.BODY_RADIUS: return false
	for obstacle in obstacles:
		var closest := Geometry2D.get_closest_point_to_segment(obstacle,a,b)
		if closest.distance_to(obstacle) < Rules.OPPONENT_GAP: return false
	return true

func path(a: Vector2, b: Vector2, obstacles: Array = []) -> PackedVector2Array:
	if not valid(a) or not valid(b): return PackedVector2Array()
	if clear(a,b,obstacles): return PackedVector2Array([b])
	for id in range(points.size()):
		var blocked := false
		for obstacle in obstacles:
			if points[id].distance_to(obstacle) < Rules.OPPONENT_GAP+STEP*0.5:
				blocked = true
				break
		graph.set_point_disabled(id,blocked)
	var start := _anchor(a,obstacles)
	var finish := _anchor(b,obstacles)
	if start < 0 or finish < 0: return PackedVector2Array()
	var raw := graph.get_point_path(start,finish)
	if raw.is_empty(): return raw
	raw.append(b)
	var result := PackedVector2Array()
	var cursor := a
	var index := 0
	while index < raw.size():
		var farthest := index
		if not clear(cursor,raw[index],obstacles): return PackedVector2Array()
		while farthest+1 < raw.size() and clear(cursor,raw[farthest+1],obstacles): farthest += 1
		result.append(raw[farthest])
		cursor = raw[farthest]
		index = farthest+1
	return result

func _anchor(point: Vector2, obstacles: Array) -> int:
	var best := -1
	var distance := INF
	for id in range(points.size()):
		if graph.is_point_disabled(id): continue
		var next := point.distance_squared_to(points[id])
		if next < distance and clear(point,points[id],obstacles):
			distance = next
			best = id
	return best
