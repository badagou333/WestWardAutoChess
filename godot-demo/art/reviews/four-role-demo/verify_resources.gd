extends SceneTree

func _init() -> void:
	var total := 0
	var failures: Array[String] = []
	for role in ["wild_hunter", "herbal_spirit_child", "sparrow_spirit", "bear_lord"]:
		var base: String = "res://art/production/" + role + "/demo_v1/"
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(base + "manifest.json"))
		var files: Array = [manifest.atlases.body, manifest.atlases.vfx]
		for frame in manifest.frames:
			files.append(frame.file)
		for effect in manifest.standalone_vfx.values():
			files.append(effect.file)
			files.append(effect.aligned_file)
		for file in files:
			var img := Image.load_from_file(base + file)
			if img == null or img.is_empty() or img.get_format() != Image.FORMAT_RGBA8:
				failures.append(base + file)
			else:
				var tex := ImageTexture.create_from_image(img)
				if tex.get_size() != Vector2(img.get_size()):
					failures.append("Texture dimensions: " + file)
			total += 1
	var result := {"engine": Engine.get_version_info().string, "runtime_pngs_loaded": total, "failures": failures, "scope": "Godot image and texture loading only; no battle integration or visual approval"}
	var out := FileAccess.open("res://art/reviews/four-role-demo/godot-validation.json", FileAccess.WRITE)
	out.store_string(JSON.stringify(result, "\t") + "\n")
	print("FOUR_ROLE_GODOT_LOAD: pngs=%d failures=%d" % [total, failures.size()])
	quit(0 if failures.is_empty() else 1)
