extends RefCounted

# Trial map: connected discrete tiles, cut-away coast and a two-tile pass.
# Row/column coordinates are unrelated to the old rectangular board dimensions.
const ROWS := ["......###.", "..#######.", ".#########", "####..####", "####..###.", ".###......"]
const ORIGIN := Vector2(390, 310)
const TILE := Vector2(112, 88)
const ROUTE: Array[Vector2i] = [
	Vector2i(4,1), Vector2i(4,2), Vector2i(3,2), Vector2i(2,2),
	Vector2i(2,3), Vector2i(2,4), Vector2i(2,5), Vector2i(2,6),
	Vector2i(1,6), Vector2i(1,7), Vector2i(1,8), Vector2i(2,8), Vector2i(3,8)
]
const CHECKPOINTS := [3,6,9,12]
const NAMES := ["林口接应", "石桥伏击", "北岸回防", "山门突围"]
const ENTRIES := [
	[Vector2i(3,0), Vector2i(1,2), Vector2i(5,3)],
	[Vector2i(1,4), Vector2i(0,6), Vector2i(1,5), Vector2i(2,9)],
	[Vector2i(0,6), Vector2i(2,9), Vector2i(4,7), Vector2i(0,8)],
	[Vector2i(4,8), Vector2i(3,9)]
]
const STEP_SECONDS := 2.5
const WARNING_SECONDS := 2.0

static func valid(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < ROWS.size() and cell.y >= 0 and cell.y < ROWS[cell.x].length() and ROWS[cell.x][cell.y] == "#"

static func cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for row in range(ROWS.size()):
		for col in range(ROWS[row].length()):
			if valid(Vector2i(row,col)): result.append(Vector2i(row,col))
	return result

static func center(cell: Vector2i) -> Vector2:
	return ORIGIN + Vector2(cell.y*TILE.x, cell.x*TILE.y)

static func tile_at(pos: Vector2) -> Vector2i:
	var relative := (pos-ORIGIN)/TILE
	var cell := Vector2i(roundi(relative.y),roundi(relative.x))
	return cell if valid(cell) else Vector2i(-1,-1)

static func rect(cell: Vector2i) -> Rect2:
	return Rect2(center(cell)-TILE/2,TILE)
