extends SceneTree
## Geometry/topology only. No OS-pointer, rendered-pixel or animation claim.
const Board = preload("res://scripts/data/diamond_duel_board.gd")
const Config = preload("res://scripts/data/board_trial_config.gd")
const Space = preload("res://scripts/combat/board_trial_space.gd")
const Stepwise = preload("res://scripts/combat/board_trial_stepwise.gd")
var checks := 0
var failures: Array[String]=[]
var shared_edge_side_samples := 0
var residual_cells := 0
var max_roundtrip_error := 0.0

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		push_error(label)

func arena_contains_closed(pixel: Vector2) -> bool:
	return pixel.x>=Board.ARENA.position.x and pixel.y>=Board.ARENA.position.y and pixel.x<=Board.ARENA.end.x and pixel.y<=Board.ARENA.end.y

func path_is_legal(path: Array[Vector2i]) -> bool:
	for index in path.size():
		if not Board.valid(path[index]): return false
		if index>0 and Config.distance(path[index-1],path[index])!=1: return false
	return true

func _initialize() -> void:
	var cells: Array[Vector2i]=Board.cells()
	check(cells.size()==71,"prototype has exactly 71 complete diamonds, not a hidden rectangular logical board")
	check(Board.ARENA==Rect2(288,300,1344,576),"outer arena is horizontal screen rectangle")
	check(Board.CELL_SIZE==Vector2(192,96) and Board.WIDTH==2*Board.HEIGHT,"exact 2:1 tile diagonal dimensions")
	check(Board.center(Vector2i.ZERO)==Vector2(960,588),"integer lattice origin identifies a cell center")
	check(Board.valid(Vector2i(-1,-1)) and not Board.valid(Board.INVALID),"negative real cells cannot alias invalid-pick sentinel")
	check(Board.cell_at(Board.center(Vector2i(-1,-1)))==Vector2i(-1,-1),"old rectangular sentinel is a real pick here")
	var seen := {}
	var boundary_edges := 0
	for cell in cells:
		check(not seen.has(cell),"legal-cell enumeration is unique "+str(cell))
		seen[cell]=true
		check(Board.valid(cell),"enumerated cell valid "+str(cell))
		check(Board.cell_at(Board.center(cell))==cell,"center picks its own tile "+str(cell))
		var polygon: PackedVector2Array=Board.polygon(cell)
		check(polygon.size()==4,"exactly four vertices "+str(cell))
		check(polygon[0]==Board.center(cell)+Vector2(0,-48) and polygon[1]==Board.center(cell)+Vector2(96,0) and polygon[2]==Board.center(cell)+Vector2(0,48) and polygon[3]==Board.center(cell)+Vector2(-96,0),"exact diamond vertices "+str(cell))
		for vertex in polygon: check(arena_contains_closed(vertex),"all four vertices fit horizontal inner frame "+str(cell))
		var inset_polygon: PackedVector2Array=Board.polygon(cell,.05)
		for index in polygon.size():
			check(inset_polygon[index].distance_to(Board.center(cell)+(polygon[index]-Board.center(cell))*.9)<.0002,"inset preserves diamond aspect and center "+str(cell))
		for fraction_x in [-.49,-.25,0.0,.25,.49]:
			for fraction_y in [-.49,-.25,0.0,.25,.49]:
				var grid := Vector2(cell)+Vector2(fraction_x,fraction_y)
				var pixel := Board.point(grid)
				var error := Board.inverse(pixel).distance_to(grid)
				max_roundtrip_error=maxf(max_roundtrip_error,error)
				check(error<.000004,"forward/inverse continuous coordinate "+str(grid))
				check(Board.cell_at(pixel)==cell,"25 interior samples pick same full tile "+str(grid))
		for direction in Space.DIRECTIONS:
			var next: Vector2i=cell+direction
			var expected_screen: Vector2=Board.AXIS_U*direction.x+Board.AXIS_V*direction.y
			check(Board.center(next)-Board.center(cell)==expected_screen,"logical four-neighbor is one diagonal shared edge "+str(cell)+" "+str(direction))
			if Board.valid(next):
				check(Config.distance(cell,next)==1,"legal screen neighbor is Manhattan one, not logical diagonal")
			else:
				boundary_edges+=1
				var beyond := Vector2(cell)+Vector2(direction)*.50001
				check(Board.cell_at(Board.point(beyond))==Board.INVALID,"outside full-cell mask never clamps to boundary tile "+str(cell)+" "+str(direction))
		# Every internal shared edge is visited once in the positive lattice axes.
		# The 1e-5 offset remains representable in the screen coordinate range.
		for direction in [Vector2i(1,0),Vector2i(0,1)]:
			var next: Vector2i=cell+direction
			if not Board.valid(next): continue
			var tangent := Vector2(direction.y,direction.x)
			for fraction in [-.375,0.0,.375]:
				var on_edge: Vector2 = Vector2(cell)+Vector2(direction)*.5+tangent*float(fraction)
				shared_edge_side_samples+=2
				check(Board.cell_at(Board.point(on_edge-Vector2(direction)*.00001))==cell,"shared edge negative side "+str(on_edge))
				check(Board.cell_at(Board.point(on_edge+Vector2(direction)*.00001))==next,"shared edge positive side "+str(on_edge))
				check(Board.cell_at(Board.point(on_edge))==next,"shared edge exact half-open owner "+str(on_edge))
	# Compare mask generation independently to all four explicit corner tests.
	# A center can lie within the rectangular art but belong to a truncated cell.
	for row in range(-8,9):
		for col in range(-8,9):
			var cell := Vector2i(col,row)
			var center: Vector2=Board.center(cell)
			var complete := true
			for corner in [center+Vector2(96,0),center-Vector2(96,0),center+Vector2(0,48),center-Vector2(0,48)]:
				complete=complete and arena_contains_closed(corner)
			check(Board.valid(cell)==complete,"mask matches all four complete corner constraints "+str(cell))
			check(cells.has(cell)==complete,"enumeration and validity agree "+str(cell))
			if not complete and arena_contains_closed(center):
				residual_cells+=1
				check(Board.cell_at(center)==Board.INVALID,"visible residual cell center is not playable "+str(cell))
	check(residual_cells>0 and boundary_edges>0,"test genuinely covers partial rim cells and mask edges")
	for corner in [Board.ARENA.position,Vector2(Board.ARENA.end.x,Board.ARENA.position.y),Board.ARENA.end,Vector2(Board.ARENA.position.x,Board.ARENA.end.y)]:
		check(Board.cell_at(corner)==Board.INVALID,"rectangle corners are residual art, not invented playable diamonds "+str(corner))
	for fraction in [.0,.125,.25,.5,.75,.875,1.0]:
		var x: float=lerpf(Board.ARENA.position.x,Board.ARENA.end.x,fraction)
		var y: float=lerpf(Board.ARENA.position.y,Board.ARENA.end.y,fraction)
		for pixel in [Vector2(x,Board.ARENA.position.y-.001),Vector2(x,Board.ARENA.end.y+.001),Vector2(Board.ARENA.position.x-.001,y),Vector2(Board.ARENA.end.x+.001,y)]:
			check(Board.cell_at(pixel)==Board.INVALID,"all four exterior strips rejected without nearest clamp "+str(pixel))
	for bad in [Vector2(INF,300),Vector2(300,INF),Vector2(NAN,300),Vector2(300,NAN),Vector2(1e30,-1e30)]:
		check(Board.cell_at(bad)==Board.INVALID,"nonfinite or remote input rejected "+str(bad))
	# Real shared BFS with the instance callback must reach every tile, never
	# cross a hidden partial rim. No new planning implementation is substituted.
	var free := func(_cell: Vector2i) -> bool: return false
	for goal in cells:
		var path: Array[Vector2i]=Space.path(Vector2i.ZERO,goal,0,free,Board.INVALID,-1,Board.valid)
		check(not path.is_empty() and path.back()==goal,"every full tile connected to center "+str(goal))
		check(path_is_legal(path),"shared BFS respects mask and logical four-neighbor route "+str(goal))
	check(Space.path(Vector2i.ZERO,Board.INVALID,0,free,Board.INVALID,-1,Board.valid).is_empty(),"shared BFS rejects illegal goal")
	check(Space.path(Board.INVALID,Vector2i.ZERO,0,free,Board.INVALID,-1,Board.valid).is_empty(),"shared BFS rejects illegal source")
	var legacy: Array[Vector2i]=Space.path(Vector2i.ZERO,Vector2i(11,6),0,free)
	check(legacy.size()==18 and legacy.all(func(cell: Vector2i) -> bool: return Config.valid(cell)),"omitted callback keeps legacy 12 by 7 BFS behavior")
	check(Space.path(Vector2i(-1,-1),Vector2i.ZERO,0,free).is_empty(),"legacy default still rejects its negative sentinel")
	var actor := {"cell":Vector2i(-2,2),"walk":Config.MOVE_SECONDS_PER_CELL,"reach":1}
	var target := {"cell":Vector2i(2,-2)}
	var occupied := {target.cell:Stepwise.NEVER}
	var approaches := 0
	for direction in Space.DIRECTIONS:
		var option: Dictionary=Stepwise.route(actor.cell+direction,actor,target,occupied,Board.valid)
		if option.is_empty(): continue
		approaches+=1
		check(path_is_legal(option.path),"real stepwise approach uses complete-cell mask")
		check(Config.distance(option.path.back(),target.cell)<=actor.reach and option.path.back()!=target.cell,"stepwise finishes in genuine attack reach without overlapping target")
	check(approaches>0,"stepwise sample actually finds attack approaches")
	check(Stepwise.route(Board.INVALID,actor,target,occupied,Board.valid).is_empty(),"stepwise rejects partial/outside first segment")
	var output := "/tmp/diamond-duel-geometry.json"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output=argument.trim_prefix("--output=")
	var report := {"checks":checks,"failures":failures,"projection":"rect-arena-diamond-lattice-v1","cells":cells.size(),"shared_edge_side_samples":shared_edge_side_samples,"residual_cells_checked":residual_cells,"boundary_edges_checked":boundary_edges,"interior_samples_per_cell":25,"max_roundtrip_error":max_roundtrip_error,"OS_input_verified":false,"rendered_pixels_verified":false}
	var file := FileAccess.open(output,FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(report,"\t"))
	print("DIAMOND_DUEL_GEOMETRY ",checks," checks / ",failures.size()," failures; ",output)
	quit(0 if failures.is_empty() else 1)
