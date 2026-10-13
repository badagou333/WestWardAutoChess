extends RefCounted

func run(board: Node3D) -> Dictionary:
	var checks: Array[Dictionary] = []
	_check(checks, "自然双手动作与两团独立狐火均已载入", board.dual_fire_loaded and board.hand_fires.size() == 2)
	if not board.dual_fire_loaded or board.hand_fires.size() != 2:
		return {"passed": false, "checks": checks}
	board.set_process(false)
	board.reset_actor()
	var player: AnimationPlayer = board.animation_player
	var skeleton: Skeleton3D = board.skeleton
	var non_arm_match := true
	var loop_match := true
	var socket_error := 0.0
	var minimum_palm_spacing := INF
	var maximum_palm_spacing := 0.0
	var minimum_height_difference := INF
	var tested := 0
	var arms: Array = board.DualFireMotion.ARM_BONES
	var shift := float(board.dual_fire_data.get("source_time_offset", 0.0))
	for pair in [[board.idle_animation, board.base_idle_animation], [board.run_animation, board.base_run_animation]]:
		var clip := player.get_animation(pair[0])
		var base := player.get_animation(pair[1])
		for track in range(base.get_track_count()):
			var path := base.track_get_path(track)
			if path.get_subname_count() != 1 or arms.has(str(path.get_subname(0))):
				continue
			var type := base.track_get_type(track)
			var patched := clip.find_track(path, type)
			if patched < 0:
				non_arm_match = false
				continue
			for sample in range(61):
				var time := clip.length * sample / 61.0
				match type:
					Animation.TYPE_ROTATION_3D:
						var q := clip.rotation_track_interpolate(patched, time).normalized()
						var reference := base.rotation_track_interpolate(track, time + shift).normalized()
						non_arm_match = non_arm_match and absf(q.dot(reference)) > 0.999999
					Animation.TYPE_POSITION_3D:
						var reference := base.position_track_interpolate(track, time + shift)
						var short_name := str(pair[0]).get_slice("/", 1)
						for repair in board.dual_fire_data.runtime_seam_repairs[short_name]:
							if str(path) == str(repair.path):
								var delta := Vector3(repair.delta[0], repair.delta[1], repair.delta[2])
								non_arm_match = non_arm_match and delta.length() * board.ACTOR_SCALE < 0.0002
								reference += delta * maxf(0.0, 1.0 - time / float(repair.until))
						non_arm_match = non_arm_match and clip.position_track_interpolate(patched, time).distance_to(reference) < 0.00001
		for track in range(clip.get_track_count()):
			var count := clip.track_get_key_count(track)
			if count > 1:
				var first = clip.track_get_key_value(track, 0)
				var last = clip.track_get_key_value(track, count - 1)
				if first is Quaternion:
					loop_match = loop_match and absf(first.normalized().dot(last.normalized())) > 0.999999
				elif first is Vector3:
					loop_match = loop_match and first.distance_to(last) < 0.00001
		player.play(pair[0], 0.0)
		for yaw in [0.0, PI * 0.5, PI, PI * 1.5]:
			board.actor.rotation.y = yaw
			for sample in range(41):
				player.seek(clip.length * sample / 41.0, true)
				board._step_visuals(0.0)
				var left: Vector3 = board._palm_world(board.hand_left, board.palm_left)
				var right: Vector3 = board._palm_world(board.hand_right, board.palm_right)
				for side in ["L", "R"]:
					var expected: Vector3 = (left if side == "L" else right) + Vector3.UP * float(board.fire_lifts[side])
					socket_error = maxf(socket_error, expected.distance_to(board.hand_fires[side].global_position))
				var spacing := left.distance_to(right)
				minimum_palm_spacing = minf(minimum_palm_spacing, spacing)
				maximum_palm_spacing = maxf(maximum_palm_spacing, spacing)
				minimum_height_difference = minf(minimum_height_difference, left.y - right.y)
				tested += 1
	_check(checks, "身体曲线相位保持，仅Idle根骨记录小于0.2mm世界位移闭环修正", non_arm_match)
	_check(checks, "双火动作循环首尾姿势一致", loop_match)
	_check(checks, "两动作四朝向328个时点两火分别跟随各自掌心", socket_error < 0.00001 and tested == 328)
	_check(checks, "双手分开且保留左高右低轮廓", minimum_palm_spacing > 0.3 and maximum_palm_spacing < 1.4 and minimum_height_difference > 0.07)
	# Negative dependency probe: moving only the left hand must not drag the
	# right fire. This rejects a hidden shared midpoint attachment.
	var right_before: Vector3 = board.hand_fires.R.global_position
	var left_before: Vector3 = board.hand_fires.L.global_position
	var hand_position: Vector3 = skeleton.get_bone_pose_position(board.hand_left)
	skeleton.set_bone_pose_position(board.hand_left, hand_position + Vector3(0.025, 0, 0))
	board._update_fire_sockets()
	_check(checks, "单手扰动负对照：左火移动，右火不跟随", board.hand_fires.L.global_position.distance_to(left_before) > 0.02 and board.hand_fires.R.global_position.is_equal_approx(right_before))
	skeleton.set_bone_pose_position(board.hand_left, hand_position)
	# Freeze in the middle of a crossfade, not only a settled clip.
	board.reset_actor()
	board.request_move(Vector2i(7, 4))
	board._step_simulation(0.04)
	board._step_visuals(0.04)
	board.set_paused(true)
	var poses: Array[Transform3D] = []
	for index in range(skeleton.get_bone_count()):
		poses.append(skeleton.get_bone_global_pose(index))
	var fire_transforms: Dictionary = {}
	var fire_times: Dictionary = {}
	for side in ["L", "R"]:
		fire_transforms[side] = board.hand_fires[side].global_transform
		fire_times[side] = board.hand_fires[side].last_elapsed
	for unused in range(30):
		board._step_simulation(1.0 / 30.0)
		board._step_visuals(1.0 / 30.0)
	var frozen := true
	for index in range(poses.size()):
		frozen = frozen and poses[index].is_equal_approx(skeleton.get_bone_global_pose(index))
	for side in ["L", "R"]:
		frozen = frozen and board.hand_fires[side].global_transform.is_equal_approx(fire_transforms[side]) and is_equal_approx(board.hand_fires[side].last_elapsed, fire_times[side])
	_check(checks, "混合途中暂停也冻结全部骨骼与两火时钟", frozen)
	board.set_paused(false)
	board._step_visuals(0.1)
	_check(checks, "恢复后两火继续流动且保留独立相位", board.hand_fires.L.last_elapsed > fire_times.L and board.hand_fires.R.last_elapsed > fire_times.R and is_equal_approx(board.hand_fires.R.last_elapsed - board.hand_fires.L.last_elapsed, 0.731))
	board.reset_actor()
	var reset_left: Vector3 = board.hand_fires.L.global_position
	var reset_right: Vector3 = board.hand_fires.R.global_position
	player.play(board.run_animation, 0.0)
	player.seek(0.2, true)
	board._step_visuals(0.0)
	board.reset_actor()
	_check(checks, "归位清除旧动作混合与两火时间", is_zero_approx(board.fire_elapsed) and reset_left.is_equal_approx(board.hand_fires.L.global_position) and reset_right.is_equal_approx(board.hand_fires.R.global_position))
	var effects: Dictionary = {}
	var layers_ok := true
	for side in ["L", "R"]:
		var effect: Dictionary = board.hand_fires[side].diagnostic_state()
		effects[side] = effect
		layers_ok = layers_ok and effect.closed_flame_meshes == 5 and effect.embers == 7 and not effect.independent_clock and not effect.light_casts_shadows
	_check(checks, "两火独立分层且无自主时钟或重复动态阴影", layers_ok and board.hand_fires.L != board.hand_fires.R)
	var passed := checks.all(func(check): return check.passed)
	return {"passed": passed, "scope": "双火动作数据保真、每手独立挂点与确定性时钟检查；不替代自然度、视觉穿插或连续播放审查", "checks": checks, "sample_count": tested, "socket_error_world": socket_error, "palm_spacing_world": [minimum_palm_spacing, maximum_palm_spacing], "minimum_left_above_right_world": minimum_height_difference, "runtime_seam_repairs": board.dual_fire_data.runtime_seam_repairs, "effects": effects}

func _check(checks: Array[Dictionary], title: String, passed: bool) -> void:
	checks.append({"name": title, "passed": passed})
