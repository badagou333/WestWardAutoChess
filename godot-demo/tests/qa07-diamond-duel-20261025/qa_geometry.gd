extends SceneTree
## 07 independent geometry verification for D-20261018-002.
## Re-derives the legal mask from the declared 1344x576 rectangular arena and
## the 192x96 diamond tile, without calling Board.valid() to decide expectations.
## It also re-checks picking, shared-edge ownership, residual rim rejection,
## four-neighbour connectivity and the real shared BFS/step planner.
const Board = preload("res://scripts/data/diamond_duel_board.gd")
const Config = preload("res://scripts/data/board_trial_config.gd")
const Space = preload("res://scripts/combat/board_trial_space.gd")
const Stepwise = preload("res://scripts/combat/board_trial_stepwise.gd")

var checks := 0
var failures: Array[String] = []
var failed_samples := 0
var max_inverse_error := 0.0
var rim_cells: Array[Vector2i] = []
var shared_edge_samples := 0
var grid_samples := 0
var output := "/tmp/qa07-duel-20261025/qa-geometry.json"

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		if failed_samples < 25:
			failed_samples += 1
			push_error(label)

# Independent derivation: the arena is centred on ORIGIN, spans 1344x576, and a
# complete tile is 192x96. A centre (gx,gy) maps to 960+96*(gx-gy), 588+48*(gx+gy).
# Complete means the four vertices are inside the closed inner arena:
#   |96*(gx-gy)|+96 <= 672  -> |gx-gy| <= 6
#   |48*(gx+gy)|+48 <= 288  -> |gx+gy| <= 5
const HALF_DIFF := 6
const HALF_SUM := 5

func exp_valid(cell: Vector2i) -> bool:
	return absi(cell.x-cell.y) <= HALF_DIFF and absi(cell.x+cell.y) <= HALF_SUM

func exp_center(cell: Vector2i) -> Vector2:
	return Vector2(960.0+96.0*float(cell.x-cell.y),588.0+48.0*float(cell.x+cell.y))

func in_arena_closed(p: Vector2) -> bool:
	var a: Rect2 = Board.ARENA
	return p.x >= a.position.x and p.x <= a.end.x and p.y >= a.position.y and p.y <= a.end.y

func diamond_contains(cell: Vector2i, p: Vector2) -> bool:
	var d := p-exp_center(cell)
	return absf(d.x)/96.0+absf(d.y)/48.0 <= 1.0+0.0000001

func bfs_all(start: Vector2i, cells: Dictionary) -> Dictionary:
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	var cursor := 0
	while cursor < queue.size():
		var cell: Vector2i = queue[cursor]
		cursor += 1
		for direction in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
			var next: Vector2i = cell+direction
			if cells.has(next) and not seen.has(next):
				seen[next] = true
				queue.append(next)
	return seen

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	run()

