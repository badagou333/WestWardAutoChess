extends SceneTree

# Independent test entry point. Component checks do not load the controller or
# require unfinished animation data. No GPU, production damage or OS input.
# Godot --headless --path <project> --script res://verify_spell_independent.gd -- --component-only
# Omit --component-only for the final integrated report after assets are ready.
const MODEL_SHA := "4257ac78a80ade3bbd328212c9341ecf9f775a7a8452aef7f8a2fc0875cfaa57"
const BASELINE_COMMIT := "ae779e0"
const REPOSITORY_PREFIX := "godot-demo/art/reviews/foxfire-3d-board-v1/"
const SOURCE_FILES := ["assets/foxfire-board.glb", "assets/dual-fire-animations.json", "assets/spell-animations.json", "spell_motion.gd", "dual_fire_motion.gd", "board_controller.gd", "attack_effects.gd", "held_fire.gd", "held_fire.gdshader", "ui.gd"]
var checks: Array[Dictionary] = []
var details: Dictionary = {}
var options: Dictionary = {}

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--"):
			var parts := argument.trim_prefix("--").split("=", true, 1)
			options[parts[0]] = parts[1] if parts.size() > 1 else true
	call_deferred("run")

func check(name: String, passed: bool, evidence: Variant = null) -> void:
	var value := {"name": name, "passed": passed}
	if evidence != null:
		value["evidence"] = evidence
	checks.append(value)

func hashes() -> Dictionary:
	var result: Dictionary = {}
	for path in SOURCE_FILES:
		if FileAccess.file_exists("res://" + path):
			result[path] = FileAccess.get_sha256("res://" + path)
	return result

func v(raw: Array) -> Vector3:
	return Vector3(raw[0], raw[1], raw[2])

func q(raw: Array) -> Quaternion:
	return Quaternion(raw[0], raw[1], raw[2], raw[3]).normalized()

func basis_error(a: Basis, b: Basis) -> float:
	return maxf(a.x.distance_to(b.x), maxf(a.y.distance_to(b.y), a.z.distance_to(b.z)))

func transforms_error(a: Array, b: Array) -> float:
	var error := 0.0
	for index in a.size():
		error = maxf(error, maxf(a[index].origin.distance_to(b[index].origin), basis_error(a[index].basis, b[index].basis)))
	return error

func bones(skeleton: Skeleton3D) -> Array:
	var result: Array = []
	for index in skeleton.get_bone_count():
		result.append(skeleton.get_bone_pose(index))
	return result

func tree_state(node: Node) -> Dictionary:
	var state := {"name": str(node.name), "children": []}
	if node is Node3D:
		state.transform = node.transform
		state.visible = node.visible
	if node is MeshInstance3D:
		var material: Material = node.material_override
		if material is ShaderMaterial:
			state.shader_time = material.get_shader_parameter("effect_time")
		elif material is StandardMaterial3D:
			state.color = material.albedo_color
	if node is OmniLight3D:
		state.energy = node.light_energy
	for child in node.get_children():
		state.children.append(tree_state(child))
	return state

func node_count(node: Node) -> int:
	var count := 1
	for child in node.get_children():
		count += node_count(child)
	return count

func step_effect_to(effect: Node3D, elapsed: float, quantum: float) -> void:
	var left := elapsed
	while left > 0.000000001:
		var dt := minf(left, quantum)
		effect.step(dt)
		left -= dt

