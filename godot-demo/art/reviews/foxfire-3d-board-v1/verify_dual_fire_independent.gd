extends SceneTree

# Independent numerical review: do not call the author's verify_dual_fire.gd.
# Run: Godot --headless --path <this project> --script res://verify_dual_fire_independent.gd
const EXPECTED_JSON_SHA := "a05ac755f3a7c810cffb7ebfa02aeb6197d1d77add80412bd382ebc4e746610f"
const EXPECTED_MODEL_SHA := "4257ac78a80ade3bbd328212c9341ecf9f775a7a8452aef7f8a2fc0875cfaa57"
const REVIEWED_FILES := ["assets/dual-fire-animations.json", "assets/foxfire-board.glb", "dual_fire_motion.gd", "board_controller.gd", "held_fire.gd", "held_fire.gdshader"]
var checks: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("run")

func check(title: String, passed: bool) -> void:
	checks.append({"name": title, "passed": passed})

func hashes() -> Dictionary:
	var result: Dictionary = {}
	for path in REVIEWED_FILES:
		result[path] = FileAccess.get_sha256("res://" + path)
	return result

func vec(raw: Array) -> Vector3:
	return Vector3(raw[0], raw[1], raw[2])

func quat(raw: Array) -> Quaternion:
	return Quaternion(raw[0], raw[1], raw[2], raw[3]).normalized()

func basis_error(a: Basis, b: Basis) -> float:
	return maxf(a.x.distance_to(b.x), maxf(a.y.distance_to(b.y), a.z.distance_to(b.z)))

func transform_error(a: Transform3D, b: Transform3D) -> float:
	return maxf(a.origin.distance_to(b.origin), basis_error(a.basis, b.basis))

func bone_chain(skeleton: Skeleton3D, index: int) -> Transform3D:
	# Reconstruct from parent-local poses, not controller._palm_world or the
	# Skeleton3D cached global pose used by the controller under test.
	var result := skeleton.get_bone_pose(index)
	var parent_index := skeleton.get_bone_parent(index)
	while parent_index >= 0:
		result = skeleton.get_bone_pose(parent_index) * result
		parent_index = skeleton.get_bone_parent(parent_index)
	return result

func local_poses(skeleton: Skeleton3D) -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	for index in skeleton.get_bone_count():
		result.append(skeleton.get_bone_pose(index))
	return result

func pose_error(a: Array[Transform3D], b: Array[Transform3D]) -> float:
	var worst := 0.0
	for index in a.size():
		worst = maxf(worst, transform_error(a[index], b[index]))
	return worst

func effect_state(fire: Node3D) -> Dictionary:
	var children: Array = []
	for child in fire.get_children():
		var item: Dictionary = {"name": str(child.name)}
		if child is Node3D:
			item.transform = child.transform
		if child is MeshInstance3D:
			var material: Material = child.material_override
			if material is ShaderMaterial:
				item.shader_time = material.get_shader_parameter("effect_time")
			elif material is StandardMaterial3D:
				item.color = material.albedo_color
		if child is OmniLight3D:
			item.energy = child.light_energy
		children.append(item)
	return {"transform": fire.global_transform, "elapsed": fire.last_elapsed, "children": children}

func fire_pair_state(board: Node3D) -> Dictionary:
	return {"L": effect_state(board.hand_fires.L), "R": effect_state(board.hand_fires.R)}

func expected_fire(board: Node3D, side: String) -> Vector3:
	var data: Dictionary = board.dual_fire_data
	var skeleton: Skeleton3D = board.skeleton
	var bone := skeleton.find_bone(data.palm_offsets[side].bone)
	var palm := skeleton.global_transform * (bone_chain(skeleton, bone) * vec(data.palm_offsets[side].position))
	return palm + Vector3.UP * float(data.orbs[side].up_offset) * 1.65

func independent_repairs(base: Animation, offset: float) -> Array:
	var result: Array = []
	for track in base.get_track_count():
		var path := base.track_get_path(track)
		if base.track_get_type(track) != Animation.TYPE_POSITION_3D or path.get_subname_count() != 1 or path.get_subname(0) != "root":
			continue
		var first: Vector3 = base.position_track_interpolate(track, offset)
		var last: Vector3 = base.track_get_key_value(track, base.track_get_key_count(track) - 1)
		var delta := last - first
		if delta.length() <= 0.000001:
			continue
		var until := 0.0
		for key in base.track_get_key_count(track):
			if base.track_get_key_time(track, key) > offset + 0.000001:
				until = base.track_get_key_time(track, key) - offset
				break
		result.append({"path": str(path), "delta": [delta.x, delta.y, delta.z], "until": until, "world_magnitude": delta.length() * 1.65})
	return result

