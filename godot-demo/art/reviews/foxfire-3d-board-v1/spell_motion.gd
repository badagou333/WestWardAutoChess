extends RefCounted

const MODEL_SHA := "4257ac78a80ade3bbd328212c9341ecf9f775a7a8452aef7f8a2fc0875cfaa57"

static func install(player: AnimationPlayer, base_idle: StringName) -> Dictionary:
	var source := "res://assets/spell-animations.json"
	if not FileAccess.file_exists(source) or FileAccess.get_sha256("res://assets/foxfire-board.glb") != MODEL_SHA:
		return {"error": "待机/火攻数据缺失或狐火模型版本不匹配"}
	var data = JSON.parse_string(FileAccess.get_file_as_string(source))
	if not data is Dictionary or not data.get("clips") is Dictionary:
		return {"error": "待机/火攻数据格式无效"}
	var paths: Dictionary = {}
	var base := player.get_animation(base_idle)
	for index in range(base.get_track_count()):
		var path := base.track_get_path(index)
		if path.get_subname_count() == 1:
			paths[str(path.get_subname(0))] = path
	var library := AnimationLibrary.new()
	for title in ["SpellIdle", "FlameAttack"]:
		var raw: Dictionary = data.clips.get(title, {})
		var duration := float(raw.get("duration", 0.0))
		if duration <= 0 or not raw.get("tracks") is Array:
			return {"error": "待机/火攻动作不完整：" + title}
		var clip := Animation.new()
		clip.length = duration
		clip.loop_mode = Animation.LOOP_LINEAR if title == "SpellIdle" else Animation.LOOP_NONE
		var seen: Array[String] = []
		for raw_track in raw.tracks:
			var bone := str(raw_track.get("bone", ""))
			var property := str(raw_track.get("path", ""))
			if not paths.has(bone) or property not in ["rotation", "translation", "scale"]:
				return {"error": "未知骨骼或动画轨道：" + bone + "/" + property}
			var key := bone + "/" + property
			if seen.has(key):
				return {"error": "重复动画轨道：" + key}
			seen.append(key)
			var times: Array = raw_track.get("times", [])
			var values: Array = raw_track.get("values", [])
			if times.is_empty() or times.size() != values.size():
				return {"error": "动画时间与数值数量不匹配"}
			var type := Animation.TYPE_ROTATION_3D if property == "rotation" else (Animation.TYPE_POSITION_3D if property == "translation" else Animation.TYPE_SCALE_3D)
			var track := clip.add_track(type)
			clip.track_set_path(track, paths[bone])
			clip.track_set_interpolation_type(track, Animation.INTERPOLATION_LINEAR)
			var previous := -1.0
			for index in range(times.size()):
				var time := float(times[index])
				var value: Array = values[index]
				if not is_finite(time) or time < 0.0 or time > duration + 0.00001 or time <= previous or value.size() != (4 if property == "rotation" else 3):
					return {"error": "动画关键帧时间或维度无效"}
				previous = time
				for component in value:
					if not is_finite(float(component)):
						return {"error": "动画包含非有限数值"}
				if property == "rotation":
					var q := Quaternion(value[0], value[1], value[2], value[3])
					if absf(q.length_squared() - 1.0) > 0.001:
						return {"error": "动画旋转未归一化"}
					clip.rotation_track_insert_key(track, time, q.normalized())
				elif property == "translation":
					clip.position_track_insert_key(track, time, Vector3(value[0], value[1], value[2]))
				else:
					clip.scale_track_insert_key(track, time, Vector3(value[0], value[1], value[2]))
		for bone in paths:
			for property in ["rotation", "translation", "scale"]:
				if not seen.has(bone + "/" + property):
					return {"error": "缺少完整骨骼姿势：" + bone + "/" + property}
		library.add_animation(title, clip)
	var events: Array = data.clips.FlameAttack.get("events", [])
	if events.size() != 1 or events[0].get("name") != "release" or events[0].get("hand") != "L":
		return {"error": "必须恰好包含一次左手发射事件"}
	var release := float(events[0].get("time", -1))
	if release <= 0 or release >= float(data.clips.FlameAttack.duration):
		return {"error": "火球发射时刻无效"}
	player.add_animation_library("spell", library)
	return {"idle": &"spell/SpellIdle", "attack": &"spell/FlameAttack", "data": data, "release": release}