func component_tests() -> void:
	var effect = load("res://attack_effects.gd").new()
	root.add_child(effect)
	effect.configure()
	var count := node_count(effect)
	check("Effect begins with no active projectile or impact", not effect.is_active() and not effect.projectile.visible and not effect.impact.visible)
	var from := Vector3(-0.6, 1.12, 0.8)
	var to := Vector3(1.7, 0.8, -0.4)
	var flight := maxf(from.distance_to(to) / 6.0, 0.06)
	var comparisons: Array = []
	for elapsed in [0.0, 0.073, flight * 0.7, flight, flight + 0.12, flight + 0.379]:
		effect.reset()
		effect.launch(from, to)
		effect.step(elapsed)
		var one: Dictionary = effect.diagnostic_state()
		var expected := from.lerp(to, clampf(elapsed / flight, 0.0, 1.0)) + Vector3.UP * sin(clampf(elapsed / flight, 0.0, 1.0) * PI) * 0.045
		var one_flash: Vector3 = effect.flash.scale
		effect.reset()
		effect.launch(from, to)
		step_effect_to(effect, elapsed, 1.0 / 120.0)
		var split: Dictionary = effect.diagnostic_state()
		var position_error: float = one.projectile_position.distance_to(split.projectile_position)
		var reference_error: float = expected.distance_to(split.projectile_position)
		var flash_error: float = one_flash.distance_to(effect.flash.scale) if split.impact_active else 0.0
		var agree: bool = one.active == split.active and one.projectile_active == split.projectile_active and one.impact_active == split.impact_active and position_error < 0.00001 and reference_error < 0.00001 and flash_error < 0.00001
		comparisons.append({"elapsed": elapsed, "passed": agree, "position_error_world": position_error, "reference_position_error_world": reference_error, "impact_scale_error": flash_error})
	check("Projectile and impact agree for one large step and 120Hz subdivision", comparisons.all(func(item): return item.passed), comparisons)
	effect.reset()
	effect.launch(from, to)
	effect.step(0.17)
	var unchanged := tree_state(effect)
	var state: Dictionary = effect.diagnostic_state()
	effect.step(0.0)
	effect.step(-0.2)
	await process_frame
	await process_frame
	check("Zero/negative steps and scene frames do not autonomously advance effects", unchanged == tree_state(effect) and state == effect.diagnostic_state())
	effect.step(flight + 0.5)
	check("A completed shot hides projectile, trail and impact", not effect.is_active() and not effect.projectile.visible and not effect.impact.visible and effect.tail.all(func(mesh): return not mesh.visible))
	for unused in 12:
		effect.reset()
		effect.launch(from, to)
		effect.step(0.1)
	check("Repeated shots reuse the same fixed node pool", node_count(effect) == count)
	effect.reset()
	var reset: Dictionary = effect.diagnostic_state()
	check("Effect reset clears counters, origins, age and all active layers", not reset.active and reset.age == 0.0 and reset.launch_count == 0 and reset.origin == Vector3.ZERO and reset.target == Vector3.ZERO and not effect.projectile.visible and not effect.impact.visible)
	effect.launch(Vector3.ONE, Vector3.ONE)
	effect.step(0.03)
	check("Coincident endpoints retain a finite minimum flight duration", effect.flight_duration == 0.06 and effect.projectile.global_position.is_finite())
	details.component = {"flight_duration": flight, "fixed_node_count": count, "samples": comparisons, "inactive_age_note": "Inactive age overshoot is not used as visual evidence; active projectile/impact state and cleanup are checked separately."}
	effect.queue_free()

func sample(track: Dictionary, time: float) -> Variant:
	var times: Array = track.times
	var at := 0
	while at + 1 < times.size() and float(times[at + 1]) <= time:
		at += 1
	var next := mini(at + 1, times.size() - 1)
	var factor := 0.0 if next == at else clampf((time - float(times[at])) / (float(times[next]) - float(times[at])), 0.0, 1.0)
	if str(track.get("interpolation", "LINEAR")) == "STEP":
		factor = 0.0
	if track.path == "rotation":
		return q(track.values[at]).slerp(q(track.values[next]), factor).normalized()
	return v(track.values[at]).lerp(v(track.values[next]), factor)

func json_hand_origin(board: Node3D, time: float, hand: String = "L") -> Vector3:
	var skeleton: Skeleton3D = board.skeleton
	var positions: Array = []
	var rotations: Array = []
	var scales: Array = []
	for index in skeleton.get_bone_count():
		var rest := skeleton.get_bone_rest(index)
		positions.append(rest.origin)
		rotations.append(rest.basis.get_rotation_quaternion())
		scales.append(rest.basis.get_scale())
	var title := "FlameAttack" if hand == "L" else "FlameAttackRight"
	for track in board.spell_data.clips[title].tracks:
		var index := skeleton.find_bone(track.bone)
		match str(track.path):
			"translation": positions[index] = sample(track, time)
			"rotation": rotations[index] = sample(track, time)
			"scale": scales[index] = sample(track, time)
	var index := skeleton.find_bone("hand." + hand)
	var chain := Transform3D(Basis(rotations[index]).scaled(scales[index]), positions[index])
	index = skeleton.get_bone_parent(index)
	while index >= 0:
		chain = Transform3D(Basis(rotations[index]).scaled(scales[index]), positions[index]) * chain
		index = skeleton.get_bone_parent(index)
	var local_offset := v(board.dual_fire_data.palm_offsets[hand].position)
	return skeleton.global_transform * (chain * local_offset) + Vector3.UP * float(board.dual_fire_data.orbs[hand].up_offset) * 1.65

