extends RefCounted

# Exercise the same small-step clock as the visible preview. These are numerical
# controller checks, not a substitute for skinned-foot or visual acceptance.
var checks: Array[Dictionary] = []

func _check(title: String, passed: bool) -> void:
	checks.append({"name": title, "passed": passed})

func _sample(board: Node3D) -> Array:
	return [board.actor.position.x, board.actor.position.z, board.actor.rotation.y,
		board.move_speed, board.actual_move_speed, board.animation_player.current_animation_position,
		board.animation_player.speed_scale, board.fire_elapsed]

func _same(a: Array, b: Array, tolerance: float = 0.00001) -> bool:
	if a.size() != b.size():
		return false
	for index in a.size():
		if absf(float(a[index]) - float(b[index])) > tolerance:
			return false
	return true

func _poses(board: Node3D) -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	for bone in board.skeleton.get_bone_count():
		result.append(board.skeleton.get_bone_pose(bone))
	return result

func _pose_error(a: Array, b: Array) -> float:
	var error := 0.0
	for bone in a.size():
		error = maxf(error, a[bone].origin.distance_to(b[bone].origin))
		for axis in 3:
			error = maxf(error, a[bone].basis[axis].distance_to(b[bone].basis[axis]))
	return error

func _clip_pose(board: Node3D, clip_name: StringName, time: float) -> Array[Transform3D]:
	var clip: Animation = board.animation_player.get_animation(clip_name)
	var positions: Array[Vector3] = []
	var rotations: Array[Quaternion] = []
	var scales: Array[Vector3] = []
	for bone in board.skeleton.get_bone_count():
		positions.append(Vector3.ZERO)
		rotations.append(Quaternion.IDENTITY)
		scales.append(Vector3.ONE)
	for track in clip.get_track_count():
		var bone: int = board.skeleton.find_bone(str(clip.track_get_path(track).get_subname(0)))
		if bone < 0:
			continue
		match clip.track_get_type(track):
			Animation.TYPE_POSITION_3D: positions[bone] = clip.position_track_interpolate(track, time)
			Animation.TYPE_ROTATION_3D: rotations[bone] = clip.rotation_track_interpolate(track, time)
			Animation.TYPE_SCALE_3D: scales[bone] = clip.scale_track_interpolate(track, time)
	var result: Array[Transform3D] = []
	for bone in positions.size():
		result.append(Transform3D(Basis(rotations[bone]).scaled(scales[bone]), positions[bone]))
	return result

func _probe_minimum(board: Node3D, poses: Array) -> float:
	# Independent local-TRS hierarchy composition, using source JSON probes
	# rather than the helper's cached global bone transforms.
	var minimum_y := INF
	for side in ["L", "R"]:
		var bone: int = board.skeleton.find_bone("foot." + side)
		var transform: Transform3D = poses[bone]
		bone = board.skeleton.get_bone_parent(bone)
		while bone >= 0:
			transform = poses[bone] * transform
			bone = board.skeleton.get_bone_parent(bone)
		for sample in board.locomotion_data.sole_probes[side]:
			var point := Vector3(sample[0], sample[1], sample[2])
			minimum_y = minf(minimum_y, (transform * point).y)
	return minimum_y

func _ground_expected(board: Node3D, poses: Array) -> float:
	var lift := maxf(0.0, 0.002 - _probe_minimum(board, poses))
	var root: int = board.skeleton.find_bone("root")
	var corrected: Transform3D = poses[root]
	corrected.origin += Vector3.UP * lift
	poses[root] = corrected
	return lift

