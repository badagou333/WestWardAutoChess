extends RefCounted
## Frontal orthographic ground plane, pitched 45 degrees down from the horizon.
## X is exactly horizontal; ground-depth Y is compressed by sin(45 degrees).
## This is display projection only. Combat retains its integer 12 by 7 board.
const Config = preload("res://scripts/data/board_trial_config.gd")
const CAMERA_PITCH_DEGREES := 45.0
const TILE_WIDTH := 106.0
const DEPTH_RATIO := 0.7071067811865476
const ORIGIN := Vector2(246,274)
const U := Vector2(TILE_WIDTH,0)
const V := Vector2(0,TILE_WIDTH*DEPTH_RATIO)

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