func board_tick(board: Node3D, delta: float) -> void:
	board._step_simulation(delta)
	board._step_visuals(delta)

func board_step_to(board: Node3D, elapsed: float, quantum: float) -> void:
	var remaining := elapsed
	while remaining > 0.000000001:
		var dt := minf(remaining, quantum)
		board_tick(board, dt)
		remaining -= dt

func animation_tests(board: Node3D) -> void:
	var player: AnimationPlayer = board.animation_player
	var skeleton: Skeleton3D = board.skeleton
	var reports: Dictionary = {}
	for name in ["SpellIdle", "FlameAttack", "FlameAttackRight"]:
		if not player.has_animation("spell/" + name) or not board.spell_data.clips.has(name):
			check(name + " is present in the installed animation library and source data", false)
			continue
		var clip := player.get_animation("spell/" + name)
		var source: Dictionary = board.spell_data.clips[name]
		var stats := {"rotation_error_max": 0.0, "translation_error_max": 0.0, "scale_error_max": 0.0, "pose_samples": 0, "track_count": source.tracks.size()}
		check(name + " expected duration and loop mode", absf(clip.length - (3.0 if name == "SpellIdle" else 1.2)) < 0.000001 and clip.loop_mode == (Animation.LOOP_LINEAR if name == "SpellIdle" else Animation.LOOP_NONE))
		player.play("spell/" + name, 0.0)
		player.speed_scale = 1.0
		for index in 121:
			var time := clip.length * index / 120.0
			player.seek(time, true)
			player.advance(0.0)
			for track in source.tracks:
				var bone := skeleton.find_bone(track.bone)
				var expected = sample(track, time)
				match str(track.path):
					"rotation": stats.rotation_error_max = maxf(stats.rotation_error_max, basis_error(Basis(expected), Basis(skeleton.get_bone_pose_rotation(bone).normalized())))
					"translation": stats.translation_error_max = maxf(stats.translation_error_max, expected.distance_to(skeleton.get_bone_pose_position(bone)))
					"scale": stats.scale_error_max = maxf(stats.scale_error_max, expected.distance_to(skeleton.get_bone_pose_scale(bone)))
				stats.pose_samples += 1
		check(name + " complete imported TRS matches independent JSON interpolation", stats.track_count == 75 and stats.rotation_error_max < 0.00001 and stats.translation_error_max < 0.00001 and stats.scale_error_max < 0.00001, stats)
		reports[name] = stats
	details.animation = reports
	var ref_model := (load("res://assets/foxfire-board.glb") as PackedScene).instantiate()
	root.add_child(ref_model)
	var ref_player: AnimationPlayer = ref_model.find_children("*", "AnimationPlayer", true, false)[0]
	var installed: Dictionary = load("res://dual_fire_motion.gd").install(ref_player, &"Idle", &"Run")
	var baseline := ref_player.get_animation(installed.run)
	# Locomotion is now separately authorized; this regression still compares the
	# preserved original library, not the newly selected movement candidate.
	var actual := player.get_animation(&"dual_fire/DualFireRun")
	var unchanged := baseline.get_track_count() == actual.get_track_count() and baseline.length == actual.length
	for track in baseline.get_track_count():
		var path := baseline.track_get_path(track)
		var found := actual.find_track(path, baseline.track_get_type(track))
		if found < 0 or baseline.track_get_key_count(track) != actual.track_get_key_count(found):
			unchanged = false
			continue
		for key in baseline.track_get_key_count(track):
			unchanged = unchanged and baseline.track_get_key_time(track, key) == actual.track_get_key_time(found, key) and baseline.track_get_key_value(track, key) == actual.track_get_key_value(found, key)
	check("Spell installation leaves the prior dual-fire running animation exactly unchanged", unchanged)
	var endpoint_reports: Array = []
	player.play("spell/SpellIdle", 0.0)
	player.seek(0.0, true)
	player.advance(0.0)
	var idle_pose := bones(skeleton)
	for name in ["FlameAttack", "FlameAttackRight"]:
		if not player.has_animation("spell/" + name):
			continue
		for time in [0.0, 1.2]:
			player.play("spell/" + name, 0.0)
			player.seek(time, true)
			player.advance(0.0)
			var error := transforms_error(idle_pose, bones(skeleton))
			endpoint_reports.append({"clip": name, "time": time, "all_bone_transform_error": error, "passed": error < 0.00001})
	check("Both attack start/end poses match the complete idle start pose", endpoint_reports.size() == 4 and endpoint_reports.all(func(item): return item.passed), endpoint_reports)
	details.endpoints = endpoint_reports
	ref_model.queue_free()
	board.reset_actor()