func _grounding_checks(board: Node3D) -> Dictionary:
	var idle := _clip_pose(board, board.idle_animation, 0.0)
	var minimum_before := INF
	var minimum_after := INF
	var maximum_lift := 0.0
	var pose_error := 0.0
	var sample_count := 0
	var worst_time := 0.0
	var worst_fraction := 0.0
	var transforms_unchanged := true
	for fraction in [0.05, 0.125, 0.25, 0.375, 0.49]:
		for index in 120:
			var time := float(index) * 0.6 / 120.0
			board.reset_actor()
			var model_transform: Transform3D = board.model.transform
			var actor_transform: Transform3D = board.actor.transform
			board.moving = true
			board.actual_move_speed = board.MOVE_SPEED * fraction
			board.animation_player.play(board.run_animation, 0.0)
			board.animation_player.seek(time, true)
			var raw := _clip_pose(board, board.run_animation, time)
			var normalized: float = fraction * 2.0
			var weight: float = normalized * normalized * (3.0 - 2.0 * normalized)
			var expected: Array[Transform3D] = []
			for bone in raw.size():
				expected.append(idle[bone].interpolate_with(raw[bone], weight))
			minimum_before = minf(minimum_before, _probe_minimum(board, expected))
			var lift := _ground_expected(board, expected)
			if lift > maximum_lift:
				maximum_lift = lift
				worst_time = time
				worst_fraction = fraction
			board._step_visuals(0.0)
			var actual := _poses(board)
			minimum_after = minf(minimum_after, _probe_minimum(board, actual))
			pose_error = maxf(pose_error, _pose_error(actual, expected))
			transforms_unchanged = transforms_unchanged and model_transform.is_equal_approx(board.model.transform) and actor_transform.is_equal_approx(board.actor.transform)
			sample_count += 1
	_check("600个低速相位足底探针均不低于0.002模型单位", sample_count == 600 and minimum_after >= 0.002 - 0.000005)
	_check("低速接地只允许根骨按最低足底精确上抬且不改变模型/演员位置", pose_error < 0.00001 and transforms_unchanged)
	_check("负对照确实复现原低速穿地且补偿不超过0.03模型单位", minimum_before < -0.005 and maximum_lift > 0.007 and maximum_lift < 0.03)
	board.reset_actor()
	board.moving = true
	board.actual_move_speed = board.MOVE_SPEED * worst_fraction
	board.animation_player.play(board.run_animation, 0.0)
	board.animation_player.seek(worst_time, true)
	board._step_visuals(0.0)
	var grounded := _poses(board)
	for unused in 12:
		board._step_visuals(0.0)
	var stable: bool = _pose_error(grounded, _poses(board)) < 0.000001
	board.set_paused(true)
	for unused in 30:
		board._step_frame(1.0 / 30.0)
		board._step_visuals(1.0 / 30.0)
	_check("最大根骨补偿相位重复刷新及暂停都不累积抬高", stable and _pose_error(grounded, _poses(board)) < 0.000001 and absf(board.animation_player.current_animation_position - worst_time) < 0.000001)
	board.reset_actor()
	return {"sample_count": sample_count, "minimum_before": minimum_before, "minimum_after": minimum_after, "maximum_root_lift": maximum_lift, "maximum_pose_error": pose_error, "maximum_lift_phase": worst_time, "maximum_lift_speed_fraction": worst_fraction}