func run() -> void:
	var start_ms := Time.get_ticks_msec()
	var expected: Array[Vector2i] = []
	for y in range(-12,13):
		for x in range(-12,13):
			if exp_valid(Vector2i(x,y)): expected.append(Vector2i(x,y))
	check(expected.size() == 71, "independent lattice formula yields exactly 71 complete tiles")
	var actual: Array = Board.cells()
	check(actual.size() == expected.size(), "Board.cells() count equals independent formula")
	var expected_set := {}
	for cell in expected: expected_set[cell] = true
	check(actual.all(func(cell): return expected_set.has(cell)), "every enumerated cell is expected")
	check(expected.all(func(cell): return actual.has(cell)), "every expected cell is enumerated")
	check(actual.size() == 71, "produced legal-cell count is 71")
	check(not Board.valid(Board.INVALID), "pick sentinel is not a playable cell")
	check(Board.valid(Vector2i(-1,-1)) and expected_set.has(Vector2i(-1,-1)), "(-1,-1) is a real playable tile")
	check(Board.INVALID == Vector2i(-9999,-9999), "failure sentinel is separate from negative lattice cells")
	check(Board.ARENA == Rect2(288,300,1344,576), "declared horizontal rectangular inner frame")
	check(Board.CELL_SIZE == Vector2(192,96), "declared 2:1 diamond tile")

	# Per-cell exact geometry.
	for cell in expected:
		check(Board.valid(cell), "expected tile is valid "+str(cell))
		var center: Vector2 = Board.center(cell)
		check(center.distance_to(exp_center(cell)) < 0.000001, "centre uses independent affine formula "+str(cell))
		check(Board.valid(cell) == exp_valid(cell), "mask agrees with derived inequality "+str(cell))
		check(in_arena_closed(center), "centre lies in arena "+str(cell))
		var inverse_error := Board.inverse(center).distance_to(Vector2(cell))
		max_inverse_error = maxf(max_inverse_error,inverse_error)
		check(inverse_error < 0.000001, "inverse(centre) returns lattice cell "+str(cell))
		check(Board.cell_at(center) == cell, "centre picking returns its tile "+str(cell))
		var polygon: PackedVector2Array = Board.polygon(cell)
		check(polygon.size() == 4, "draw polygon has four vertices "+str(cell))
		var exact := [center+Vector2(0,-48),center+Vector2(96,0),center+Vector2(0,48),center+Vector2(-96,0)]
		for index in 4:
			check(polygon[index].distance_to(exact[index]) < 0.000001, "exact diamond vertex "+str(cell)+" "+str(index))
			check(in_arena_closed(polygon[index]), "complete tile vertex inside inner frame "+str(cell))
		var area := 0.0
		for index in 4:
			var a: Vector2 = polygon[index]
			var b: Vector2 = polygon[(index+1)%4]
			area += a.cross(b)
		check(absf(area)*0.5 > 9215.99 and absf(area)*0.5 < 9216.01, "tile area is exactly half of 192x96 "+str(cell))

	# Picking a dense screen grid: no complete-tile point may be rejected and no
	# point may be assigned to a residual tile.
	for gy in range(0,73):
		for gx in range(0,169):
			var p := Vector2(288.0+float(gx)*8.0+0.37,300.0+float(gy)*8.0+0.41)
			if not in_arena_closed(p): continue
			grid_samples += 1
			var grid := Board.inverse(p)
			var nearest := Vector2i(floori(grid.x+0.5),floori(grid.y+0.5))
			var picked: Vector2i = Board.cell_at(p)
			if exp_valid(nearest):
				check(picked == nearest, "inside a complete tile is always accepted "+str(p))
				check(diamond_contains(nearest,p), "sampled point really lies in that diamond "+str(p))
			else:
				check(picked == Board.INVALID, "residual/outside tile is never clamped "+str(p))

	# Shared edge ownership: both sides resolve to their own tile; an exact edge
	# has exactly one deterministic owner and never an invented third cell.
	for cell in expected:
		for direction in [Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0),Vector2i(0,-1)]:
			var next: Vector2i = cell+direction
			var midpoint := (Board.center(cell)+Board.center(next))*0.5
			var normal := (Board.center(next)-Board.center(cell)).normalized()
			var near_side: Vector2i = Board.cell_at(midpoint-normal*0.0001)
			var far_side: Vector2i = Board.cell_at(midpoint+normal*0.0001)
			var exact_owner: Vector2i = Board.cell_at(midpoint)
			shared_edge_samples += 2
			check(near_side == cell, "edge side inside source tile "+str(cell)+" "+str(direction))
			if exp_valid(next):
				check(far_side == next, "edge side inside logical neighbour "+str(cell)+" "+str(direction))
			else:
				check(far_side == Board.INVALID, "edge against residual tile rejects, no clamp "+str(cell)+" "+str(direction))
			check(exact_owner == near_side or exact_owner == far_side, "exact shared edge has one owner "+str(cell)+" "+str(direction))
			# The two vertices shared by the tiles are exactly on the boundary.
			for vertex in Board.polygon(cell):
				var owner := Board.cell_at(vertex)
				check(owner == Board.INVALID or diamond_contains(owner,vertex),
					"shared vertex resolves only to a tile that physically contains it "+str(cell))

	# Residual rim: cells whose centre is visibly inside the art rectangle but
	# which lack one complete corner are never playable.
	for y in range(-10,11):
		for x in range(-10,11):
			var cell := Vector2i(x,y)
			if exp_valid(cell): continue
			var center: Vector2 = Board.center(cell)
			if in_arena_closed(center):
				rim_cells.append(cell)
				check(Board.cell_at(center) == Board.INVALID, "visible residual rim centre is not playable "+str(cell))
				check(not Board.valid(cell), "residual rim tile is not valid "+str(cell))
	check(rim_cells.size() == 26, "26 partial rim tiles are visibly inside the frame but rejected")
	for corner in [Vector2(288,300),Vector2(1632,300),Vector2(288,876),Vector2(1632,876)]:
		check(Board.cell_at(corner) == Board.INVALID, "inner-frame rectangle corner is not a diamond "+str(corner))
	for p in [Vector2(287.9,588),Vector2(1632.1,588),Vector2(960,299.9),Vector2(960,876.1),Vector2(NAN,588),Vector2(INF,588)]:
		check(Board.cell_at(p) == Board.INVALID, "outside/non-finite point rejected "+str(p))

	# Connectivity under logical four neighbours and real shared BFS.
	var cell_set := {}
	for cell in expected: cell_set[cell] = true
	var reached := bfs_all(Vector2i.ZERO, cell_set)
	check(reached.size() == 71, "all 71 tiles are four-neighbour connected to centre")
	var free := func(_cell: Vector2i) -> bool: return false
	var max_path := 0
	for goal in expected:
		var path: Array[Vector2i] = Space.path(Vector2i.ZERO,goal,0,free,Board.INVALID,-1,Board.valid)
		check(not path.is_empty() and path.back() == goal, "shared BFS reaches every complete tile "+str(goal))
		check(path[0] == Vector2i.ZERO, "BFS starts at the requested source "+str(goal))
		var legal := true
		for index in path.size():
			legal = legal and exp_valid(path[index])
			if index > 0: legal = legal and Config.distance(path[index-1],path[index]) == 1
		check(legal and path.size()-1 == absi(goal.x)+absi(goal.y), "BFS path is legal, four-neighbour and shortest "+str(goal))
		max_path = maxi(max_path,path.size()-1)
	check(Space.path(Vector2i.ZERO,Board.INVALID,0,free,Board.INVALID,-1,Board.valid).is_empty(), "BFS rejects the failure sentinel as goal")
	check(Space.path(Board.INVALID,Vector2i.ZERO,0,free,Board.INVALID,-1,Board.valid).is_empty(), "BFS rejects the failure sentinel as source")
	check(Space.path(Vector2i(3,-3),Vector2i(-3,3),0,free,Board.INVALID,-1,Board.valid).size() == 13, "opposite corner route uses 12 real steps")

	# Actual step planner can find a reach-1 attack cell around the target for
	# representative far/near/rim pairs, without overlapping the target.
	var pairs := [
		[Vector2i(-3,0),Vector2i(3,0)],
		[Vector2i(1,0),Vector2i(-1,0)],
		[Vector2i(-3,3),Vector2i(3,-3)],
		[Vector2i(1,4),Vector2i(1,-4)],
		[Vector2i(0,-4),Vector2i(0,4)]]
	var planned_pairs := 0
	for pair in pairs:
		var a: Vector2i = pair[0]
		var b: Vector2i = pair[1]
		var actor := {"cell":a,"walk":Config.MOVE_SECONDS_PER_CELL,"reach":1}
		var target := {"cell":b}
		var occupied := {b: 999999}
		var approaches := 0
		for direction in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
			var option: Dictionary = Stepwise.route(a+direction,actor,target,occupied,Board.valid)
			if option.is_empty(): continue
			approaches += 1
			var legal := true
			for cell in option.path: legal = legal and exp_valid(cell)
			check(legal, "approach path stays in complete mask "+str(a)+"->"+str(b))
			check(Config.distance(option.path.back(),b) == 1 and option.path.back() != b, "approach ends in real range-1 attack cell "+str(a)+"->"+str(b))
		check(approaches > 0, "shared planner finds at least one attack approach "+str(a)+"->"+str(b))
		planned_pairs += 1
	check(Stepwise.route(Board.INVALID,{"cell":Vector2i(-3,0),"walk":0.5,"reach":1},{"cell":Vector2i(3,0)},{Vector2i(3,0):999999},Board.valid).is_empty(), "planner rejects invalid first step")

	# The legacy rectangular domain must remain untouched by the instance hook.
	var legacy_count := 0
	for y in range(Config.ROWS):
		for x in range(Config.COLS):
			check(Config.valid(Vector2i(x,y)), "legacy 12x7 domain unchanged "+str(Vector2i(x,y)))
			legacy_count += 1
	check(legacy_count == 84, "legacy default config still has 84 cells")
	check(not Config.valid(Vector2i(-1,-1)) and Config.cell_at(Config.center(Vector2i(0,0))) == Vector2i.ZERO, "legacy inverse/pick rules unchanged")
	check(Config.valid(Vector2i(11,6)) and not Config.valid(Vector2i(12,0)), "legacy bounds remain half-open 12x7")
	var legacy_path: Array[Vector2i] = Space.path(Vector2i.ZERO,Vector2i(11,6),0,free)
	check(legacy_path.size() == 18 and legacy_path.all(func(cell): return Config.valid(cell)),
		"omitted callback keeps legacy 12x7 shortest path")

	var report := {
		"scope":"07 independent D002 geometry/topology",
		"method":"re-derived 1344x576 arena + 192x96 tile inequalities; did not use Board.valid to create expectations",
		"checks":checks,
		"failures":failures,
		"legal_cells":actual.size(),
		"rim_cells":rim_cells.size(),
		"grid_samples":grid_samples,
		"shared_edge_samples":shared_edge_samples,
		"max_path_steps":max_path,
		"planned_pairs":planned_pairs,
		"legacy_cells":legacy_count,
		"max_inverse_error":max_inverse_error,
		"OS_input_verified":false,
		"rendered_pixels_verified":false,
		"elapsed_ms":Time.get_ticks_msec()-start_ms}
	var file := FileAccess.open(output,FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(report,"\t"))
	print("QA07_GEOMETRY checks=",checks," failures=",failures.size()," cells=",actual.size()," rim=",rim_cells.size()," grid=",grid_samples," edges=",shared_edge_samples," out=",output)
	quit(1 if failures else 0)