func baseline_tests(board: Node3D) -> void:
	var output: Array = []
	var repository := ProjectSettings.globalize_path("res://")
	var status := OS.execute("git", ["-C", repository, "show", BASELINE_COMMIT + ":" + REPOSITORY_PREFIX + "assets/spell-animations.json"], output, true)
	var old = JSON.parse_string(str(output[0])) if status == 0 and not output.is_empty() else null
	var loaded: bool = old is Dictionary and old.get("clips") is Dictionary
	check("Historical spell baseline is read directly from the pre-change Git commit", loaded, {"commit": BASELINE_COMMIT, "git_exit": status})
	if loaded:
		check("Original left attack data is exactly unchanged from the pre-change commit", old.clips.FlameAttack == board.spell_data.clips.FlameAttack)
		check("Original idle data is exactly unchanged from the pre-change commit", old.clips.SpellIdle == board.spell_data.clips.SpellIdle)
	output.clear()
	status = OS.execute("git", ["-C", repository, "show", BASELINE_COMMIT + ":" + REPOSITORY_PREFIX + "assets/dual-fire-animations.json"], output, true)
	var baseline_text := str(output[0]) if status == 0 and not output.is_empty() else ""
	check("Prior dual-fire source, including Run, is byte-for-byte unchanged", status == 0 and not baseline_text.is_empty() and baseline_text == FileAccess.get_file_as_string("res://assets/dual-fire-animations.json"), {"commit": BASELINE_COMMIT, "git_exit": status, "historical_sha256": baseline_text.sha256_text()})

func sequence_state(board: Node3D) -> Dictionary:
	return {"hand": str(board.attack_hand), "next": str(board.next_attack_hand), "last": str(board.last_release_hand), "clip": str(board.attack_animation), "launches": board.launch_count}

func prepare_hand(board: Node3D, hand: String) -> bool:
	board.reset_actor()
	if hand == "R":
		if not board.request_attack():
			return false
		board_step_to(board, 2.0, 1.0 / 60.0)
	return str(board.next_attack_hand) == hand and not board.attacking and not board.attack_effects.is_active()

