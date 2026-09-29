extends RefCounted

# Hand-calibrated stone seam intersections in battlefield-candidate.png (1672x941).
# Only projection changes: logical cells remain 5x7 with Manhattan gameplay distances.
const IMAGE_SIZE := Vector2(1672,941)
const VIEW_SIZE := Vector2(1920,1080)
const Y := [254.0,342.0,431.0,530.0,634.0,746.0]
const X := [
	[381,513,643,773,904,1032,1161,1292],
	[365,503,636,770,905,1036,1168,1310],
	[347,492,628,766,905,1043,1180,1327],
	[328,478,621,765,907,1050,1192,1348],
	[309,467,615,762,909,1057,1206,1371],
	[288,454,608,759,911,1068,1220,1394]
]

static func vertex(row: int, col: int) -> Vector2:
	return Vector2(X[row][col],Y[row])*VIEW_SIZE/IMAGE_SIZE

static func polygon(cell: Vector2i) -> PackedVector2Array:
	return PackedVector2Array([vertex(cell.x,cell.y),vertex(cell.x,cell.y+1),vertex(cell.x+1,cell.y+1),vertex(cell.x+1,cell.y)])

static func center(cell: Vector2i) -> Vector2:
	var points := polygon(cell)
	return (points[0]+points[1]+points[2]+points[3])/4.0

static func cell_at(point: Vector2) -> Vector2i:
	for row in range(5):
		for col in range(7):
			var cell := Vector2i(row,col)
			if Geometry2D.is_point_in_polygon(point,polygon(cell)): return cell
	return Vector2i(-1,-1)
