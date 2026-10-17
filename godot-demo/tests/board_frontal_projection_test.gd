extends SceneTree
## Geometric checks only; no rendered pixels, combat or OS-pointer claims.
const GroundProjection = preload("res://scripts/presentation/board_depth_projection.gd")
const Config = preload("res://scripts/data/board_trial_config.gd")
const INVALID := Vector2i(-1,-1)
var checks := 0
var failures: Array[String] = []
var max_roundtrip_error := 0.0
var shared_edge_samples := 0
var exterior_samples := 0
var collapsed_subpixel_samples := 0

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		push_error(label)

func _outside(grid: Vector2, label: String) -> void:
	exterior_samples+=1
	check(GroundProjection.cell_at(GroundProjection.point(grid))==INVALID,label+" "+str(grid))

func _initialize() -> void:
	var expected_corners := [Vector2(348.16,319.76),Vector2(1408,319.76),Vector2(1522.08,733.76),Vector2(234.08,733.76)]
	var logical_corners := [Vector2(0,0),Vector2(12,0),Vector2(12,7),Vector2(0,7)]
	for index in range(4):
		check(GroundProjection.point(logical_corners[index]).distance_to(expected_corners[index])<0.0002,"05 recommended playable corner "+str(index))
	check(GroundProjection.IMAGE_ORIGIN==Vector2(120,110) and GroundProjection.IMAGE_SCALE==0.92,"one uniform art origin and scale")
	check(GroundProjection.IMAGE_RECT.position==Vector2(120,110) and GroundProjection.IMAGE_RECT.size.distance_to(Vector2(1538.24,865.72))<0.0002,"clean stage image rectangle matches handoff")
	check(Config.COLS==12 and Config.ROWS==7,"display change retains exact 12 by 7 combat board")
	var safe_rect := Rect2(210,150,1340,760)
	var hud_rects := [Rect2(32,20,1856,112),Rect2(26,179,168,732),Rect2(1572,176,314,728),Rect2(220,918,1320,134),Rect2(1572,918,314,130)]
	for y in range(Config.ROWS):
		for x in range(Config.COLS):
			var cell := Vector2i(x,y)
			var center := GroundProjection.center(cell)
			check(GroundProjection.cell_at(center)==cell,"all 84 cell centers pick themselves "+str(cell))
			var polygon := GroundProjection.polygon(cell)
			check(Geometry2D.is_point_in_polygon(center,polygon),"inset tile contains center "+str(cell))
			check(polygon[0].y==polygon[1].y and polygon[3].y==polygon[2].y,"each tile has horizontal near/far edges "+str(cell))
			check(safe_rect.has_point(center),"center remains in interactive safe rectangle "+str(cell))
			for hud in hud_rects: check(not hud.has_point(center),"center avoids every existing HUD envelope "+str(cell))
			for fy in [.001,.125,.5,.875,.999]:
				for fx in [.001,.125,.5,.875,.999]:
					var grid := Vector2(cell)+Vector2(fx,fy)
					var pixel := GroundProjection.point(grid)
					var error := GroundProjection.inverse(pixel).distance_to(grid)
					max_roundtrip_error=maxf(max_roundtrip_error,error)
					check(error<0.000004,"fractional projection inverse "+str(grid))
					check(GroundProjection.cell_at(pixel)==cell,"25 distributed interior picks per cell "+str(grid))
					check(safe_rect.has_point(pixel),"entire playable interior stays clear of HUD "+str(grid))
	# All internal shared lines. 1e-5 logical units is still distinguishable at
	# the largest float32 screen coordinates; a broad pick epsilon would fail.
	for y in range(Config.ROWS):
		for x in range(1,Config.COLS):
			for fraction in [.125,.5,.875]:
				shared_edge_samples+=2
				check(GroundProjection.cell_at(GroundProjection.point(Vector2(x-.00001,y+fraction)))==Vector2i(x-1,y),"shared column line left "+str(Vector2(x,y+fraction)))
				check(GroundProjection.cell_at(GroundProjection.point(Vector2(x+.00001,y+fraction)))==Vector2i(x,y),"shared column line right "+str(Vector2(x,y+fraction)))
	for y in range(1,Config.ROWS):
		for x in range(Config.COLS):
			for fraction in [.125,.5,.875]:
				shared_edge_samples+=2
				check(GroundProjection.cell_at(GroundProjection.point(Vector2(x+fraction,y-.00001)))==Vector2i(x,y-1),"shared row line far "+str(Vector2(x+fraction,y)))
				check(GroundProjection.cell_at(GroundProjection.point(Vector2(x+fraction,y+.00001)))==Vector2i(x,y),"shared row line near "+str(Vector2(x+fraction,y)))
	var previous_width := 0.0
	var previous_spacing := 0.0
	for y in range(Config.ROWS+1):
		var left := GroundProjection.point(Vector2(0,y))
		var right := GroundProjection.point(Vector2(Config.COLS,y))
		var width := right.x-left.x
		check(left.y==right.y,"every full row is level "+str(y))
		check(absf((left.x+right.x)*.5-878.08)<.0002,"each row centered, with no left/right rotation "+str(y))
		check(width>previous_width,"row widths strictly increase toward viewer "+str(y))
		previous_width=width
		if y>0:
			var spacing := left.y-GroundProjection.point(Vector2(0,y-1)).y
			check(spacing>previous_spacing,"row spacing strictly increases toward viewer "+str(y))
			previous_spacing=spacing
	check(GroundProjection.point(Vector2(0,7)).x<GroundProjection.point(Vector2(0,0)).x and GroundProjection.point(Vector2(12,7)).x>GroundProjection.point(Vector2(12,0)).x,"columns follow widening trapezoid, not old vertical grid")
	for y in range(Config.ROWS):
		for fraction in [.001,.25,.5,.75,.999]:
			var row := y+float(fraction)
			_outside(Vector2(-.00001,row),"left outside cannot clamp into a tile")
			_outside(Vector2(12.00001,row),"right outside cannot clamp into a tile")
			check(GroundProjection.cell_at(GroundProjection.point(Vector2(.00001,row)))==Vector2i(0,y),"left-edge interior remains playable")
			check(GroundProjection.cell_at(GroundProjection.point(Vector2(11.99999,row)))==Vector2i(11,y),"right-edge interior remains playable")
	for x in range(Config.COLS):
		for fraction in [.001,.25,.5,.75,.999]:
			var column := x+float(fraction)
			_outside(Vector2(column,-.00001),"far outside cannot clamp into a tile")
			_outside(Vector2(column,7.00001),"near outside cannot clamp into a tile")
			check(GroundProjection.cell_at(GroundProjection.point(Vector2(column,.00001)))==Vector2i(x,0),"far-edge interior remains playable")
			check(GroundProjection.cell_at(GroundProjection.point(Vector2(column,6.99999)))==Vector2i(x,6),"near-edge interior remains playable")
	check(GroundProjection.cell_at(GroundProjection.point(Vector2.ZERO))==Vector2i.ZERO,"top-left exact boundary inclusive")
	for corner in [Vector2(12,0),Vector2(12,7),Vector2(0,7)]: _outside(corner,"right and bottom exact boundaries excluded")
	# Retain strict 1e-7 logical-domain counterexamples in float64. A Vector2
	# screen pixel cannot always carry that displacement: report the loss instead
	# of calling an identical representable point a passing outside click.
	for row in [.5,3.5,6.5]:
		check(GroundProjection._cell_from_grid(-1e-7,row)==INVALID,"1e-7 logical left exterior rejected without epsilon")
		check(GroundProjection._cell_from_grid(1e-7,row)==Vector2i(0,floori(row)),"1e-7 logical left interior not over-rejected")
		check(GroundProjection._cell_from_grid(12.0+1e-7,row)==INVALID,"1e-7 logical right exterior rejected")
		check(GroundProjection._cell_from_grid(12.0-1e-7,row)==Vector2i(11,floori(row)),"1e-7 logical right interior not over-rejected")
		var edge := GroundProjection.point(Vector2(0,row))
		var tiny_outside := GroundProjection.point(Vector2(-1e-7,row))
		if edge==tiny_outside: collapsed_subpixel_samples+=1
		else: check(GroundProjection.cell_at(tiny_outside)==INVALID,"representable 1e-7 left exterior rejected")
	for column in [.5,6.5,11.5]:
		check(GroundProjection._cell_from_grid(column,-1e-7)==INVALID,"1e-7 logical far exterior rejected")
		check(GroundProjection._cell_from_grid(column,1e-7)==Vector2i(floori(column),0),"1e-7 logical far interior not over-rejected")
		check(GroundProjection._cell_from_grid(column,7.0+1e-7)==INVALID,"1e-7 logical near exterior rejected")
		check(GroundProjection._cell_from_grid(column,7.0-1e-7)==Vector2i(floori(column),6),"1e-7 logical near interior not over-rejected")
	# At image y=470 the playable left edge is x=181.316; x=200 is inside.
	# Use x=100 as an unambiguous forest point, retaining all close-edge probes.
	for image_point in [Vector2(242,220),Vector2(1406,220),Vector2(1534,686),Vector2(116,686),Vector2(824,700),Vector2(824,760),Vector2(100,470),Vector2(1540,470)]:
		exterior_samples+=1
		check(GroundProjection.cell_at(GroundProjection.IMAGE_ORIGIN+image_point*GroundProjection.IMAGE_SCALE)==INVALID,"decorative rim/sidewall/stair/forest rejected "+str(image_point))
	for hud in hud_rects: check(GroundProjection.cell_at(hud.get_center())==INVALID,"HUD envelope center not board space")
	for bad_pixel in [Vector2(INF,300),Vector2(300,INF),Vector2(NAN,300),Vector2(300,NAN),Vector2(1e30,-1e30)]:
		check(GroundProjection.cell_at(bad_pixel)==INVALID,"nonfinite or far-out input safely rejected "+str(bad_pixel))
	check(not GroundProjection.inverse(Vector2(NAN,0)).is_finite(),"inverse propagates invalid coordinates rather than legal cell")
	check(not GroundProjection.point(Vector2(INF,0)).is_finite(),"forward safely rejects nonfinite coordinates")
	check(is_equal_approx(GroundProjection.depth_scale(Vector2(6,0)),1152.0/1400.0),"far actor depth multiplier matches stage")
	check(is_equal_approx(GroundProjection.depth_scale(Vector2(6,7)),1.0),"near actor depth multiplier matches stage")
	check(GroundProjection.BODY_NEAR_SCALE==.9,"near actor display base remains 0.9")
	var previous_scale := 0.0
	for index in range(701):
		var grid := Vector2(6,float(index)*.01)
		var scale := GroundProjection.depth_scale(grid)
		check(is_finite(scale) and scale>previous_scale,"continuous strictly increasing actor depth multiplier "+str(index))
		check(absf(scale-GroundProjection.depth_scale(Vector2(0,grid.y)))<1e-12,"depth depends only on ground depth "+str(index))
		previous_scale=scale
	var report := {"checks":checks,"failures":failures,"cells":84,"interior_samples_per_cell":25,"shared_line_side_samples":shared_edge_samples,"exterior_samples":exterior_samples,"projection":"perspective-stage-v1-homography","image_origin":[120,110],"image_scale":.92,"max_roundtrip_error":max_roundtrip_error,"subpixel_quantization_collapsed_samples":collapsed_subpixel_samples,"strict_logical_boundary_delta":1e-7,"OS_input_verified":false,"rendered_pixels_verified":false}
	var output := "/tmp/board-perspective-20261017-geometry.json"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output=argument.trim_prefix("--output=")
	var file := FileAccess.open(output,FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(report,"\t"))
	print("FRONTAL_PROJECTION ",checks," checks / ",failures.size()," failures; ",output)
	quit(0 if failures.is_empty() else 1)