func alternating_tests(board: Node3D) -> void:
	if not board.spell_data.clips.has("FlameAttackRight"):
		check("Right attack is ready for alternating integration checks", false)
		return
	baseline_tests(board)
	var events: Array = board.spell_data.clips.FlameAttackRight.get("events", [])
	check("One right-hand release event is exactly at 0.4 seconds", events.size() == 1 and events[0].get("name") == "release" and events[0].get("hand") == "R" and absf(float(events[0].get("time", -1.0)) - 0.4) < 0.000001)
	board.reset_actor()
	var rounds: Array = []
	for hand in ["L", "R", "L", "R"]:
		var before: int = board.launch_count
		var accepted: bool = board.request_attack()
		var expected_clip := "spell/FlameAttack" if hand == "L" else "spell/FlameAttackRight"
		var selected: bool = str(board.attack_hand) == hand and str(board.next_attack_hand) == hand and str(board.attack_animation) == expected_clip
		var expected := json_hand_origin(board, 0.4, hand)
		board_step_to(board, 0.399, 1.0 / 60.0)
		var before_release: bool = board.launch_count == before and str(board.next_attack_hand) == hand
		board_tick(board, 0.001)
		var opposite := "R" if hand == "L" else "L"
		var origin_error: float = board.attack_effects.origin.distance_to(expected)
		var released: bool = board.launch_count == before + 1 and board.attack_effects.launch_count == before + 1 and str(board.last_release_hand) == hand and str(board.next_attack_hand) == opposite and origin_error < 0.00001
		board_step_to(board, 1.6, 1.0 / 60.0)
		var finished: bool = not board.attacking and board.launch_count == before + 1 and str(board.next_attack_hand) == opposite and str(board.animation_player.current_animation) == str(board.idle_animation)
		rounds.append({"hand": hand, "accepted": accepted, "correct_clip_and_pending_hand": selected, "unchanged_before_release": before_release, "one_correct_release": released, "clean_idle_completion": finished, "origin_error_world": origin_error, "passed": accepted and selected and before_release and released and finished})
	check("Four completed attacks follow L/R/L/R and advance the next hand only at release", rounds.size() == 4 and rounds.all(func(item): return item.passed), rounds)
	details.alternating_rounds = rounds
	var releases: Array = []
	for elapsed in [0.399, 0.4, 0.47, 0.9, 1.2, 2.0]:
		var outcomes: Array = []
		for quantum in [10.0, 1.0 / 120.0]:
			var prepared := prepare_hand(board, "R")
			var accepted: bool = board.request_attack()
			var expected := json_hand_origin(board, 0.4, "R")
			board_step_to(board, elapsed, quantum)
			var state: Dictionary = board.attack_effects.diagnostic_state()
			var fired: bool = elapsed >= 0.4
			var expected_count := 2 if fired else 1
			var origin_error: float = state.origin.distance_to(expected) if fired else 0.0
			var correct_sequence: bool = str(board.attack_hand) == "R" and str(board.next_attack_hand) == ("L" if fired else "R") and str(board.last_release_hand) == ("R" if fired else "L")
			outcomes.append({"quantum": quantum, "passed": prepared and accepted and correct_sequence and board.launch_count == expected_count and state.launch_count == expected_count and origin_error < 0.00001, "origin_error_world": origin_error, "sequence": sequence_state(board), "active": state.active, "projectile_active": state.projectile_active, "impact_active": state.impact_active, "position": state.projectile_position, "age": state.age, "pose": bones(board.skeleton)})
		var pose_error := transforms_error(outcomes[0].pose, outcomes[1].pose)
		var agree: bool = outcomes[0].active == outcomes[1].active and outcomes[0].projectile_active == outcomes[1].projectile_active and outcomes[0].impact_active == outcomes[1].impact_active and outcomes[0].position.distance_to(outcomes[1].position) < 0.00001 and pose_error < 0.00001
		for outcome in outcomes:
			outcome.erase("pose")
		releases.append({"elapsed": elapsed, "passed": agree and outcomes.all(func(item): return item.passed), "pose_error": pose_error, "outcomes": outcomes})
	check("Right release uses its own JSON hand socket and agrees for large/120Hz steps", releases.all(func(item): return item.passed), releases)
	details.right_release = releases
	var pauses: Array = []
	for phase in [0.06, 0.399, 0.45, 0.9]:
		var prepared := prepare_hand(board, "R")
		board.request_attack()
		board_step_to(board, phase, 1.0 / 60.0)
		var sequence := sequence_state(board)
		board.set_paused(true)
		var pose := bones(board.skeleton)
		var effect := tree_state(board.attack_effects)
		var left := tree_state(board.hand_fires.L)
		var right := tree_state(board.hand_fires.R)
		var state: Dictionary = board.attack_effects.diagnostic_state()
		var time: float = board.attack_time
		var fire_time: float = board.fire_elapsed
		var rejected: bool = not board.request_attack()
		board_step_to(board, 1.0, 1.0 / 30.0)
		var frozen: bool = prepared and rejected and sequence == sequence_state(board) and transforms_error(pose, bones(board.skeleton)) == 0.0 and effect == tree_state(board.attack_effects) and left == tree_state(board.hand_fires.L) and right == tree_state(board.hand_fires.R) and state == board.attack_effects.diagnostic_state() and board.attack_time == time and board.fire_elapsed == fire_time
		board.set_paused(false)
		var unpause_keeps_sequence: bool = sequence == sequence_state(board)
		board_step_to(board, 2.0, 1.0 / 60.0)
		var once: bool = unpause_keeps_sequence and board.launch_count == 2 and board.attack_effects.launch_count == 2 and not board.attacking and str(board.next_attack_hand) == "L" and str(board.last_release_hand) == "R"
		pauses.append({"phase": phase, "all_state_frozen": frozen, "resume_once_and_preserve_sequence": once})
	check("Right windup/pre-release/flight/impact pauses freeze pose, flames, effects and sequence", pauses.all(func(item): return item.all_state_frozen), pauses)
	check("Right resume preserves pending hand and never repeats the shot", pauses.all(func(item): return item.resume_once_and_preserve_sequence))
	details.right_pause = pauses
	var resets: Array = []
	for hand in ["L", "R"]:
		for phase in [0.06, 0.399, 0.45, 0.9, 1.3]:
			var prepared := prepare_hand(board, hand)
			board.request_attack()
			board_step_to(board, phase, 1.0 / 60.0)
			board.reset_actor()
			var state: Dictionary = board.attack_effects.diagnostic_state()
			var reset: bool = prepared and not board.attacking and board.attack_time == 0.0 and board.launch_count == 0 and str(board.next_attack_hand) == "L" and str(board.last_release_hand).is_empty() and not state.active and state.launch_count == 0 and state.age == 0.0 and board.hand_fires.L.visible and board.hand_fires.R.visible and not board.attack_marker.visible
			var accepted: bool = board.request_attack()
			board_tick(board, 0.4)
			var first_left: bool = accepted and board.launch_count == 1 and str(board.last_release_hand) == "L" and str(board.next_attack_hand) == "R"
			resets.append({"interrupted_hand": hand, "phase": phase, "reset_cleared_all_and_next_left": reset, "first_new_release_left": first_left, "passed": reset and first_left})
	check("Reset cancels either hand in every phase, clears both effect clocks and restarts with L", resets.all(func(item): return item.passed), resets)
	details.alternating_reset = resets
	var rejections: Array = []
	for hand in ["L", "R"]:
		var prepared := prepare_hand(board, hand)
		var before := sequence_state(board)
		board.set_paused(true)
		var paused_rejected: bool = not board.request_attack() and before == sequence_state(board)
		board.set_paused(false)
		var pause_roundtrip: bool = before == sequence_state(board)
		board.request_move(Vector2i(7, 4))
		board_tick(board, 0.04)
		var moving_rejected: bool = board.moving and not board.request_attack() and before == sequence_state(board)
		board_step_to(board, 10.0, 1.0 / 60.0)
		var move_complete: bool = not board.moving and before == sequence_state(board)
		var accepted: bool = board.request_attack()
		board_tick(board, 0.2)
		var pending := sequence_state(board)
		var busy_rejected: bool = not board.request_attack() and not board.request_move(Vector2i(8, 4)) and pending == sequence_state(board) and str(board.next_attack_hand) == hand
		board_tick(board, 0.2)
		var after := sequence_state(board)
		var after_release_rejected: bool = not board.request_attack() and after == sequence_state(board) and str(board.last_release_hand) == hand and str(board.next_attack_hand) == ("R" if hand == "L" else "L")
		rejections.append({"hand": hand, "paused": paused_rejected, "pause_roundtrip": pause_roundtrip, "moving": moving_rejected, "move_completed_same_hand": move_complete, "busy_before_release": busy_rejected, "busy_after_release": after_release_rejected, "passed": prepared and accepted and paused_rejected and pause_roundtrip and moving_rejected and move_complete and busy_rejected and after_release_rejected})
	check("Paused, moving and busy rejected requests never skip either hand", rejections.all(func(item): return item.passed), rejections)
	details.rejections = rejections
	var cancellations: Array = []
	for hand in ["L", "R"]:
		for phase in [0.0, 0.06, 0.399, 0.45, 0.9, 1.199]:
			var prepared := prepare_hand(board, hand)
			var initial_count: int = board.launch_count
			board.request_attack()
			board_step_to(board, phase, 1.0 / 60.0)
			var before := sequence_state(board)
			var effect: Dictionary = board.attack_effects.diagnostic_state()
			board.cancel_attack()
			var preserved: bool = not board.attacking and str(board.next_attack_hand) == before.next and str(board.last_release_hand) == before.last and board.launch_count == before.launches and effect == board.attack_effects.diagnostic_state()
			var pending_projectile_rejects: bool = not effect.active or (not board.request_attack() and str(board.next_attack_hand) == before.next and board.launch_count == before.launches)
			board_step_to(board, 2.0, 1.0 / 60.0)
			var no_late_release: bool = board.launch_count == before.launches and board.attack_effects.launch_count == before.launches and not board.attack_effects.is_active()
			var fired_before_cancel: bool = phase >= 0.4
			var expected: String = ("R" if hand == "L" else "L") if fired_before_cancel else hand
			var accepted: bool = board.request_attack()
			board_tick(board, 0.4)
			var resumed_correctly: bool = accepted and str(board.last_release_hand) == expected and board.launch_count == initial_count + (2 if fired_before_cancel else 1)
			cancellations.append({"hand": hand, "phase": phase, "cancellation_preserves_sequence_and_launched_effect": preserved, "pending_projectile_rejects_without_skip": pending_projectile_rejects, "no_delayed_release": no_late_release, "next_release": str(board.last_release_hand), "expected_next_release": expected, "passed": prepared and preserved and pending_projectile_rejects and no_late_release and resumed_correctly})
	check("Cancellation before release retries the same hand; cancellation after release retains the fired shot and next hand", cancellations.all(func(item): return item.passed), cancellations)
	details.cancellations = cancellations
	board.reset_actor()
	board.set_spell_demo(true)
	var loop_hands: Array = []
	var previous_count := 0
	for unused in 1200:
		board_tick(board, 1.0 / 60.0)
		if board.launch_count != previous_count:
			loop_hands.append(str(board.last_release_hand))
			previous_count = board.launch_count
		if loop_hands.size() >= 4:
			break
	check("The existing automatic spell demonstration also releases L/R/L/R", loop_hands == ["L", "R", "L", "R"], loop_hands)
	var flames: Array = []
	for hand in ["L", "R"]:
		for phase in [0.0, 0.2, 0.399, 0.4, 0.6, 0.72, 0.85, 1.0, 1.2]:
			var prepared := prepare_hand(board, hand)
			board.request_attack()
			board_step_to(board, phase, 1.0 / 60.0)
			var other := "R" if hand == "L" else "L"
			var expected := 1.0 + 0.22 * sin(phase / 0.4 * PI) if phase < 0.4 else smoothstep(0.72, 1.2, phase)
			var amount: float = board.hand_fires[hand].basis.get_scale().x / float(board.fire_sizes[hand])
			var other_amount: float = board.hand_fires[other].basis.get_scale().x / float(board.fire_sizes[other])
			var passed: bool = prepared and absf(amount - maxf(0.001, expected)) < 0.00001 and board.hand_fires[hand].visible == (expected > 0.005) and board.hand_fires[other].visible and absf(other_amount - 1.0) < 0.00001
			flames.append({"hand": hand, "phase": phase, "expected_scale": expected, "actual_scale": amount, "other_hand_scale": other_amount, "passed": passed})
	check("Only the casting flame vanishes at 0.4 and replenishes over 0.72–1.2 seconds", flames.all(func(item): return item.passed), flames)
	details.alternating_flames = flames

