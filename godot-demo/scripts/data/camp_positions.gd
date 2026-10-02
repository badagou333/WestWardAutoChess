extends RefCounted
## Per-camp coordinate ledger, separate from hero ownership and population.
## Removing/merging a hero never manufactures another freely placeable seat.
const PICK_RADIUS := 24.0
var points := {} # stable numeric seat -> exact world position

func reset() -> void:
	points.clear()

func capture(slots: Array, heroes: Array) -> void:
	reset()
	for index in range(slots.size()):
		var hero = slots[index]
		if is_instance_valid(hero) and hero in heroes and hero.board_row >= 0:
			record(index,hero.position)

func record(index: int, point: Vector2) -> void:
	points[index] = point

func at_point(point: Vector2, occupied: Array = []) -> int:
	var nearest := -1
	var distance := INF
	for index in points:
		var gap: float = point.distance_to(points[index])
		if gap > PICK_RADIUS: continue
		# End-of-wave friendly transit may leave overlapping saved positions.
		# A filled marker must not swallow another empty marker at the same point.
		var score := gap+(1000.0 if index in occupied else 0.0)
		if score < distance:
			nearest = index
			distance = score
	return nearest

func may_add(population: int) -> bool:
	return points.size() < population

func next_index(maximum: int) -> int:
	for index in range(maximum):
		if not points.has(index): return index
	return -1

func near_reserved(point: Vector2, gap: float) -> bool:
	for reserved in points.values():
		if point.distance_to(reserved) < gap: return true
	return false
