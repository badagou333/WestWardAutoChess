extends SceneTree
## Headless outward-facing regression: normals AND clockwise winding are checked
## against world-space exterior directions, not merely against one another.
const Builder = preload("res://world_builder.gd")
const REPORT_PATH := "res://reports/geometry.json"
const AREA_EPSILON := 1.0e-10

func _initialize() -> void:
	var parent := Node3D.new()
	root.add_child(parent)
	var material := Builder.mat("808080")
	var block := Builder.stone(parent, Vector3.ZERO, Vector3(2, 1, 2), material, 0.08)
	var tile := Builder.stone(parent, Vector3.ZERO, Vector3(1.17, 0.16, 1.17), material, 0.08)
	var rng := RandomNumberGenerator.new()
	rng.seed = 492861
	Builder.landform(parent, rng)
	var land := parent.get_child(2) as MeshInstance3D
	var stone_rock := Builder.rock(parent, Vector3.ZERO, Vector3.ONE, material, rng)
	var checks: Array[Dictionary] = []
	checks.append(inspect("stone_block", block.mesh, "stone", 0, true))
	checks.append(inspect("stone_tile", tile.mesh, "stone", 0, true))
	checks.append(inspect("landform", land.mesh, "landform", 0, true))
	# SphereMesh's latitude/longitude poles contain 14 zero-area triangles.
	# These cannot define winding; count them explicitly, do not silently pass them.
	checks.append(inspect("rock", stone_rock.mesh, "rock", 14, false))
	var reverse_winding := inspect("negative_reverse_winding", block.mesh, "stone", 0, true, true, false)
	var reverse_normals := inspect("negative_reverse_normals", block.mesh, "stone", 0, true, false, true)
	var reverse_both := inspect("negative_reverse_both", block.mesh, "stone", 0, true, true, true)
	var negative_controls := {
		"reversed_winding_rejected": not reverse_winding["passed"],
		"reversed_normals_rejected": not reverse_normals["passed"],
		"both_reversed_rejected": not reverse_both["passed"]
	}
	var passed := true
	for check in checks: passed = passed and check["passed"]
	for value in negative_controls.values(): passed = passed and value
	var report := {
		"schema": 1,
		"godot": Engine.get_version_info()["string"],
		"builder_sha256": FileAccess.get_sha256("res://world_builder.gd"),
		"seed": 492861,
		"passed": passed,
		"checks": checks,
		"negative_controls": negative_controls,
		"method": "Actual generated mesh arrays. Godot clockwise front = -(b-a).cross(c-a). Independent exterior: +Y on top fans; radial XZ on block/landform sides; radial XYZ on sphere-derived rock. All actual vertex normals independently point exterior. Flat faces additionally agree with their own clockwise geometric normal.",
		"scope": "Headless geometry only; no GPU render, screenshot, lighting quality, gameplay, or visual acceptance. Rock pole degenerates are explicitly counted."
	}
	var folder := ProjectSettings.globalize_path("res://reports")
	DirAccess.make_dir_recursive_absolute(folder)
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write " + REPORT_PATH)
		quit(2)
		return
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()
	print(JSON.stringify(report))
	quit(0 if passed else 1)

func inspect(label: String, mesh: Mesh, kind: String, expected_degenerate: int, require_flat: bool, flip_winding: bool = false, flip_normals: bool = false) -> Dictionary:
	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices := PackedInt32Array()
	if arrays[Mesh.ARRAY_INDEX] != null: indices = arrays[Mesh.ARRAY_INDEX]
	var count: int = indices.size() if not indices.is_empty() else vertices.size()
	var valid := 0
	var degenerate := 0
	var winding_fail := 0
	var normal_fail := 0
	var flat_fail := 0
	var min_winding_dot := 1.0
	var min_normal_dot := 1.0
	var min_flat_dot := 1.0
	var failures: Array[Dictionary] = []
	for offset in range(0, count, 3):
		var ids: Array[int] = []
		for k in range(3): ids.append(indices[offset + k] if not indices.is_empty() else offset + k)
		if flip_winding:
			var swap: int = ids[1]
			ids[1] = ids[2]
			ids[2] = swap
		var a: Vector3 = vertices[ids[0]]
		var b: Vector3 = vertices[ids[1]]
		var c: Vector3 = vertices[ids[2]]
		var cross: Vector3 = -(b - a).cross(c - a)
		if cross.length_squared() < AREA_EPSILON:
			degenerate += 1
			continue
		valid += 1
		var centroid: Vector3 = (a + b + c) / 3.0
		var geometric_normal := cross.normalized()
		var expected := exterior_direction(kind, a, b, c, centroid)
		var winding_dot: float = geometric_normal.dot(expected)
		min_winding_dot = minf(min_winding_dot, winding_dot)
		var normals_ok := true
		var flat_ok := true
		for index in ids:
			var normal: Vector3 = normals[index] * (-1.0 if flip_normals else 1.0)
			var dot: float = normal.dot(expected)
			var flat_dot: float = normal.dot(geometric_normal)
			min_normal_dot = minf(min_normal_dot, dot)
			min_flat_dot = minf(min_flat_dot, flat_dot)
			normals_ok = normals_ok and dot > 0.05 and absf(normal.length() - 1.0) < 0.001
			flat_ok = flat_ok and flat_dot > 0.999
		if winding_dot <= 0.05: winding_fail += 1
		if not normals_ok: normal_fail += 1
		if require_flat and not flat_ok: flat_fail += 1
		if failures.size() < 8 and (winding_dot <= 0.05 or not normals_ok or (require_flat and not flat_ok)):
			failures.append({"triangle": offset / 3, "center": [centroid.x, centroid.y, centroid.z], "winding_outward_dot": winding_dot, "normals_outward": normals_ok, "flat": flat_ok})
	return {
		"name": label, "triangles": count / 3, "nondegenerate": valid,
		"degenerate": degenerate, "expected_degenerate": expected_degenerate,
		"winding_inward_or_tangent": winding_fail, "normals_inward_or_invalid": normal_fail,
		"flat_required": require_flat, "flat_failures": flat_fail,
		"min_winding_exterior_dot": min_winding_dot, "min_normal_exterior_dot": min_normal_dot,
		"min_normal_geometric_dot": min_flat_dot,
		"passed": valid > 0 and degenerate == expected_degenerate and winding_fail == 0 and normal_fail == 0 and flat_fail == 0,
		"failures": failures
	}

func exterior_direction(kind: String, a: Vector3, b: Vector3, c: Vector3, centroid: Vector3) -> Vector3:
	if kind == "rock": return centroid.normalized()
	# Both block and landform top caps are fans about an independent central point.
	# This classification uses vertex positions, never the generated normal/winding.
	for p: Vector3 in [a, b, c]:
		if Vector2(p.x, p.z).length_squared() < 1.0e-10: return Vector3.UP
	return Vector3(centroid.x, 0, centroid.z).normalized()