func integrated_tests() -> void:
	var board = load("res://board_controller.gd").new()
	root.add_child(board)
	board.set_process(false)
	await process_frame
	check("Spell clips and presentation-only attack effects are loaded", board.spell_loaded and board.attack_effects != null)
	if not board.spell_loaded or board.attack_effects == null:
		return
	animation_tests(board)
	var source_events: Array = board.spell_data.clips.FlameAttack.events
	check("One left-hand release event is exactly at 0.4 seconds", source_events.size() == 1 and source_events[0].name == "release" and source_events[0].hand == "L" and absf(board.release_time - 0.4) < 0.000001)
	var releases: Array = []
	for elapsed in [0.399, 0.4, 0.47, 0.9, 1.2, 2.0]:
		var outcomes: Array = []
		for quantum in [10.0, 1.0 / 60.0]:
			board.reset_actor()
			board.request_attack()
			var expected := json_hand_origin(board, 0.4)
			board_step_to(board, elapsed, quantum)
			var state: Dictionary = board.attack_effects.diagnostic_state()
			var fired := 1 if elapsed >= 0.4 else 0
			var origin_error: float = state.origin.distance_to(expected) if fired else 0.0
			var success: bool = board.launch_count == fired and state.launch_count == fired and origin_error < 0.00001
			outcomes.append({"quantum": quantum, "passed": success, "origin_error_world": origin_error, "controller_launches": board.launch_count, "effect_launches": state.launch_count, "active": state.active, "projectile_active": state.projectile_active, "impact_active": state.impact_active, "position": state.projectile_position, "age": state.age})
		var agree: bool = outcomes[0].active == outcomes[1].active and outcomes[0].projectile_active == outcomes[1].projectile_active and outcomes[0].impact_active == outcomes[1].impact_active and outcomes[0].position.distance_to(outcomes[1].position) < 0.00001
		releases.append({"elapsed": elapsed, "passed": agree and outcomes.all(func(item): return item.passed), "outcomes": outcomes})
	check("Release boundary, exact JSON socket and large/subdivided time steps agree", releases.all(func(item): return item.passed), releases)
	var pause_reports: Array = []
	for phase in [0.06, 0.399, 0.45, 0.9]:
		board.reset_actor()
		board.request_attack()
		board_step_to(board, phase, 1.0 / 60.0)
		board.set_paused(true)
		var pose := bones(board.skeleton)
		var effect := tree_state(board.attack_effects)
		var left := tree_state(board.hand_fires.L)
		var right := tree_state(board.hand_fires.R)
		var state: Dictionary = board.attack_effects.diagnostic_state()
		var time: float = board.attack_time
		var fire_time: float = board.fire_elapsed
		var launches: int = board.launch_count
		board_step_to(board, 1.0, 1.0 / 30.0)
		var frozen: bool = transforms_error(pose, bones(board.skeleton)) == 0.0 and effect == tree_state(board.attack_effects) and left == tree_state(board.hand_fires.L) and right == tree_state(board.hand_fires.R) and state == board.attack_effects.diagnostic_state() and board.attack_time == time and board.fire_elapsed == fire_time and board.launch_count == launches
		board.set_paused(false)
		board_step_to(board, 2.0, 1.0 / 60.0)
		var once: bool = board.launch_count == 1 and board.attack_effects.launch_count == 1 and not board.attacking
		pause_reports.append({"phase": phase, "fully_frozen": frozen, "resume_exactly_one_release": once})
	check("Windup, pre-release, flight and impact pauses freeze all clocks and visual nodes", pause_reports.all(func(item): return item.fully_frozen), pause_reports)
	check("Resume never repeats an already released shot", pause_reports.all(func(item): return item.resume_exactly_one_release))
	var resets: Array = []
	for phase in [0.06, 0.399, 0.45, 0.9, 1.3]:
		board.reset_actor()
		board.request_attack()
		board_step_to(board, phase, 1.0 / 60.0)
		board.reset_actor()
		var state: Dictionary = board.attack_effects.diagnostic_state()
		resets.append({"phase": phase, "passed": not board.attacking and board.attack_time == 0.0 and board.launch_count == 0 and not state.active and state.launch_count == 0 and state.age == 0.0 and board.hand_fires.L.visible and board.hand_fires.R.visible and not board.attack_marker.visible})
	check("Reset during every attack phase clears projectile/impact and restores both hand fires", resets.all(func(item): return item.passed), resets)
	board.reset_actor()
	board.request_move(Vector2i(7, 4))
	board_tick(board, 0.04)
	check("Attack is rejected while moving", board.moving and not board.request_attack() and board.launch_count == 0)
	board.reset_actor()
	board.request_attack()
	var position: Vector3 = board.actor.position
	var rejected: bool = not board.request_move(Vector2i(7, 4)) and not board.request_attack()
	board_tick(board, 0.5)
	check("Attack rejects move and repeat-attack requests without changing position", rejected and board.actor.position == position and board.route.is_empty() and board.launch_count == 1)
	check("Released left fire is extinguished while the right hand stays lit", not board.hand_fires.L.visible and board.hand_fires.R.visible)
	board_step_to(board, 0.5, 1.0 / 60.0)
	check("Left hand fire replenishes during recovery", board.hand_fires.L.visible and board.hand_fires.R.visible and board.attack_time > 0.72)
	board.reset_actor()
	board.actor.position = Vector3(5.2, 0, -2.6)
	board.actor.rotation.y = PI * 0.25
	board.request_attack()
	var direction: Vector3 = board.attack_target - board.actor.position
	direction.y = 0.0
	check("Clamped board-edge target matches the actor casting direction", board.actor.global_basis.z.normalized().dot(direction.normalized()) > 0.99999)
	details.release = releases
	details.pause = pause_reports
	details.reset = resets
	alternating_tests(board)
	board.queue_free()

