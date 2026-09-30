extends RefCounted
## Hand-calibrated to painted_route_v2, source 1672x941. Trial topology,
## NOT the art proposal's 122 cells. Borders follow the dominant stone seams;
## edge cliff/decorative partial stones are deliberately non-walkable.
const SOURCE_SIZE := Vector2(1672,941)
const DISPLAY_SIZE := Vector2(1920,1080)
const X := [255,320,386,452,520,588,656,722,789,852,917,980,1040,1098,1155,1213,1271,1328,1387,1445]
const Y := [132,181,230,277,325,373,424,475,529,583,636,691,744]
const SPANS := [
	[[12,15]], [[11,15]], [[3,16]], [[1,17]], [[0,17]],
	[[0,5],[12,17]], [[0,4],[13,17]], [[0,3],[16,18]],
	[[0,3],[16,18]], [[0,5],[14,18]], [[0,17]], [[5,15]]
]
const ROUTE: Array[Vector2i] = [
	Vector2i(8,1),Vector2i(8,2),Vector2i(7,2),Vector2i(6,2),Vector2i(5,2),
	Vector2i(5,3),Vector2i(4,3),Vector2i(3,3),Vector2i(2,3),
	Vector2i(2,4),Vector2i(2,5),Vector2i(2,6),Vector2i(2,7),Vector2i(2,8),Vector2i(2,9),
	Vector2i(2,10),Vector2i(2,11),Vector2i(2,12),Vector2i(2,13),Vector2i(2,14),Vector2i(2,15),
	Vector2i(2,16),Vector2i(3,16),Vector2i(4,16),Vector2i(5,16),Vector2i(6,16)
]
const CHECKPOINTS := [8,14,20,25]
const NAMES := ["林口接应", "石桥伏击", "北岸回防", "山门突围"]
const ENTRIES := [
	[Vector2i(5,0),Vector2i(3,1),Vector2i(9,3)],
	[Vector2i(3,7),Vector2i(4,10),Vector2i(3,8),Vector2i(3,11)],
	[Vector2i(0,13),Vector2i(3,17),Vector2i(4,15),Vector2i(0,15)],
	[Vector2i(8,18),Vector2i(7,17)]
]
const STEP_SECONDS := 1.6 # Expanded path trial pacing, not final balance.
const WARNING_SECONDS := 2.0

static func valid(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.x >= SPANS.size(): return false
	for span in SPANS[cell.x]:
		if cell.y >= span[0] and cell.y <= span[1]: return true
	return false

static func cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for row in range(SPANS.size()):
		for span in SPANS[row]:
			for col in range(span[0],span[1]+1): result.append(Vector2i(row,col))
	return result

static func rect(cell: Vector2i) -> Rect2:
	return Rect2(Vector2(X[cell.y],Y[cell.x])*DISPLAY_SIZE/SOURCE_SIZE,Vector2(X[cell.y+1]-X[cell.y],Y[cell.x+1]-Y[cell.x])*DISPLAY_SIZE/SOURCE_SIZE)

static func center(cell: Vector2i) -> Vector2:
	return rect(cell).get_center()

static func tile_at(pos: Vector2) -> Vector2i:
	for cell in cells():
		if rect(cell).has_point(pos): return cell
	return Vector2i(-1,-1)
