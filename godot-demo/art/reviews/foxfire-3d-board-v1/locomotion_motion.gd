extends RefCounted

static func install(player: AnimationPlayer, base_run: StringName) -> Dictionary:
	var source := "res://assets/locomotion-animations.json"
	if not FileAccess.file_exists(source):
		return {"error": "新移动动作数据缺失"}
	var data = JSON.parse_string(FileAccess.get_file_as_string(source))
	if not data is Dictionary or data.get("base_glb_sha256") != FileAccess.get_sha256("res://assets/foxfire-board.glb"):
		return {"error": "移动数据与模型版本不匹配"}
	var raw: Dictionary = data.get("clips", {}).get("NaturalRun", {})
	var duration := float(raw.get("duration", 0))
	if duration <= 0 or not raw.get("tracks") is Array:
		return {"error": "移动动作缺失或时长无效"}
	var paths: Dictionary = {}
	var base := player.get_animation(base_run)
	for index in range(base.get_track_count()):
		var path := base.track_get_path(index)
		if path.get_subname_count() == 1:
			paths[str(path.get_subname(0))] = path
	for bone in ["root", "foot.L", "foot.R"]:
		if not paths.has(bone):
			return {"error": "移动接地缺少根骨或脚骨"}
	var raw_probes = data.get("sole_probes")
	if not raw_probes is Dictionary:
		return {"error": "移动接地缺少双脚足底探针"}
	var sole_probes: Dictionary = {}
	for side in ["L", "R"]:
		var samples = raw_probes.get(side)
		if not samples is Array or samples.is_empty():
			return {"error": "移动接地缺少足底探针：" + side}
		var points: Array[Vector3] = []
		for sample in samples:
			if not sample is Array or sample.size() != 3 or not sample.all(func(value): return value is float or value is int) or not sample.all(func(value): return is_finite(float(value))):
				return {"error": "移动足底探针坐标无效：" + side}
			points.append(Vector3(sample[0], sample[1], sample[2]))
		sole_probes[side] = points
	var clip := Animation.new()
	clip.length = duration
	clip.loop_mode = Animation.LOOP_LINEAR
	var seen: Dictionary = {}
	for entry in raw.tracks:
		var bone := str(entry.get("bone", ""))
		var property := str(entry.get("path", ""))
		var key := bone + "/" + property
		if not paths.has(bone) or property not in ["rotation", "translation", "scale"] or seen.has(key):
			return {"error": "移动动作未知/重复轨道"}
		seen[key] = true
		var times: Array = entry.get("times", [])
		var values: Array = entry.get("values", [])
		if times.size() < 2 or times.size() != values.size() or absf(float(times[0])) > 0.000001 or absf(float(times[-1]) - duration) > 0.000001:
			return {"error": "移动动作关键帧不完整"}
		var type := Animation.TYPE_ROTATION_3D if property == "rotation" else (Animation.TYPE_POSITION_3D if property == "translation" else Animation.TYPE_SCALE_3D)
		var track := clip.add_track(type)
		clip.track_set_path(track, paths[bone])
		var previous := -1.0
		for i in range(times.size()):
			var time := float(times[i])
			var value: Array = values[i]
			if not is_finite(time) or time <= previous or time < 0 or time > duration + 0.000001 or value.size() != (4 if property == "rotation" else 3):
				return {"error": "移动动画时间/维度无效"}
			previous = time
			for component in value:
				if not is_finite(float(component)):
					return {"error": "移动动作含非有限数值"}
			if property == "rotation":
				var q := Quaternion(value[0], value[1], value[2], value[3])
				if absf(q.length_squared() - 1) > 0.001:
					return {"error": "移动旋转未归一化"}
				clip.rotation_track_insert_key(track, time, q.normalized())
			elif property == "translation":
				clip.position_track_insert_key(track, time, Vector3(value[0], value[1], value[2]))
			else:
				clip.scale_track_insert_key(track, time, Vector3(value[0], value[1], value[2]))
	for bone in paths:
		for property in ["rotation", "translation", "scale"]:
			if not seen.has(bone + "/" + property):
				return {"error": "移动动作缺少完整骨骼姿势"}
	var library := AnimationLibrary.new()
	library.add_animation("NaturalRun", clip)
	player.add_animation_library("locomotion", library)
	player.set_meta("locomotion_sole_probes", sole_probes)
	return {"run": &"locomotion/NaturalRun", "data": data}

static func relax_at_low_speed(skeleton: Skeleton3D, player: AnimationPlayer, idle_name: StringName, speed_fraction: float) -> void:
	# Keep phase continuous but reduce stride as speed tends to zero. This is
	# applied once after each animation evaluation, never repeatedly while paused.
	# Full-speed samples and spell actions remain completely untouched.
	var weight := smoothstep(0.0, 0.5, speed_fraction)
	if weight >= 1.0:
		return
	var idle := player.get_animation(idle_name)
	for track in range(idle.get_track_count()):
		var path := idle.track_get_path(track)
		if path.get_subname_count() != 1:
			continue
		var bone := skeleton.find_bone(path.get_subname(0))
		if bone < 0:
			continue
		match idle.track_get_type(track):
			Animation.TYPE_POSITION_3D:
				skeleton.set_bone_pose_position(bone, idle.position_track_interpolate(track, 0.0).lerp(skeleton.get_bone_pose_position(bone), weight))
			Animation.TYPE_ROTATION_3D:
				skeleton.set_bone_pose_rotation(bone, idle.rotation_track_interpolate(track, 0.0).slerp(skeleton.get_bone_pose_rotation(bone), weight))
			Animation.TYPE_SCALE_3D:
				skeleton.set_bone_pose_scale(bone, idle.scale_track_interpolate(track, 0.0).lerp(skeleton.get_bone_pose_scale(bone), weight))
	if weight <= 0.0:
		return
	ensure_ground_clearance(skeleton, player)

static func ensure_ground_clearance(skeleton: Skeleton3D, player: AnimationPlayer) -> void:
	# Interpolating joint rotations can lower a sole even when both endpoint
	# poses clear the floor. These probes are fully weighted sole vertices in
	# each foot bone's local coordinates; measure the final blended hierarchy.
	skeleton.force_update_all_bone_transforms()
	var probes: Dictionary = player.get_meta("locomotion_sole_probes", {})
	var minimum_y := INF
	for side in ["L", "R"]:
		var foot := skeleton.get_bone_global_pose(skeleton.find_bone("foot." + side))
		for point in probes.get(side, []):
			minimum_y = minf(minimum_y, (foot * point).y)
	# Leave clear poses, including Idle and full Run, exactly unchanged. The
	# tolerance avoids lifting their sub-micrometre floating-point noise.
	if minimum_y < 0.002 - 0.000001:
		var root := skeleton.find_bone("root")
		skeleton.set_bone_pose_position(root, skeleton.get_bone_pose_position(root) + Vector3.UP * (0.002 - minimum_y))
		skeleton.force_update_all_bone_transforms()