func _low_speed_checks(board: Node3D) -> Dictionary:
	var idle := _clip_pose(board, board.idle_animation, 0.0)
	var full_speed_error := 0.0
	var phase_unchanged := true
	# Explicit component fixtures compare runtime poses with independent clip
	# interpolation; they do not stand in for the natural turn below.
	for time in [0.0, 0.113, 0.297, 0.49, 0.599]:
		board.reset_actor()
		board.moving = true
		board.actual_move_speed = board.MOVE_SPEED
		board.animation_player.play(board.run_animation, 0.0)
		board.animation_player.seek(time, true)
		board._step_visuals(0.0)
		full_speed_error = maxf(full_speed_error, _pose_error(_poses(board), _clip_pose(board, board.run_animation, time)))
		phase_unchanged = phase_unchanged and absf(board.animation_player.current_animation_position - time) < 0.000001
	_check("全速五个相位的25骨姿势保持新Run且不改步相", full_speed_error < 0.00001 and phase_unchanged)
	board.reset_actor()
	board.moving = true
	board.actual_move_speed = board.MOVE_SPEED * 0.25
	board.animation_player.play(board.run_animation, 0.0)
	board.animation_player.seek(0.2, true)
	var raw := _clip_pose(board, board.run_animation, 0.2)
	var half: Array[Transform3D] = []
	for bone in raw.size():
		half.append(idle[bone].interpolate_with(raw[bone], 0.5))
	var expected_lift := _ground_expected(board, half)
	board._step_visuals(0.0)
	var slow_error := _pose_error(_poses(board), half)
	var relaxed := _poses(board)
	for unused in 4:
		board._step_visuals(0.0)
	_check("四分之一速度姿势为混合中点加精确根骨接地补偿且重复零推进不累积", slow_error < 0.00001 and _pose_error(relaxed, _poses(board)) < 0.00001 and absf(board.animation_player.current_animation_position - 0.2) < 0.000001)
	board.set_paused(true)
	var frozen := _poses(board)
	var frozen_time: float = board.animation_player.current_animation_position
	var frozen_fire: Transform3D = board.hand_fires.L.global_transform
	for unused in 30:
		board._step_visuals(1.0 / 30.0)
	_check("低速姿势混合途中暂停不重复松弛或推进步相/火焰", _pose_error(frozen, _poses(board)) < 0.000001 and is_equal_approx(frozen_time, board.animation_player.current_animation_position) and frozen_fire.is_equal_approx(board.hand_fires.L.global_transform))
	board.set_paused(false)
	board.locomotion_loaded = false
	board.animation_player.seek(0.2, true)
	board._step_visuals(0.0)
	_check("旧动作模式跳过低速松弛", _pose_error(_poses(board), raw) < 0.00001)
	board.locomotion_loaded = true
	board.reset_actor()
	board.actor.rotation.y = PI / 2.0
	board.request_move(Vector2i(9, 1))
	var turn_samples := 0
	var turn_pose_error := 0.0
	var turn_phase_error := 0.0
	var prior_phase := -1.0
	var socket_error := 0.0
	for unused in 720:
		board._step_frame(1.0 / 120.0)
		if board.current_cell == Vector2i(9, 4) and board.moving and is_zero_approx(board.actual_move_speed):
			turn_samples += 1
			turn_pose_error = maxf(turn_pose_error, _pose_error(_poses(board), idle))
			var phase: float = board.animation_player.current_animation_position
			if prior_phase >= 0:
				turn_phase_error = maxf(turn_phase_error, absf(phase - prior_phase))
			prior_phase = phase
			for side in ["L", "R"]:
				var bone: int = board.hand_left if side == "L" else board.hand_right
				var offset: Vector3 = board.palm_left if side == "L" else board.palm_right
				var palm: Vector3 = board.skeleton.global_transform * (board.skeleton.get_bone_global_pose(bone) * offset)
				socket_error = maxf(socket_error, board.hand_fires[side].global_position.distance_to(palm + Vector3.UP * float(board.fire_lifts[side])))
	_check("真实90度急转零速时全身与双脚回到Idle0且步相保留", turn_samples >= 10 and turn_pose_error < 0.00001 and turn_phase_error < 0.000001)
	_check("低速松弛后才更新两手火焰挂点", turn_samples >= 10 and socket_error < 0.00001)
	board.reset_actor()
	return {"full_speed_pose_error": full_speed_error, "quarter_speed_pose_error": slow_error, "quarter_speed_root_lift": expected_lift, "zero_speed_turn_samples": turn_samples, "zero_speed_turn_pose_error": turn_pose_error, "zero_speed_turn_phase_error": turn_phase_error, "relaxed_socket_error": socket_error}

