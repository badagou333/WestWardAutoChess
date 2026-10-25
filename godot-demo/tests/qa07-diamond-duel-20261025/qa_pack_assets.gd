extends SceneTree
## 07 independent final-PCK resource check. Run with --main-pack and an absolute
## script path from an empty cwd; compares packed textures against the approved
## candidate-decoded RGBA table and rejects loose source/candidate/test fallback.
const ART := "res://art/runtime/diamond_duel_v1/"
const SCENE := "res://scenes/diamond_duel.tscn"
var checks := 0
var failures: Array[String] = []
var failed_samples := 0
var expected_path := ""
var source_manifest := ""
var output := "/tmp/qa07-duel-20261025/pack-assets.json"

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		if failed_samples < 25:
			failed_samples += 1
			push_error(label)

func sha(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
		elif argument.begins_with("--expected="): expected_path = argument.trim_prefix("--expected=")
		elif argument.begins_with("--source-manifest="): source_manifest = argument.trim_prefix("--source-manifest=")
	print("PACK_ASSETS phase expectations")
	check(expected_path != "" and FileAccess.file_exists(expected_path), "candidate-decoded expectation table is readable")
	var expected = JSON.parse_string(FileAccess.get_file_as_string(expected_path))
	print("PACK_ASSETS parsed expectation")
	check(expected is Dictionary and expected.get("failures",[]) == [], "independent asset expectation table itself passed")
	if not expected is Dictionary:
		quit(1)
		return
	print("PACK_ASSETS phase pack flags")
	check(OS.has_feature("diamond_duel"), "packed feature tag is diamond_duel")
	check(ProjectSettings.get_setting_with_override("application/run/main_scene") == SCENE, "pack default entry is the independent diamond scene")
	check(not FileAccess.file_exists("res://scripts/diamond_duel.gd"), "pack has no loose production source fallback")
	check(not FileAccess.file_exists("res://tests/diamond_duel_test.gd"), "pack has no test scripts")
	check(not FileAccess.file_exists("res://art/candidates/rect_iso_duel_v1/manifest.json"), "source candidate is not packed")
	check(not FileAccess.file_exists("res://art/candidates/rect_iso_duel_v1/frames/monk_se_idle.png"), "source candidate frames are not packed")
	check(not FileAccess.file_exists("res://art/reviews/foxfire-3d-board-v1/project.godot"), "independent 3D project is not packed")
	check(FileAccess.file_exists(ART + "manifest.json"), "runtime manifest is packed")
	print("PACK_ASSETS phase manifest")
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(ART + "manifest.json"))
	check(manifest is Dictionary and manifest.get("schema") == "diamond-duel-runtime-v1", "packed manifest schema")
	if not manifest is Dictionary:
		quit(1)
		return
	check(manifest.get("frames",[]).size() == 17 and expected.assets.size() == 17, "seventeen approved frames in manifest and expectation table")
	check(expected.get("failures",[]) == [], "source-imported expectation table itself was clean")
	if source_manifest != "" and FileAccess.file_exists(source_manifest):
		var source = JSON.parse_string(FileAccess.get_file_as_string(source_manifest))
		check(source is Dictionary and source == manifest, "packed manifest equals the complete source adapter manifest")
	else:
		check(false, "source manifest path was supplied and readable")
	var seen := {}
	print("PACK_ASSETS phase frames")
	for row in expected.assets:
		var id := str(row.id)
		check(not seen.has(id), "unique packed frame id "+id)
		seen[id] = true
		var path := ART + str(row.image)
		check(ResourceLoader.exists(path), "packed frame resource exists "+id)
		if not ResourceLoader.exists(path): continue
		var texture: Texture2D = load(path)
		check(texture != null, "packed texture loads "+id)
		if texture == null: continue
		var image: Image = texture.get_image()
		image.convert(Image.FORMAT_RGBA8)
		var decoded := sha(image.get_data())
		check(int(texture.get_size().x) == int(row["size"][0]) and int(texture.get_size().y) == int(row["size"][1]), "packed texture keeps source imported dimensions "+id)
		check(decoded == str(row.rgba_sha), "packed RGBA equals the source-imported texture RGBA "+id)
		check(not FileAccess.file_exists(path), "packed frame has no loose PNG fallback "+id)
	print("PACK_ASSETS phase rejected")
	# The three rejected poses must not exist even as imported resources.
	for id in ["monk_ne_move_b","wolf_se_move_b","wolf_ne_move_b"]:
		check(not FileAccess.file_exists(ART+"frames/"+id+".png"), "rejected pose absent from pack "+id)
		check(not ResourceLoader.exists(ART+"frames/"+id+".png"), "rejected pose not loadable from pack "+id)
	var report := {"scope":"07 independent D002 final-PCK resources","checks":checks,"failures":failures,
		"frames":seen.size(),"feature":OS.has_feature("diamond_duel"),
		"main_scene":ProjectSettings.get_setting_with_override("application/run/main_scene"),
		"source_candidate_packed":FileAccess.file_exists("res://art/candidates/rect_iso_duel_v1/manifest.json"),
		"tests_packed":FileAccess.file_exists("res://tests/diamond_duel_test.gd"),
		"3d_packed":FileAccess.file_exists("res://art/reviews/foxfire-3d-board-v1/project.godot")}
	var file := FileAccess.open(output,FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(report,"\t"))
	print("QA07_PACK_ASSETS checks=",checks," failures=",failures.size()," frames=",seen.size()," out=",output)
	quit(1 if failures else 0)

func pair(value: Vector2) -> Array:
	return [int(value.x),int(value.y)]
