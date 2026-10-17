extends RefCounted
## D-20261017-002: one display-only homography, calibrated to the clean stage.
## Combat, movement duration and distances retain the integer 12 by 7 board.
const Config = preload("res://scripts/data/board_trial_config.gd")
const IMAGE_ORIGIN := Vector2(120,110)
const IMAGE_SCALE := 0.92
const IMAGE_SIZE := Vector2(1672,941)
const IMAGE_RECT := Rect2(IMAGE_ORIGIN,IMAGE_SIZE*IMAGE_SCALE)
const IMAGE_CENTER_X := 824.0
const IMAGE_TOP_Y := 228.0
const IMAGE_HEIGHT := 450.0
const IMAGE_TOP_WIDTH := 1152.0
const IMAGE_BOTTOM_WIDTH := 1400.0
const FAR_NEAR_RATIO := IMAGE_TOP_WIDTH/IMAGE_BOTTOM_WIDTH
const BODY_NEAR_SCALE := 0.9
const INVALID_CELL := Vector2i(-1,-1)

static func _denominator(grid_y: float) -> float:
	return 1.0+(FAR_NEAR_RATIO-1.0)*grid_y/float(Config.ROWS)

static func _screen_x(grid_x: float, grid_y: float) -> float:
	return IMAGE_ORIGIN.x+IMAGE_SCALE*(IMAGE_CENTER_X+IMAGE_TOP_WIDTH*(grid_x/float(Config.COLS)-0.5)/_denominator(grid_y))

static func point(grid: Vector2) -> Vector2:
	var denominator := _denominator(grid.y)
	if not grid.is_finite() or not is_finite(denominator) or denominator == 0.0:
		return Vector2(NAN,NAN)
	return Vector2(_screen_x(grid.x,grid.y),
		IMAGE_ORIGIN.y+IMAGE_SCALE*(IMAGE_TOP_Y+IMAGE_HEIGHT*FAR_NEAR_RATIO*(float(grid.y)/float(Config.ROWS))/denominator))

static func center(cell: Vector2i) -> Vector2:
	return point(Vector2(cell)+Vector2(0.5,0.5))

static func _inverse_values(pixel: Vector2) -> PackedFloat64Array:
	if not pixel.is_finite(): return PackedFloat64Array([NAN,NAN])
	# Keep intermediate coordinates in double precision, rather than rounding the
	# inverse to a Vector2 before deciding which side of a boundary was clicked.
	var image_y := (float(pixel.y)-IMAGE_ORIGIN.y)/IMAGE_SCALE
	var normalized_y := (image_y-IMAGE_TOP_Y)/IMAGE_HEIGHT
	var divisor := FAR_NEAR_RATIO-normalized_y*(FAR_NEAR_RATIO-1.0)
	if not is_finite(divisor) or divisor == 0.0: return PackedFloat64Array([NAN,NAN])
	var v := normalized_y/divisor
	var denominator := 1.0+(FAR_NEAR_RATIO-1.0)*v
	var image_x := (float(pixel.x)-IMAGE_ORIGIN.x)/IMAGE_SCALE
	var u := 0.5+(image_x-IMAGE_CENTER_X)*denominator/IMAGE_TOP_WIDTH
	return PackedFloat64Array([u*float(Config.COLS),v*float(Config.ROWS)])

static func inverse(pixel: Vector2) -> Vector2:
	var values := _inverse_values(pixel)
	return Vector2(values[0],values[1])

static func _cell_from_grid(grid_x: float, grid_y: float) -> Vector2i:
	# No epsilon, clamp or nearest-cell fallback: the logical domain is half open.
	if not is_finite(grid_x) or not is_finite(grid_y): return INVALID_CELL
	if grid_x<0.0 or grid_y<0.0 or grid_x>=Config.COLS or grid_y>=Config.ROWS: return INVALID_CELL
	return Vector2i(floori(grid_x),floori(grid_y))

static func cell_at(pixel: Vector2) -> Vector2i:
	if not pixel.is_finite(): return INVALID_CELL
	var top_y := point(Vector2.ZERO).y
	var bottom_y := point(Vector2(0,Config.ROWS)).y
	if pixel.y<top_y or pixel.y>=bottom_y: return INVALID_CELL
	var values := _inverse_values(pixel)
	var grid_x := values[0]
	var grid_y := values[1]
	if not is_finite(grid_x) or not is_finite(grid_y): return INVALID_CELL
	# A standard Godot Vector2 stores single-precision pixels. Compare against the
	# very same representable lines we draw, not a wide tolerance around them.
	# This makes exact drawn boundaries deterministic without admitting an outer
	# rim or clamping an actual outside point into the nearest playable cell.
	var nearest_y := roundi(grid_y)
	if nearest_y>=0 and nearest_y<=Config.ROWS and pixel.y==point(Vector2(0,nearest_y)).y:
		grid_y=float(nearest_y)
	var x_edges := Vector2(_screen_x(0,grid_y),_screen_x(Config.COLS,grid_y))
	if pixel.x<x_edges.x or pixel.x>=x_edges.y: return INVALID_CELL
	var nearest_x := roundi(grid_x)
	if nearest_x>=0 and nearest_x<=Config.COLS and pixel.x==Vector2(_screen_x(nearest_x,grid_y),0).x:
		grid_x=float(nearest_x)
	return _cell_from_grid(grid_x,grid_y)

static func polygon(cell: Vector2i, inset := 0.035) -> PackedVector2Array:
	var at := Vector2(cell)
	return PackedVector2Array([
		point(at+Vector2(inset,inset)),
		point(at+Vector2(1.0-inset,inset)),
		point(at+Vector2(1.0-inset,1.0-inset)),
		point(at+Vector2(inset,1.0-inset))])

static func depth_scale(grid: Vector2) -> float:
	var denominator := _denominator(grid.y)
	if not grid.is_finite() or not is_finite(denominator) or denominator<=0.0: return NAN
	return FAR_NEAR_RATIO/denominator