func _scenario(board: Node3D, fps: int, kind: String) -> Dictionary:
	board.reset_actor()
	# Start facing along the first segment to measure acceleration independently
	# from the explicit turn cases. All positions remain normal board cells.
	board.actor.rotation.y = PI / 2.0
	var target := Vector2i(5, 4) if kind == "short" else Vector2i(9, 1) if kind == "corner" else Vector2i(9, 4)
	var accepted: bool = board.request_move(target)
	var trace: Array = []
	var maximum_speed := 0.0
	var maximum_fast_heading_error := 0.0
	var maximum_rate_error := 0.0
	var maximum_deceleration := 0.0
	var first_speed := 0.0
	var continuous_phase := true
	var straight_crossings := 0
	var brake_seen := false
	var replan_stable := true
	var pause_stable := true
	var phase_distance_error := 0.0
	var elapsed_animation := 0.0
	var total_distance := 0.0
	var previous: Vector3 = board.actor.position
	var previous_phase := 0.0
	var previous_moving := false
	var previous_speed := 0.0
	var minimum_frame_sole := INF
	var minimum_stop_sole := INF
	var stop_blend_remaining := 0.0
	var stop_blend_samples := 0
	var samples_per_frame: int = fps / 30
	for frame in range(fps * 8):
		if kind in ["replan", "reverse", "pause"] and frame == int(fps * 0.6):
			if kind == "pause":
				board.set_paused(true)
				var frozen := _sample(board)
				var transforms: Array[Transform3D] = []
				for bone in board.skeleton.get_bone_count():
					transforms.append(board.skeleton.get_bone_pose(bone))
				for unused in fps:
					board._step_frame(1.0 / fps)
				pause_stable = _same(frozen, _sample(board), 0.0)
				for bone in transforms.size():
					pause_stable = pause_stable and transforms[bone].is_equal_approx(board.skeleton.get_bone_pose(bone))
				board.set_paused(false)
			else:
				var before: Vector3 = board.actor.position
				target = Vector2i(3, 4) if kind == "reverse" else Vector2i(3, 2)
				replan_stable = board.request_move(target) and before.is_equal_approx(board.actor.position)
		var visited: int = board.travel_log.size()
		board._step_frame(1.0 / fps)
		var sole_y := _probe_minimum(board, _poses(board))
		minimum_frame_sole = minf(minimum_frame_sole, sole_y)
		if previous_moving and not board.moving:
			stop_blend_remaining = 0.12
		if stop_blend_remaining > 0.0:
			minimum_stop_sole = minf(minimum_stop_sole, sole_y)
			stop_blend_samples += 1
			stop_blend_remaining -= 1.0 / fps
		var distance: float = board.actor.position.distance_to(previous)
		var phase: float = board.animation_player.current_animation_position
		maximum_speed = maxf(maximum_speed, board.actual_move_speed)
		var expected_rate: float = board.actual_move_speed / 2.2 if board.moving else 1.0
		maximum_rate_error = maxf(maximum_rate_error, absf(board.animation_player.speed_scale - expected_rate))
		if frame == 0:
			first_speed = board.actual_move_speed
		if board.moving and previous_moving and kind == "straight":
			var animation_delta: float = fposmod(phase - previous_phase, board.animation_player.current_animation_length)
			elapsed_animation += animation_delta
			total_distance += distance
			phase_distance_error = maxf(phase_distance_error, absf(elapsed_animation * board.RUN_REFERENCE_SPEED - total_distance))
			if board.travel_log.size() > visited:
				straight_crossings += 1
				continuous_phase = continuous_phase and absf(animation_delta * board.RUN_REFERENCE_SPEED - distance) < 0.00005
		if distance > 0.000001 and board.actual_move_speed > board.MOVE_SPEED * 0.6:
			var heading: Vector3 = board.actor.global_basis.z.normalized()
			maximum_fast_heading_error = maxf(maximum_fast_heading_error, rad_to_deg(acos(clampf(heading.dot((board.actor.position - previous).normalized()), -1.0, 1.0))))
		if previous_speed > 0.2 and board.move_speed > 0.0 and board.move_speed < previous_speed - 0.001:
			brake_seen = true
		maximum_deceleration = maxf(maximum_deceleration, (previous_speed - board.move_speed) * fps)
		previous_speed = board.move_speed
		previous_moving = board.moving
		previous_phase = phase
		previous = board.actor.position
		if (frame + 1) % samples_per_frame == 0:
			trace.append(_sample(board))
	var adjacent := true
	var cell: Vector2i = board.HOME
	for visited in board.travel_log:
		adjacent = adjacent and absi(visited.x - cell.x) + absi(visited.y - cell.y) == 1
		cell = visited
	return {"fps": fps, "kind": kind, "trace": trace, "accepted": accepted,
		"arrived": board.current_cell == target and board.route.is_empty() and not board.moving and board.actor.position.is_equal_approx(board.cell_to_world(target)),
		"idle": board.animation_player.current_animation == board.idle_animation,
		"stopped": is_zero_approx(board.move_speed) and is_zero_approx(board.actual_move_speed),
		"first_speed": first_speed, "maximum_speed": maximum_speed, "brake_seen": brake_seen, "maximum_deceleration": maximum_deceleration,
		"maximum_rate_error": maximum_rate_error, "maximum_fast_heading_error_degrees": maximum_fast_heading_error,
		"phase_distance_error": phase_distance_error, "straight_crossings": straight_crossings,
		"continuous_phase": continuous_phase, "four_neighbour": adjacent,
		"minimum_frame_sole": minimum_frame_sole, "minimum_stop_sole": minimum_stop_sole, "stop_blend_samples": stop_blend_samples,
		"replan_stable": replan_stable, "pause_stable": pause_stable}