func run() -> void:
	details.test_runner_notes = ["First invocation found three GDScript type-inference errors in new test locals, before any assertions ran. Explicit bool/String annotations fixed the test fixture; no production code was changed. The headless rerun directs its log to /private/tmp because the sandbox cannot write the default user log directory."]
	var before := hashes()
	await component_tests()
	if not options.has("component-only"):
		check("Original model is unchanged", before.get("assets/foxfire-board.glb") == MODEL_SHA)
		check("Final spell animation data exists", FileAccess.file_exists("res://assets/spell-animations.json"))
		if FileAccess.file_exists("res://assets/spell-animations.json"):
			await integrated_tests()
	check("Tested source files did not change during this run", before == hashes())
	var result := {"schema": 2, "baseline_commit": BASELINE_COMMIT, "phase": "component-only" if options.has("component-only") else "alternating-integrated", "integration_pending": options.has("component-only"), "scope": "Independent headless state/clock/pose/component review. No GPU, frame-rate benchmark, gameplay damage or visual acceptance.", "engine": Engine.get_version_info().string, "created_at_utc": Time.get_datetime_string_from_system(true) + "Z", "hashes": before, "checks": checks, "details": details, "passed": checks.all(func(item): return item.passed), "passed_count": checks.filter(func(item): return item.passed).size(), "check_count": checks.size()}
	var output := str(options.get("output", "/private/tmp/spell-component-independent.json" if options.has("component-only") else "res://reports/alternating-fire-independent.json"))
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	print(JSON.stringify({"phase": result.phase, "passed": result.passed, "passed_count": result.passed_count, "check_count": result.check_count, "output": output}))
	quit(0 if result.passed else 1)
