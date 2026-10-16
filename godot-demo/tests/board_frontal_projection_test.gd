extends SceneTree
## Exact geometric checks for the non-skewed 45-degree presentation.
## Deliberately independent of combat, textures, animation and OS input.
const GroundProjection = preload("res://scripts/presentation/board_depth_projection.gd")
const Config = preload("res://scripts/data/board_trial_config.gd")
var checks := 0
var failures: Array[String] = []
var max_roundtrip_error := 0.0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func _initialize() -> void:
	check(GroundProjection.U.y == 0.0 and GroundProjection.V.x == 0.0,"X horizontal and Y vertical: no skew or board rotation")
	check(is_equal_approx(GroundProjection.V.length()/GroundProjection.U.length(),sin(PI/4)),"ground depth uses exactly sin(45 degrees)")
	check(GroundProjection.U.x>0 and GroundProjection.V.y>0,"axes preserve left-to-right and far-to-near ordering")
	var safe_rect := Rect2(218,160,1336,746)
	for y in range(Config.ROWS):
		for x in range(Config.COLS):
			var cell := Vector2i(x,y)
			var center := GroundProjection.center(cell)
			check(GroundProjection.cell_at(center)==cell,"all 84 cell centers pick themselves "+str(cell))
			var polygon := GroundProjection.polygon(cell)
			check(Geometry2D.is_point_in_polygon(center,polygon),"inset tile contains center "+str(cell))
			check(polygon[0].y==polygon[1].y and polygon[3].y==polygon[2].y and polygon[0].x==polygon[3].x and polygon[1].x==polygon[2].x,"tile edges have no residual slant "+str(cell))
			for fy in [.001,.125,.5,.875,.999]:
				for fx in [.001,.125,.5,.875,.999]:
					var grid := Vector2(cell)+Vector2(fx,fy)
					var pixel := GroundProjection.point(grid)
					var error := GroundProjection.inverse(pixel).distance_to(grid)
					max_roundtrip_error=maxf(max_roundtrip_error,error)
					check(error<0.000002,"fractional projection inverse "+str(grid))
					check(GroundProjection.cell_at(pixel)==cell,"25 distributed interior picks per cell "+str(grid))
					check(safe_rect.has_point(pixel),"playable tile avoids HUD safe margins "+str(grid))
	for y in range(Config.ROWS+1):
		var left := GroundProjection.point(Vector2(0,y))
		var right := GroundProjection.point(Vector2(Config.COLS,y))
		check(left.y==right.y,"every full row stays horizontal "+str(y))
	for x in range(Config.COLS+1):
		var far := GroundProjection.point(Vector2(x,0))
		var near := GroundProjection.point(Vector2(x,Config.ROWS))
		check(far.x==near.x,"every full column stays vertical "+str(x))
	for grid in [Vector2(-.001,3),Vector2(12,3),Vector2(3,-.001),Vector2(3,7),Vector2(12.001,7.001)]:
		check(GroundProjection.cell_at(GroundProjection.point(grid))==Vector2i(-1,-1),"outside rectangle is not playable "+str(grid))
	check(GroundProjection.cell_at(GroundProjection.point(Vector2(0,3))+Vector2(-20,0))==Vector2i(-1,-1),"left trim is not a legal tile")
	check(GroundProjection.cell_at(GroundProjection.point(Vector2(6,7))+Vector2(0,20))==Vector2i(-1,-1),"front fascia is not a legal tile")
	check(GroundProjection.cell_at(GroundProjection.ORIGIN)==Vector2i.ZERO,"top-left boundary is inclusive")
	var bottom_step := GroundProjection.point(Vector2(7.3,7.84))+Vector2(0,40)
	check(bottom_step.y<918,"lowest stair clears status text and roster")
	var report := {"checks":checks,"failures":failures,"cells":84,"interior_samples_per_cell":25,"camera_pitch_degrees":GroundProjection.CAMERA_PITCH_DEGREES,"origin":[GroundProjection.ORIGIN.x,GroundProjection.ORIGIN.y],"u":[GroundProjection.U.x,GroundProjection.U.y],"v":[GroundProjection.V.x,GroundProjection.V.y],"max_roundtrip_error":max_roundtrip_error,"OS_input_verified":false}
	var output := "/tmp/board-frontal-projection.json"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output=argument.trim_prefix("--output=")
	var file := FileAccess.open(output,FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(report,"\t"))
	print("FRONTAL_PROJECTION ",checks," checks / ",failures.size()," failures; ",output)
	quit(0 if failures.is_empty() else 1)
