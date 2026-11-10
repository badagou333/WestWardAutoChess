extends SceneTree
## 07 independent real-Viewport mirror symmetry probe (D-20261110-004).
## Renders all 98 source indices in both facings on the plain review background
## and compares original pixel (x,y) with mirrored pixel (1439-x,y) over the
## WHOLE stage below the UI (y 140..809, x 0..1439), stricter than the author
## region. Controls: (a) original rendered twice (determinism); (b) the same
## comparison with NEAREST texture filtering, to test the author's claim that
## the 1/255 residue comes from bilinear interpolation rounding.
## Also renders the board view and checks the foot cell diamond is unchanged.
## No OS input, no listening, no offline compositing.
const SIZE := Vector2i(1440, 810)
const Y0 := 140
var output := ""
var scene
var report := {}
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	call_deferred("run")

func check(ok: bool, msg: String) -> void:
	checks += 1
	if not ok:
		failures.append(msg)
		push_error("QA07 FAIL: " + msg)

func render() -> Image:
	scene.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img

func cmp_reflect(a: Image, b: Image) -> Dictionary:
	var da := a.get_data()
	var db := b.get_data()
	var diff_px := 0
	var max_d := 0
	var hist := {}
	var differs_unreflected := 0
	var nonbg := 0
	var bg := a.get_pixel(5, SIZE.y - 5)
	var bg8 := [bg.r8, bg.g8, bg.b8]
	for y in range(Y0, SIZE.y):
		for x in SIZE.x:
			var ia := (y * SIZE.x + x) * 4
			var ib := (y * SIZE.x + (SIZE.x - 1 - x)) * 4
			var d := 0
			var du := 0
			for c in 3:
				d = maxi(d, absi(int(da[ia + c]) - int(db[ib + c])))
				du = maxi(du, absi(int(da[ia + c]) - int(db[ia + c])))
			if d > 0:
				diff_px += 1
				hist[d] = int(hist.get(d, 0)) + 1
			max_d = maxi(max_d, d)
			if du > 0: differs_unreflected += 1
			if int(da[ia]) != bg8[0] or int(da[ia + 1]) != bg8[1] or int(da[ia + 2]) != bg8[2]: nonbg += 1
	return {"diff_px": diff_px, "max_8bit": max_d, "hist": hist, "differs_unreflected": differs_unreflected, "character_px": nonbg}

func cmp_same(a: Image, b: Image) -> int:
	var da := a.get_data()
	var db := b.get_data()
	var n := 0
	for i in range(Y0 * SIZE.x * 4, da.size(), 4):
		if da[i] != db[i] or da[i + 1] != db[i + 1] or da[i + 2] != db[i + 2]: n += 1
	return n

func sweep(label: String) -> Dictionary:
	var per := []
	var tot_px := 0
	var idx_with := 0
	var max_d := 0
	var min_unrefl := 1 << 30
	var min_char := 1 << 30
	var hist := {}
	for i in 98:
		scene.set_facing(1)
		scene.inspect_frame(i)
		var a: Image = await render()
		scene.set_facing(-1)
		var b: Image = await render()
		var r := cmp_reflect(a, b)
		r["index"] = i
		per.append(r)
		tot_px += r.diff_px
		if r.diff_px > 0: idx_with += 1
		max_d = maxi(max_d, r.max_8bit)
		min_unrefl = mini(min_unrefl, r.differs_unreflected)
		min_char = mini(min_char, r.character_px)
		for k in r.hist: hist[k] = int(hist.get(k, 0)) + int(r.hist[k])
	scene.set_facing(1)
	return {"label": label, "indices_with_diff": idx_with, "total_diff_px": tot_px, "max_8bit": max_d,
		"hist": hist, "min_px_differs_unreflected": min_unrefl, "min_character_px": min_char, "per_index": per}

func run() -> void:
	scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	check(scene.ready_to_play, "scene ready")
	check(Vector2i(root.get_texture().get_size()) == SIZE, "viewport 1440x810")
	report["renderer"] = RenderingServer.get_video_adapter_name() + " / " + RenderingServer.get_current_rendering_driver_name()
	scene.review_plain_background = true
	# (a) determinism control
	scene.inspect_frame(31)
	var r1: Image = await render()
	var r2: Image = await render()
	report["determinism_index31_diff_px"] = cmp_same(r1, r2)
	check(report.determinism_index31_diff_px == 0, "original render deterministic")
	# main sweep (production LINEAR/default filter)
	var lin: Dictionary = await sweep("default_filter")
	report["default_filter"] = lin
	check(lin.max_8bit <= 1, "mirror residue bounded to 1/255 (max %d)" % lin.max_8bit)
	check(lin.min_px_differs_unreflected > 1000, "mirror actually flips every index (min %d px differ from unreflected)" % lin.min_px_differs_unreflected)
	check(lin.min_character_px > 1000, "character present in every index")
	# (b) NEAREST control
	scene.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var nea: Dictionary = await sweep("nearest_filter_control")
	report["nearest_filter_control"] = nea
	scene.texture_filter = CanvasItem.TEXTURE_FILTER_PARENT_NODE
	# board view foot cell: diamond overlay is drawn in world space and must not flip
	scene.review_plain_background = false
	scene.inspect_frame(0)
	scene.set_facing(1)
	var bo: Image = await render()
	scene.set_facing(-1)
	var bm: Image = await render()
	if output != "":
		DirAccess.make_dir_recursive_absolute(output)
		bo.save_png(output.path_join("board-original-index000.png"))
		bm.save_png(output.path_join("board-mirrored-index000.png"))
		bo.get_region(Rect2i(600, 260, 240, 240)).save_png(output.path_join("crop-original-index000.png"))
		bm.get_region(Rect2i(600, 260, 240, 240)).save_png(output.path_join("crop-mirrored-index000.png"))
	# pixel at far-from-character board area must be identical in both facings
	var same_board := 0
	for p in [Vector2i(100, 700), Vector2i(1300, 700), Vector2i(600, 441), Vector2i(840, 441), Vector2i(720, 520)]:
		if bo.get_pixelv(p) == bm.get_pixelv(p): same_board += 1
	report["board_probe_points_identical"] = same_board
	check(same_board == 5, "board & foot diamond unchanged by facing (%d/5)" % same_board)
	report["checks"] = checks
	report["failures"] = failures
	if output != "":
		var slim := report.duplicate(true)
		var f := FileAccess.open(output.path_join("render-report.json"), FileAccess.WRITE)
		f.store_string(JSON.stringify(slim, "  "))
		f.close()
	print("QA07_C03_MIRROR_RENDER %d checks / %d failures | default: %d idx %d px max %d hist %s | nearest: %d idx %d px max %d | det %d" % [checks, failures.size(),
		lin.indices_with_diff, lin.total_diff_px, lin.max_8bit, str(lin.hist), nea.indices_with_diff, nea.total_diff_px, nea.max_8bit, report.determinism_index31_diff_px])
	for f in failures: print("  FAIL ", f)
	quit(0 if failures.is_empty() else 1)