func run(board: Node3D) -> Dictionary:
	checks.clear()
	_check("新移动动作安装且使用独立NaturalRun", board.locomotion_loaded and str(board.run_animation) == "locomotion/NaturalRun")
	if not board.locomotion_loaded:
		return {"passed": false, "checks": checks}
	_check("周期与名义速度匹配0.6秒和缩放后1.32单位", is_equal_approx(board.animation_player.get_animation(board.run_animation).length, 0.6) and is_equal_approx(board.RUN_REFERENCE_SPEED, 2.2))
	var blocked: Array[Vector2i] = board.blocked.duplicate()
	board.blocked.clear()
	var summaries: Array = []
	for kind in ["straight", "short", "corner", "replan", "reverse", "pause"]:
		var reference: Array = []
		for fps in [30, 60, 120]:
			var result := _scenario(board, fps, kind)
			_check("%s %dFPS：合法逐格抵达并归待机清速率" % [kind, fps], result.accepted and result.arrived and result.idle and result.stopped and result.four_neighbour)
			_check("%s %dFPS：起步/刹车及位移步频匹配" % [kind, fps], result.first_speed > 0.0 and result.first_speed < board.MOVE_SPEED * 0.15 and result.maximum_speed <= board.MOVE_SPEED + 0.00001 and result.brake_seen and result.maximum_rate_error < 0.00001)
			_check("%s %dFPS：高速朝向误差小于12度" % [kind, fps], result.maximum_fast_heading_error_degrees < 12.0)
			_check("%s %dFPS：逐帧含抵达后0.12秒混合的足底保持接地" % [kind, fps], result.minimum_frame_sole >= 0.002 - 0.000001 and result.minimum_stop_sole >= 0.002 - 0.000001 and result.stop_blend_samples >= ceili(0.12 * fps))
			if kind in ["straight", "short", "corner"]:
				_check("%s %dFPS：含最后抵达子步的减速度不超制动上限" % [kind, fps], result.maximum_deceleration <= board.MOVE_BRAKING + 0.001)
			if kind == "straight":
				_check("直线%dFPS：跨格相位连续且步频随实际位移" % fps, result.straight_crossings >= 4 and result.continuous_phase and result.phase_distance_error < 0.0001 and result.maximum_speed > board.MOVE_SPEED - 0.0001)
			if kind in ["replan", "reverse", "pause"]:
				_check("%s %dFPS：改目标无瞬移/暂停冻结骨骼与时钟" % [kind, fps], result.replan_stable and result.pause_stable)
			if reference.is_empty():
				reference = result.trace
			else:
				var consistent: bool = reference.size() == result.trace.size()
				for index in mini(reference.size(), result.trace.size()):
					consistent = consistent and _same(reference[index], result.trace[index])
				_check("%s %dFPS：全部公共时刻与30FPS位置/朝向/步相/火焰一致" % [kind, fps], consistent)
			result.erase("trace")
			summaries.append(result)
	# A large presentation delta must traverse the same sequence of movement and
	# pose updates; moving first and then posing once would fail this comparison.
	board.reset_actor()
	board.request_move(Vector2i(9, 1))
	board._step_frame(1.2)
	var large := _sample(board)
	board.reset_actor()
	board.request_move(Vector2i(9, 1))
	for unused in 144:
		board._step_frame(1.0 / 120.0)
	_check("1.2秒大步与144个小步的移动/骨骼相位/火焰时钟一致", _same(large, _sample(board)))
	board.reset_actor()
	board.actor.rotation.y = PI / 2.0
	board.request_move(Vector2i(9, 4))
	board._step_frame(1.0 / 120.0)
	var first_endpoint: Vector2i = board.route[0]
	var early_position: Vector3 = board.actor.position
	var early_replan: bool = board.request_move(Vector2i(4, 2))
	_check("极慢起步不足旧0.005阈值也保当前格段且不瞬移", early_replan and early_position.distance_to(board.cell_to_world(board.HOME)) < 0.005 and board.route[0] == first_endpoint and board.actor.position.is_equal_approx(early_position))
	board.reset_actor()
	board._step_frame(0.003)
	board.request_move(Vector2i(7, 4))
	board._step_frame(0.4)
	board.set_paused(true)
	board.reset_actor()
	_check("归位清除速度/固定步余量/暂停和路径", is_zero_approx(board.move_speed) and is_zero_approx(board.actual_move_speed) and is_zero_approx(board.motion_remainder) and not board.paused and not board.moving and board.route.is_empty())
	var relaxation := _low_speed_checks(board)
	var grounding := _grounding_checks(board)
	board.blocked.assign(blocked)
	return {"passed": checks.all(func(item): return item.passed), "scope": "独立试场新移动控制的无窗口动态检查；足底仅为源模型探针，不替代全部真实蒙皮、GPU、连续视觉或正式战斗验收", "checks": checks, "passed_count": checks.filter(func(item): return item.passed).size(), "check_count": checks.size(), "scenarios": summaries, "low_speed_pose": relaxation, "low_speed_grounding": grounding}
