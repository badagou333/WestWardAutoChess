extends RefCounted
## D-20261018-002 prototype defaults, not a final board size or game rule.
## Integer lattice coordinates identify cell CENTERS. Four-neighbor movement
## stays (+/-1,0)/(0,+/-1); its screen axes are diagonal, not logical diagonals.
const WIDTH := 192.0
const HEIGHT := 96.0
const W := WIDTH
const H := HEIGHT
const CELL_SIZE := Vector2(WIDTH,HEIGHT)
const AXIS_U := Vector2(WIDTH*.5,HEIGHT*.5)
const AXIS_V := Vector2(-WIDTH*.5,HEIGHT*.5)
const ORIGIN := Vector2(960,588)
const ARENA := Rect2(288,300,1344,576)
const SEARCH_MIN := -8
const SEARCH_MAX := 8
# (-1,-1) is a real playable cell in this centered lattice. Never use the
# legacy rectangular-board sentinel for an unsuccessful diamond pick.
const INVALID := Vector2i(-9999,-9999)
const INVALID_CELL := INVALID

static func point(grid: Vector2) -> Vector2:
	return ORIGIN+AXIS_U*grid.x+AXIS_V*grid.y

static func center(cell: Vector2i) -> Vector2:
	return point(Vector2(cell))

static func inverse(pixel: Vector2) -> Vector2:
	var local := pixel-ORIGIN
	return Vector2(local.x/WIDTH+local.y/HEIGHT,-local.x/WIDTH+local.y/HEIGHT)

static func _inside_arena(pixel: Vector2) -> bool:
	# Closed geometric containment is deliberate: a COMPLETE tile may touch the
	# inner frame. Pick ownership is separately half-open in lattice space.
	return pixel.is_finite() and pixel.x>=ARENA.position.x and pixel.x<=ARENA.end.x and pixel.y>=ARENA.position.y and pixel.y<=ARENA.end.y

static func valid(cell: Vector2i) -> bool:
	if cell.x<SEARCH_MIN or cell.x>SEARCH_MAX or cell.y<SEARCH_MIN or cell.y>SEARCH_MAX: return false
	var pixel := center(cell)
	return _inside_arena(pixel+Vector2(WIDTH*.5,0)) and _inside_arena(pixel-Vector2(WIDTH*.5,0)) and _inside_arena(pixel+Vector2(0,HEIGHT*.5)) and _inside_arena(pixel-Vector2(0,HEIGHT*.5))

static func cells() -> Array[Vector2i]:
	var result: Array[Vector2i]=[]
	for row in range(SEARCH_MIN,SEARCH_MAX+1):
		for col in range(SEARCH_MIN,SEARCH_MAX+1):
			var cell := Vector2i(col,row)
			if valid(cell): result.append(cell)
	return result

static func cell_at(pixel: Vector2) -> Vector2i:
	if not _inside_arena(pixel): return INVALID
	var grid := inverse(pixel)
	if not grid.is_finite(): return INVALID
	# No nearest-valid-cell clamp. A partial rim cell remains non-playable even
	# when its visible fragment lies inside the rectangular frame.
	var cell := Vector2i(floori(grid.x+.5),floori(grid.y+.5))
	if not valid(cell): return INVALID
	# The same exact affine diamond used to draw the cell also bounds input.
	# Half-open ownership above resolves any shared edge to a single cell.
	var local := pixel-center(cell)
	if absf(local.x)/(WIDTH*.5)+absf(local.y)/(HEIGHT*.5)>1.0: return INVALID
	return cell

static func polygon(cell: Vector2i, inset := 0.0) -> PackedVector2Array:
	# Fractional logical inset: .05 reduces both diamond diagonals by 10%.
	var amount := maxf(0.0,1.0-2.0*inset)
	var pixel := center(cell)
	return PackedVector2Array([
		pixel+Vector2(0,-HEIGHT*.5*amount),
		pixel+Vector2(WIDTH*.5*amount,0),
		pixel+Vector2(0,HEIGHT*.5*amount),
		pixel+Vector2(-WIDTH*.5*amount,0)])