func run() -> void:
	var initial_hashes := hashes()
	check("Final dual-fire JSON and original model SHA match the assigned versions", initial_hashes["assets/dual-fire-animations.json"] == EXPECTED_JSON_SHA and initial_hashes["assets/foxfire-board.glb"] == EXPECTED_MODEL_SHA)
	var board = load("res://board_controller.gd").new()
	root.add_child(board)
	board.set_process(false)
	await process_frame
	check("Two distinct hand-fire nodes and both dual-fire clips are loaded", board.dual_fire_loaded and board.hand_fires.size() == 2 and board.hand_fires.L != board.hand_fires.R)
	if not board.dual_fire_loaded or board.hand_fires.size() != 2:
		finish({"scope": "Dual-fire load failure", "hashes": initial_hashes})
		return
	var skeleton: Skeleton3D = board.skeleton
	var player: AnimationPlayer = board.animation_player
	var data: Dictionary = board.dual_fire_data
	var result := {"schema": 1, "scope": "Independent headless numerical integration review; not GPU, performance, visual occlusion or human-play acceptance.", "engine": Engine.get_version_info().string, "hashes": initial_hashes, "clips": {}, "socket_samples_per_hand": 0, "socket_max_error_world": {"L": 0.0, "R": 0.0}, "fire_scale_max_error": 0.0, "single_hand_negative_controls": [], "review_phase": "Final dual-fire revision only; supersedes earlier single-held-fire exploration."}
	var shift: float = data.source_time_offset
	for pair in [[board.idle_animation, board.base_idle_animation, "DualFireIdle"], [board.run_animation, board.base_run_animation, "DualFireRun"]]:
		var clip := player.get_animation(pair[0])
		var base := player.get_animation(pair[1])
		var source: Dictionary = data.clips[pair[2]]
		var stats := {"source_track_count": source.tracks.size(), "replaced_bones": [], "json_pose_samples": 0, "arm_basis_error_max": 0.0, "unchanged_track_count": 0, "body_samples_per_track": 601, "body_rotation_one_minus_abs_dot_max": 0.0, "body_position_residual_max": 0.0, "body_scale_residual_max": 0.0, "loop_quaternion_one_minus_abs_dot_max": 0.0, "loop_vector_error_max": 0.0, "curve_mismatches": [], "derived_root_seam_repairs": independent_repairs(base, shift)}
		var replaced: Dictionary = {}
		player.play(pair[0], 0.0)
		for track in source.tracks:
			var bone: String = track.bone
			if not stats.replaced_bones.has(bone):
				stats.replaced_bones.append(bone)
			replaced[bone + ":" + str(track.path)] = true
			check(str(pair[2]) + " allowed arm rotation track: " + bone, data.replace_only_bones.has(bone) and track.path == "rotation")
			var index := skeleton.find_bone(bone)
			for key in track.times.size():
				for midpoint in [false, true]:
					if midpoint and key == track.times.size() - 1:
						continue
					var time: float = track.times[key]
					var expected: Quaternion = quat(track.values[key])
					if midpoint:
						time = (time + float(track.times[key + 1])) * 0.5
						expected = expected.slerp(quat(track.values[key + 1]), 0.5).normalized()
					player.seek(time, true)
					board._step_visuals(0.0)
					stats.arm_basis_error_max = maxf(stats.arm_basis_error_max, basis_error(Basis(expected), Basis(skeleton.get_bone_pose_rotation(index).normalized())))
					stats.json_pose_samples += 1
		check(str(pair[2]) + " exactly six authored arm rotation curves match actual local poses", stats.replaced_bones.size() == 6 and source.tracks.size() == 6 and stats.arm_basis_error_max < 0.00001)
		var metadata: Array = data.runtime_seam_repairs[pair[2]]
		var repairs_match: bool = metadata.size() == stats.derived_root_seam_repairs.size()
		for repair in stats.derived_root_seam_repairs:
			var matched := false
			for recorded in metadata:
				matched = matched or (recorded.path == repair.path and vec(recorded.delta).distance_to(vec(repair.delta)) < 0.0000000001 and absf(float(recorded.until) - float(repair.until)) < 0.0000000001)
			repairs_match = repairs_match and matched and float(repair.world_magnitude) < 0.0002
		check(str(pair[2]) + " declared sub-0.2mm root repair equals independently derived correction", repairs_match)
		for track in base.get_track_count():
			var path := base.track_get_path(track)
			if path.get_subname_count() != 1:
				continue
			var type := base.track_get_type(track)
			var property := "rotation" if type == Animation.TYPE_ROTATION_3D else ("translation" if type == Animation.TYPE_POSITION_3D else "scale")
			if replaced.has(str(path.get_subname(0)) + ":" + property):
				continue
			var patched := clip.find_track(path, type)
			if patched < 0:
				stats.curve_mismatches.append({"path": str(path), "reason": "missing untouched track"})
				continue
			stats.unchanged_track_count += 1
			var worst := 0.0
			for sample in 601:
				var time := clip.length * sample / 601.0
				var difference := 0.0
				match type:
					Animation.TYPE_ROTATION_3D:
						difference = maxf(0.0, 1.0 - absf(clip.rotation_track_interpolate(patched, time).normalized().dot(base.rotation_track_interpolate(track, time + shift).normalized())))
						stats.body_rotation_one_minus_abs_dot_max = maxf(stats.body_rotation_one_minus_abs_dot_max, difference)
					Animation.TYPE_POSITION_3D:
						var expected := base.position_track_interpolate(track, time + shift)
						for repair in stats.derived_root_seam_repairs:
							if str(path) == str(repair.path):
								expected += vec(repair.delta) * maxf(0.0, 1.0 - time / float(repair.until))
						difference = clip.position_track_interpolate(patched, time).distance_to(expected)
						stats.body_position_residual_max = maxf(stats.body_position_residual_max, difference)
					Animation.TYPE_SCALE_3D:
						difference = clip.scale_track_interpolate(patched, time).distance_to(base.scale_track_interpolate(track, time + shift))
						stats.body_scale_residual_max = maxf(stats.body_scale_residual_max, difference)
				worst = maxf(worst, difference)
			if worst > (0.000001 if type == Animation.TYPE_ROTATION_3D else 0.00001):
				stats.curve_mismatches.append({"path": str(path), "type": type, "error": worst})
		check(str(pair[2]) + " all untouched tracks preserve the base phase plus explicit root repair", stats.curve_mismatches.is_empty())
		for track in clip.get_track_count():
			var count := clip.track_get_key_count(track)
			if count < 2:
				continue
			var first = clip.track_get_key_value(track, 0)
			var last = clip.track_get_key_value(track, count - 1)
			if first is Quaternion:
				stats.loop_quaternion_one_minus_abs_dot_max = maxf(stats.loop_quaternion_one_minus_abs_dot_max, maxf(0.0, 1.0 - absf(first.normalized().dot(last.normalized()))))
			elif first is Vector3:
				stats.loop_vector_error_max = maxf(stats.loop_vector_error_max, first.distance_to(last))
		check(str(pair[2]) + " cyclic keyed endpoints are closed", stats.loop_quaternion_one_minus_abs_dot_max < 0.000001 and stats.loop_vector_error_max < 0.00001)
		player.play(pair[0], 0.0)
		for yaw in [0.0, 0.8, 1.9, 3.6]:
			board.actor.position = Vector3(yaw * 0.1, 0, -yaw * 0.2)
			board.actor.rotation.y = yaw
			for sample in 61:
				player.seek(clip.length * sample / 61.0, true)
				board._step_visuals(0.0)
				for side in ["L", "R"]:
					var fire: Node3D = board.hand_fires[side]
					result.socket_max_error_world[side] = maxf(result.socket_max_error_world[side], expected_fire(board, side).distance_to(fire.global_position))
					var expected_size: float = float(data.orbs[side].core_radius) * 1.65 / 0.125
					result.fire_scale_max_error = maxf(result.fire_scale_max_error, fire.global_basis.get_scale().distance_to(Vector3.ONE * expected_size))
				result.socket_samples_per_hand += 1
			for side in ["L", "R"]:
				player.seek(clip.length * 0.37, true)
				board._step_visuals(0.0)
				var other := "R" if side == "L" else "L"
				var bone := skeleton.find_bone("hand." + side)
				var before_position := skeleton.get_bone_pose_position(bone)
				var before_expected := expected_fire(board, side)
				var own_before: Vector3 = board.hand_fires[side].global_position
				var other_before: Vector3 = board.hand_fires[other].global_position
				skeleton.set_bone_pose_position(bone, before_position + Vector3(0.12, 0.03, -0.02))
				board._update_fire_sockets()
				var expected_delta := expected_fire(board, side) - before_expected
				var actual_delta: Vector3 = board.hand_fires[side].global_position - own_before
				var opposite_movement: float = board.hand_fires[other].global_position.distance_to(other_before)
				result.single_hand_negative_controls.append({"clip": str(pair[2]), "yaw": yaw, "moved_hand": side, "expected_own_motion_world": expected_delta.length(), "own_motion_error_world": actual_delta.distance_to(expected_delta), "opposite_fire_motion_world": opposite_movement})
				skeleton.set_bone_pose_position(bone, before_position)
				board._update_fire_sockets()
		result.clips[str(pair[2])] = stats
	check("Each hand uses its own full parent-chain socket over 488 poses and four orientations", result.socket_samples_per_hand == 488 and result.socket_max_error_world.L < 0.00001 and result.socket_max_error_world.R < 0.00001)
	check("Fire radius applies model scaling exactly once", result.fire_scale_max_error < 0.00001)
	check("Moving only one hand moves only its own fire by the full displacement, not a midpoint half-displacement", result.single_hand_negative_controls.size() == 16 and result.single_hand_negative_controls.all(func(test): return test.expected_own_motion_world > 0.1 and test.own_motion_error_world < 0.00001 and test.opposite_fire_motion_world < 0.00001))
	board.reset_actor()
	board.request_move(Vector2i(7, 4))
	board._step_simulation(0.04)
	board._step_visuals(0.04)
	board.set_paused(true)
	var paused_bones := local_poses(skeleton)
	var paused_actor: Transform3D = board.actor.global_transform
	var paused_fires := fire_pair_state(board)
	var paused_animation_time := player.current_animation_position
	var paused_elapsed: float = board.fire_elapsed
	for step in 30:
		board._step_simulation(1.0 / 30.0)
		board._step_visuals(1.0 / 30.0)
	var current_fires := fire_pair_state(board)
	result.pause = {"duration_seconds": 1.0, "bone_transform_error_max": pose_error(paused_bones, local_poses(skeleton)), "actor_transform_error": transform_error(paused_actor, board.actor.global_transform), "animation_time_change": player.current_animation_position - paused_animation_time, "effect_clock_change": board.fire_elapsed - paused_elapsed, "all_fire_children_materials_and_lights_identical": paused_fires == current_fires, "embers_checked": 14}
	check("Crossfade pause freezes all bones and actor movement", result.pause.bone_transform_error_max == 0.0 and result.pause.actor_transform_error == 0.0 and result.pause.animation_time_change == 0.0)
	check("Both fires, 14 embers, shader time, colors and both lights freeze during pause", result.pause.effect_clock_change == 0.0 and result.pause.all_fire_children_materials_and_lights_identical)
	board.set_paused(false)
	board._step_visuals(0.125)
	var resumed_fires := fire_pair_state(board)
	result.resume = {"left_effect_advance": float(resumed_fires.L.elapsed) - float(paused_fires.L.elapsed), "right_effect_advance": float(resumed_fires.R.elapsed) - float(paused_fires.R.elapsed), "right_left_phase_difference": float(resumed_fires.R.elapsed) - float(resumed_fires.L.elapsed), "left_children_changed": resumed_fires.L.children != paused_fires.L.children, "right_children_changed": resumed_fires.R.children != paused_fires.R.children, "bone_transform_change": pose_error(paused_bones, local_poses(skeleton))}
	check("Both fires resume by the same elapsed duration while retaining independent flicker phases", absf(result.resume.left_effect_advance - 0.125) < 0.000001 and absf(result.resume.right_effect_advance - 0.125) < 0.000001 and absf(result.resume.right_left_phase_difference - 0.731) < 0.000001 and result.resume.left_children_changed and result.resume.right_children_changed and result.resume.bone_transform_change > 0.000001)
	board.reset_actor()
	var reset_pose := local_poses(skeleton)
	var reset_fires := fire_pair_state(board)
	player.stop()
	player.play(board.idle_animation, 0.0)
	player.seek(0.0, true)
	board._step_visuals(0.0)
	result.reset = {"bone_error_vs_hard_idle": pose_error(reset_pose, local_poses(skeleton)), "fires_identical_to_hard_idle": reset_fires == fire_pair_state(board), "left_effect_time": board.hand_fires.L.last_elapsed, "right_effect_time": board.hand_fires.R.last_elapsed}
	check("Reset clears old crossfade and restores both fires deterministically", result.reset.bone_error_vs_hard_idle == 0.0 and result.reset.fires_identical_to_hard_idle and absf(result.reset.left_effect_time) < 0.000001 and absf(result.reset.right_effect_time - 0.731) < 0.000001)
	check("Reviewed source files did not change during the check", initial_hashes == hashes())
	finish(result)

func finish(result: Dictionary) -> void:
	result["checks"] = checks
	result["passed"] = checks.all(func(item): return item.passed)
	result["passed_count"] = checks.filter(func(item): return item.passed).size()
	result["check_count"] = checks.size()
	result["created_at_utc"] = Time.get_datetime_string_from_system(true) + "Z"
	var output := "res://reports/dual-fire-independent.json"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	print(JSON.stringify({"passed": result.passed, "checks": result.check_count, "passed_count": result.passed_count, "output": output}))
	quit(0 if result.passed else 1)
