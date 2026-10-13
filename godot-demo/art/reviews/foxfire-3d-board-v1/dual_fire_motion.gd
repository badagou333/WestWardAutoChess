extends RefCounted

# Small upper-body animation patch; the original textured model is never duplicated.
# Values are Blender's official glTF export TRS, not Euler guesses in Godot space.
const BASE_SHA256 := "4257ac78a80ade3bbd328212c9341ecf9f775a7a8452aef7f8a2fc0875cfaa57"
const ARM_BONES := ["clavicle.L", "upper_arm.L", "forearm.L", "hand.L", "clavicle.R", "upper_arm.R", "forearm.R", "hand.R"]
const REQUIRED_BONES := ["upper_arm.L", "forearm.L", "hand.L", "upper_arm.R", "forearm.R", "hand.R"]

static func install(player: AnimationPlayer, idle: StringName, run: StringName) -> Dictionary:
	var source := "res://assets/dual-fire-animations.json"
	if not FileAccess.file_exists(source):
		return {"error": "缺少托火动作数据"}
	if FileAccess.get_sha256("res://assets/foxfire-board.glb") != BASE_SHA256:
		return {"error": "托火动作只适用于已验证的狐火骨架，模型版本不匹配"}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(source))
	if not parsed is Dictionary or not parsed.get("clips") is Dictionary:
		return {"error": "托火动作文件格式无效"}
	for side in ["L", "R"]:
		var palm: Dictionary = parsed.get("palm_offsets", {}).get(side, {})
		var orb: Dictionary = parsed.get("orbs", {}).get(side, {})
		if palm.get("bone", "") != "hand." + side or not palm.get("position") is Array or palm.position.size() != 3:
			return {"error": "双火缺少有效的独立手部挂点：" + side}
		if float(orb.get("core_radius", 0.0)) <= 0.0 or float(orb.get("up_offset", -1.0)) < 0.0:
			return {"error": "双火尺寸或掌上偏移无效：" + side}
	var library := AnimationLibrary.new()
	parsed["runtime_seam_repairs"] = {}
	for name in ["DualFireIdle", "DualFireRun"]:
		var data: Dictionary = parsed.clips.get(name, {})
		var base := player.get_animation(idle if name == "DualFireIdle" else run)
		if data.is_empty() or not data.get("tracks") is Array or base == null:
			return {"error": "托火动作或基础动作缺失：" + name}
		var clip := base.duplicate(true) as Animation
		parsed.runtime_seam_repairs[name] = _normalize_time(clip, float(parsed.get("source_time_offset", 0.0)), float(data.get("duration", 0.0)))
		var bone_paths: Dictionary = {}
		for index in range(clip.get_track_count()):
			var path := clip.track_get_path(index)
			if path.get_subname_count() == 1:
				bone_paths[str(path.get_subname(0))] = path
		var seen: Array[String] = []
		for track in data.tracks:
			var bone := str(track.get("bone", ""))
			var property := str(track.get("path", ""))
			if not ARM_BONES.has(bone) or not bone_paths.has(bone):
				return {"error": "拒绝覆盖非肩臂骨骼或未知骨骼：" + bone}
			if property not in ["rotation", "translation", "scale"]:
				return {"error": "未知托火轨道类型：" + property}
			var times: Array = track.get("times", [])
			var values: Array = track.get("values", [])
			if times.is_empty() or times.size() != values.size():
				return {"error": "托火轨道时间与姿势数不一致"}
			var type := Animation.TYPE_ROTATION_3D if property == "rotation" else (Animation.TYPE_SCALE_3D if property == "scale" else Animation.TYPE_POSITION_3D)
			var index := clip.find_track(bone_paths[bone], type)
			if index >= 0:
				clip.remove_track(index)
			index = clip.add_track(type)
			clip.track_set_path(index, bone_paths[bone])
			clip.track_set_interpolation_type(index, Animation.INTERPOLATION_NEAREST if str(track.get("interpolation", "LINEAR")) == "STEP" else Animation.INTERPOLATION_LINEAR)
			var last_time := -1.0
			for key in range(times.size()):
				var value: Array = values[key]
				var key_time := float(times[key])
				if key_time <= last_time or value.size() != (4 if property == "rotation" else 3):
					return {"error": "托火轨道包含无效关键帧"}
				last_time = key_time
				if property == "rotation":
					var q := Quaternion(value[0], value[1], value[2], value[3])
					if absf(q.length_squared() - 1.0) > 0.001:
						return {"error": "托火旋转未归一化"}
					clip.rotation_track_insert_key(index, key_time, q.normalized())
				elif property == "translation":
					clip.position_track_insert_key(index, key_time, Vector3(value[0], value[1], value[2]))
				else:
					clip.scale_track_insert_key(index, key_time, Vector3(value[0], value[1], value[2]))
			if property == "rotation" and not seen.has(bone):
				seen.append(bone)
		if not REQUIRED_BONES.all(func(bone): return seen.has(bone)) or float(data.get("duration", 0)) <= 0:
			return {"error": "托火动作不完整"}
		clip.length = float(data.duration)
		clip.loop_mode = Animation.LOOP_LINEAR
		library.add_animation(name, clip)
	player.add_animation_library("dual_fire", library)
	return {"idle": &"dual_fire/DualFireIdle", "run": &"dual_fire/DualFireRun", "data": parsed}

static func _normalize_time(clip: Animation, offset: float, duration: float) -> Array:
	# Blender's frame 1 starts at 1/30 s in the source GLB. Godot adds a key at
	# zero and may optimize constant tracks to a single key. Resample the exact
	# new first value, then shift later keys, removing that synthetic lead-in.
	var repairs: Array = []
	for index in range(clip.get_track_count()):
		var initial
		match clip.track_get_type(index):
			Animation.TYPE_ROTATION_3D: initial = clip.rotation_track_interpolate(index, offset)
			Animation.TYPE_POSITION_3D: initial = clip.position_track_interpolate(index, offset)
			Animation.TYPE_SCALE_3D: initial = clip.scale_track_interpolate(index, offset)
			_: continue
		var later: Array = []
		for key in range(clip.track_get_key_count(index)):
			var time := clip.track_get_key_time(index, key) - offset
			if time > 0.000001:
				later.append([minf(time, duration), clip.track_get_key_value(index, key)])
		for key in range(clip.track_get_key_count(index) - 1, -1, -1):
			clip.track_remove_key(index, key)
		clip.track_insert_key(index, 0.0, initial)
		for key in later:
			clip.track_insert_key(index, key[0], key[1])
		# Godot optimized away the original Idle root's held lead-in key. Cutting
		# that interval introduces a 0.000094 model-unit seam. Close only this
		# root-position seam, record the sub-millimetre repair, never hide it as
		# an unchanged source curve or loosen the whole-skeleton comparison.
		var path := clip.track_get_path(index)
		if clip.track_get_type(index) == Animation.TYPE_POSITION_3D and path.get_subname_count() == 1 and path.get_subname(0) == "root" and later.size() > 0:
			var endpoint: Vector3 = clip.track_get_key_value(index, clip.track_get_key_count(index) - 1)
			var correction: Vector3 = endpoint - initial
			if correction.length() > 0.000001 and correction.length() < 0.00012:
				clip.track_set_key_value(index, 0, endpoint)
				repairs.append({"path": str(path), "delta": [correction.x, correction.y, correction.z], "until": clip.track_get_key_time(index, 1)})
	return repairs
