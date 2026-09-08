extends SceneTree

const BASE := "res://art/production/foxfire_imp/demo_v1/"
const OUT := "res://art/reviews/foxfire-layer-review/"
var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func inspect_image(file_name: String, expected: Vector2i) -> Dictionary:
	var img := Image.load_from_file(BASE + file_name)
	check(img != null and not img.is_empty(), "Cannot load: " + file_name)
	if img == null or img.is_empty():
		return {}
	check(img.get_size() == expected, "Unexpected size: " + file_name)
	check(img.get_format() == Image.FORMAT_RGBA8, "Missing RGBA8: " + file_name)
	var occupied := 0
	var opaque := 0
	var border := 0
	var strong := Rect2i()
	var found := false
	var support_min := img.get_width()
	var support_max := -1
	for y in img.get_height():
		for x in img.get_width():
			var alpha := img.get_pixel(x, y).a
			if alpha > 0:
				occupied += 1
				if x == 0 or y == 0 or x == img.get_width()-1 or y == img.get_height()-1:
					border += 1
			if alpha >= 0.99:
				opaque += 1
			if alpha >= 0.1:
				if not found:
					strong = Rect2i(x, y, 1, 1)
					found = true
				else:
					strong = strong.merge(Rect2i(x, y, 1, 1))
	if found:
		for y in range(maxi(0, strong.end.y-6), strong.end.y):
			for x in img.get_width():
				if img.get_pixel(x, y).a >= 0.5:
					support_min = mini(support_min, x)
					support_max = maxi(support_max, x)
	check(border == 0, "Nontransparent border: " + file_name)
	return {"file": file_name, "size": [img.get_width(), img.get_height()], "format": "RGBA8" if img.get_format() == Image.FORMAT_RGBA8 else str(img.get_format()), "nonzero_alpha_pixels": occupied, "opaque_pixels": opaque, "border_pixels": border, "alpha_10_percent_bbox": [strong.position.x,strong.position.y,strong.size.x,strong.size.y], "bottom_six_rows_alpha_50_percent_x_span": [support_min, support_max]}

func _init() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASE + "manifest.json"))
	var rows: Array = []
	var comparisons: Array = []
	for layer in ["body", "vfx"]:
		var atlas_name: String = manifest.atlases[layer]
		rows.append(inspect_image(atlas_name, Vector2i(1536,256)))
		var atlas := Image.load_from_file(BASE + atlas_name)
		for frame in manifest.frames:
			var i := int(frame.index)
			var region := atlas.get_region(Rect2i(i*256,0,256,256))
			if layer == "body" or frame.aligned_vfx:
				var file_name := "foxfire_imp_%s_%s_v1.png" % [frame.name, layer]
				rows.append(inspect_image(file_name, Vector2i(256,256)))
				var single := Image.load_from_file(BASE + file_name)
				var matches := region.get_data() == single.get_data()
				var alpha_differences := 0
				var visible_rgb_differences := 0
				var max_premultiplied_delta := 0.0
				for y in 256:
					for x in 256:
						var a := region.get_pixel(x,y)
						var b := single.get_pixel(x,y)
						if a.a != b.a:
							alpha_differences += 1
						if (a.a > 0 or b.a > 0) and Vector3(a.r,a.g,a.b) != Vector3(b.r,b.g,b.b):
							visible_rgb_differences += 1
						max_premultiplied_delta = maxf(max_premultiplied_delta, maxf(absf(a.r*a.a-b.r*b.a), maxf(absf(a.g*a.a-b.g*b.a),absf(a.b*a.a-b.b*b.a))) * 255.0)
				check(alpha_differences == 0 and max_premultiplied_delta <= 1.0, "Atlas difference exceeds one composited color level: " + file_name)
				comparisons.append({"frame": i, "layer": layer, "byte_identical": matches, "alpha_differences": alpha_differences, "visible_rgb_differences": visible_rgb_differences, "max_premultiplied_delta_255": max_premultiplied_delta})
			else:
				var empty := region.get_used_rect().size == Vector2i.ZERO
				check(empty, "Unexpected VFX: " + str(i))
				comparisons.append({"frame": i, "layer": layer, "empty": empty})
	for effect in manifest.standalone_vfx.values():
		rows.append(inspect_image(effect.file, Vector2i(64,64)))
	var result := {"scope": "Raw PNG structure and atlas identity; not battle integration or visual approval", "files": rows, "atlas_checks": comparisons, "failures": failures}
	var output := FileAccess.open(OUT + "audit-results.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(result, "\t") + "\n")
	print("FOX_LAYER_AUDIT: files=%d atlas_checks=%d failures=%d" % [rows.size(), comparisons.size(), failures.size()])
	quit(0 if failures.is_empty() else 1)
