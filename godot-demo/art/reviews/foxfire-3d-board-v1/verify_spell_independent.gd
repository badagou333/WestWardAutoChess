extends SceneTree

# Independent test entry point. Component checks do not load the controller or
# require unfinished animation data. No GPU, production damage or OS input.
# Godot --headless --path <project> --script res://verify_spell_independent.gd -- --component-only
# Omit --component-only for the final integrated report after assets are ready.
const MODEL_SHA := "4257ac78a80ade3bbd328212c9341ecf9f775a7a8452aef7f8a2fc0875cfaa57"
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

func json_hand_origin(board: Node3D, time: float) -> Vector3:
	var skeleton: Skeleton3D = board.skeleton
	var positions: Array = []
	var rotations: Array = []
	var scales: Array = []
	for index in skeleton.get_bone_count():
		var rest := skeleton.get_bone_rest(index)
		positions.append(rest.origin)
		rotations.append(rest.basis.get_rotation_quaternion())
		scales.append(rest.basis.get_scale())
	for track in board.spell_data.clips.FlameAttack.tracks:
		var index := skeleton.find_bone(track.bone)
		match str(track.path):
			"translation": positions[index] = sample(track, time)
			"rotation": rotations[index] = sample(track, time)
			"scale": scales[index] = sample(track, time)
	var index := skeleton.find_bone("hand.L")
	var chain := Transform3D(Basis(rotations[index]).scaled(scales[index]), positions[index])
	index = skeleton.get_bone_parent(index)
	while index >= 0:
		chain = Transform3D(Basis(rotations[index]).scaled(scales[index]), positions[index]) * chain
		index = skeleton.get_bone_parent(index)
	var local_offset := v(board.dual_fire_data.palm_offsets.L.position)
	return skeleton.global_transform * (chain * local_offset) + Vector3.UP * float(board.dual_fire_data.orbs.L.up_offset) * 1.65

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
	for name in ["SpellIdle", "FlameAttack"]:
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
	var actual := player.get_animation(board.run_animation)
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
	ref_model.queue_free()
	board.reset_actor()

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
	board.queue_free()

func run() -> void:
	var before := hashes()
	await component_tests()
	if not options.has("component-only"):
		check("Original model is unchanged", before.get("assets/foxfire-board.glb") == MODEL_SHA)
		check("Final spell animation data exists", FileAccess.file_exists("res://assets/spell-animations.json"))
		if FileAccess.file_exists("res://assets/spell-animations.json"):
			await integrated_tests()
	check("Tested source files did not change during this run", before == hashes())
	var result := {"schema": 1, "phase": "component-only" if options.has("component-only") else "integrated", "integration_pending": options.has("component-only"), "scope": "Independent headless state/clock/pose/component review. No GPU, frame-rate benchmark, gameplay damage or visual acceptance.", "engine": Engine.get_version_info().string, "created_at_utc": Time.get_datetime_string_from_system(true) + "Z", "hashes": before, "checks": checks, "details": details, "passed": checks.all(func(item): return item.passed), "passed_count": checks.filter(func(item): return item.passed).size(), "check_count": checks.size()}
	var output := str(options.get("output", "/private/tmp/spell-component-independent.json" if options.has("component-only") else "res://reports/spell-independent.json"))
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	print(JSON.stringify({"phase": result.phase, "passed": result.passed, "passed_count": result.passed_count, "check_count": result.check_count, "output": output}))
	quit(0 if result.passed else 1)
