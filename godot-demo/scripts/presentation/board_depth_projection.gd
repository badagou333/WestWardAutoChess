extends RefCounted
## Affine ground projection only. Combat retains its integer 12 by 7 board.
const Config = preload("res://scripts/data/board_trial_config.gd")
const ORIGIN := Vector2(234,406)
const U := Vector2(92,-17)
const V := Vector2(29,54)

static func point(grid: Vector2) -> Vector2:
	return ORIGIN+U*grid.x+V*grid.y

static func center(cell: Vector2i) -> Vector2:
	return point(Vector2(cell)+Vector2(0.5,0.5))

static func inverse(pixel: Vector2) -> Vector2:
	var offset := pixel-ORIGIN
	var determinant := U.cross(V)
	return Vector2(offset.cross(V),U.cross(offset))/determinant

static func cell_at(pixel: Vector2) -> Vector2i:
	var grid := inverse(pixel)
	var cell := Vector2i(floori(grid.x),floori(grid.y))
	return cell if Config.valid(cell) else Vector2i(-1,-1)

static func polygon(cell: Vector2i, inset := 0.035) -> PackedVector2Array:
	var at := Vector2(cell)
	return PackedVector2Array([
		point(at+Vector2(inset,inset)),
		point(at+Vector2(1.0-inset,inset)),
		point(at+Vector2(1.0-inset,1.0-inset)),
		point(at+Vector2(inset,1.0-inset))])
