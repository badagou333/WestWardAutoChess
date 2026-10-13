extends Node3D

const WorldBuilder = preload("res://world_builder.gd")
const TrialUI = preload("res://ui.gd")
const Verifier = preload("res://verify.gd")
const COLS := 12
const ROWS := 7
const MOVE_SPEED := 2.35
const RUN_PLAYBACK_SPEED := 0.65
const ACTOR_SCALE := 1.65
const HOME := Vector2i(4, 4)
const AUTO_ROUTE := [Vector2i(8, 4), Vector2i(8, 1), Vector2i(3, 1), Vector2i(3, 5), Vector2i(7, 5), HOME]

var actor: Node3D
var model: Node3D
var animation_player: AnimationPlayer
var run_animation: StringName
var idle_animation: StringName
var camera: Camera3D
var grid: Node3D
var marker: Node3D
var hover_marker: Node3D
var trail: Node3D
var hud: CanvasLayer
var blocked: Array[Vector2i] = []
var current_cell := HOME
var destination := HOME
var route: Array[Vector2i] = []
var paused := false
var auto_demo := false
var auto_index := 0
var auto_wait := 0.0
var moving := false
var camera_mode := 2
var actor_yaw := 0.0
var travel_log: Array[Vector2i] = []
var options: Dictionary = {}
var asset_loaded := false
var animation_names: Array[String] = []
var performance_samples: Array[float] = []
var performance_process_ms: Array[float] = []
var performance_draw_calls: Array[float] = []
var performance_last_usec := 0
var performance_collecting := false

func _ready() -> void:
	options = _arguments()
	if options.has("taa"):
		get_viewport().use_taa = str(options.taa) != "off"
	var world: Dictionary = WorldBuilder.build(self)
	grid = world.get("grid")
	for value in world.get("blocked", []):
		blocked.append(value)
	_build_camera()
	_build_actor()
	_build_markers()
	hud = TrialUI.new()
	add_child(hud)
	hud.build(self)
	reset_actor()
	set_camera(int(options.get("camera", "2")))
	if options.has("at"):
		var components: PackedStringArray = str(options.at).split(",")
		if components.size() == 2:
			current_cell = Vector2i(clampi(int(components[0]), 0, COLS - 1), clampi(int(components[1]), 0, ROWS - 1))
			destination = current_cell
			actor.position = cell_to_world(current_cell)
	if options.has("yaw"):
		actor.rotation.y = deg_to_rad(float(options.yaw))
	if camera_mode == 4:
		_update_detail_camera()
	if options.has("hide-ui"):
		hud.hide()
	if options.has("grid") and grid:
		grid.visible = str(options.grid) != "off"
	if options.has("auto"):
		set_auto(true)
	if options.has("verify"):
		call_deferred("_verify")
	elif options.has("input-verify"):
		call_deferred("_verify_input")
	elif options.has("performance"):
		call_deferred("_measure_performance")
	elif options.has("capture") or options.has("sequence"):
		call_deferred("_capture")

func _arguments() -> Dictionary:
	var result: Dictionary = {}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--"):
			var pair := argument.trim_prefix("--").split("=", true, 1)
			result[pair[0]] = pair[1] if pair.size() > 1 else "true"
	return result

func _build_camera() -> void:
	camera = Camera3D.new()
	camera.name = "FixedBattleCamera"
	add_child(camera)
	camera.near = 0.1
	camera.far = 100.0
	camera.current = true

func set_camera(value: int) -> void:
	camera_mode = clampi(value, 1, 4)
	match camera_mode:
		1:
			camera.projection = Camera3D.PROJECTION_PERSPECTIVE
			camera.fov = 34.0
			camera.position = Vector3(6.0, 12.0, 21.0)
		2:
			camera.projection = Camera3D.PROJECTION_ORTHOGONAL
			camera.size = 12.0
			camera.position = Vector3(7.0, 16.0, 19.0)
		3:
			camera.projection = Camera3D.PROJECTION_ORTHOGONAL
			camera.size = 11.8
			camera.position = Vector3(4.0, 23.0, 13.0)
		4:
			camera.projection = Camera3D.PROJECTION_ORTHOGONAL
			camera.size = 6.4
	if camera_mode == 4 and actor:
		_update_detail_camera()
	else:
		camera.look_at(Vector3(0, 0.35, -0.3) if camera_mode == 2 else Vector3(0, 0.1, 0), Vector3.UP)
	if hud:
		hud.refresh()

func _build_actor() -> void:
	actor = Node3D.new()
	actor.name = "FoxfireActor"
	add_child(actor)
	var asset := "res://assets/foxfire-board.glb"
	if ResourceLoader.exists(asset):
		var packed = load(asset)
		if packed is PackedScene:
			model = packed.instantiate()
			model.name = "FoxfireModel"
			model.scale = Vector3.ONE * ACTOR_SCALE
			actor.add_child(model)
			asset_loaded = true
			animation_player = _find_animation_player(model)
	if not asset_loaded:
		push_error("缺少狐火模型：assets/foxfire-board.glb。不得把此状态当作可交付画面。")
		return
	if animation_player:
		for clip in animation_player.get_animation_list():
			animation_names.append(str(clip))
			var short_name := str(clip).get_slice("/", str(clip).get_slice_count("/") - 1).to_lower()
			if short_name == "run" or short_name.ends_with("run"):
				run_animation = clip
			if short_name == "idle" or short_name.ends_with("idle"):
				idle_animation = clip
		for clip in [run_animation, idle_animation]:
			if not str(clip).is_empty():
				animation_player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		_play(false)

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var result := _find_animation_player(child)
		if result:
			return result
	return null

func _build_markers() -> void:
	marker = _ring("Destination", Color(1.0, 0.65, 0.25, 0.9), 0.28)
	add_child(marker)
	marker.hide()
	hover_marker = _ring("HoverCell", Color(0.76, 0.9, 0.83, 0.55), 0.38)
	add_child(hover_marker)
	hover_marker.hide()
	trail = Node3D.new()
	trail.name = "RouteMarkers"
	add_child(trail)

func _ring(title: String, tint: Color, radius: float) -> Node3D:
	var node := MeshInstance3D.new()
	node.name = title
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - 0.013
	mesh.outer_radius = radius + 0.013
	mesh.rings = 48
	mesh.ring_segments = 6
	node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = false
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node

func cell_to_world(cell: Vector2i) -> Vector3:
	return Vector3(float(cell.x) - 5.5, 0.0, float(cell.y) - 3.0)

func world_to_cell(point: Vector3) -> Vector2i:
	return Vector2i(floori(point.x + 6.0), floori(point.z + 3.5))

func valid_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < COLS and cell.y >= 0 and cell.y < ROWS and not blocked.has(cell)

func _screen_cell(screen_position: Vector2) -> Vector2i:
	var start := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	var hit = Plane(Vector3.UP, 0).intersects_ray(start, direction)
	return world_to_cell(hit) if hit != null else Vector2i(-1, -1)

func request_move(target: Vector2i) -> bool:
	if not valid_cell(target) or paused:
		return false
	# Replan from the current edge endpoint, never snap a moving actor to a cell.
	var start := current_cell
	var retain: Array[Vector2i] = []
	if not route.is_empty() and actor.position.distance_to(cell_to_world(current_cell)) > 0.005:
		start = route[0]
		retain.append(start)
	var next_route := find_path(start, target)
	if start != target and next_route.is_empty():
		return false
	route = retain + next_route
	destination = target
	marker.position = cell_to_world(target) + Vector3(0, 0.03, 0)
	marker.visible = not route.is_empty()
	_show_route()
	return true

func find_path(start: Vector2i, target: Vector2i) -> Array[Vector2i]:
	var empty: Array[Vector2i] = []
	if not valid_cell(start) or not valid_cell(target) or start == target:
		return empty
	var frontier: Array[Vector2i] = [start]
	var came_from: Dictionary = {start: start}
	var cursor := 0
	while cursor < frontier.size():
		var cell := frontier[cursor]
		cursor += 1
		if cell == target:
			break
		for direction in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
			var neighbor: Vector2i = cell + direction
			if valid_cell(neighbor) and not came_from.has(neighbor):
				came_from[neighbor] = cell
				frontier.append(neighbor)
	if not came_from.has(target):
		return empty
	var result: Array[Vector2i] = []
	var cell := target
	while cell != start:
		result.push_front(cell)
		cell = came_from[cell]
	return result

func _show_route() -> void:
	for child in trail.get_children():
		trail.remove_child(child)
		child.queue_free()
	for cell in route:
		if cell == destination:
			continue
		var dot := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.028
		sphere.height = 0.015
		sphere.radial_segments = 8
		sphere.rings = 4
		dot.mesh = sphere
		dot.position = cell_to_world(cell) + Vector3(0, 0.025, 0)
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.92, 0.65, 0.28, 0.6)
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		dot.material_override = material
		dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		trail.add_child(dot)

func _process(delta: float) -> void:
	if performance_collecting:
		var now := Time.get_ticks_usec()
		performance_samples.append(float(now - performance_last_usec) / 1000.0)
		performance_last_usec = now
		performance_process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		performance_draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	_step_simulation(delta)
	if camera_mode == 4:
		_update_detail_camera()
	if hud:
		hud.refresh()

func _step_simulation(delta: float) -> void:
	if paused:
		return
	if auto_demo and route.is_empty():
		auto_wait -= delta
		if auto_wait <= 0:
			request_move(AUTO_ROUTE[auto_index % AUTO_ROUTE.size()])
			auto_index += 1
			auto_wait = 0.85
	var did_move := not route.is_empty()
	if did_move:
		var budget := MOVE_SPEED * delta
		while budget > 0 and not route.is_empty():
			var target := cell_to_world(route[0])
			var difference := target - actor.position
			var distance := difference.length()
			if distance > 0.0001:
				actor_yaw = atan2(difference.x, difference.z)
				actor.rotation.y = lerp_angle(actor.rotation.y, actor_yaw, minf(1.0, delta * 12.0))
			var step := minf(budget, distance)
			actor.position = actor.position.move_toward(target, step)
			actor.position.y = 0.0
			budget -= step
			if actor.position.distance_to(target) < 0.0001:
				current_cell = route.pop_front()
				travel_log.append(current_cell)
				_show_route()
			else:
				break
		if route.is_empty():
			marker.hide()
	_play(not route.is_empty())

func _update_detail_camera() -> void:
	camera.position = actor.position + Vector3(4.0, 5.3, 7.7)
	camera.look_at(actor.position + Vector3(0, 0.65, 0), Vector3.UP)

func _play(is_moving: bool) -> void:
	moving = is_moving
	if not animation_player:
		return
	animation_player.speed_scale = 0.0 if paused else (RUN_PLAYBACK_SPEED if is_moving else 1.0)
	var clip := run_animation if is_moving else idle_animation
	if str(clip).is_empty():
		return
	if animation_player.current_animation != clip or not animation_player.is_playing():
		animation_player.play(clip, 0.18)

func set_paused(value: bool) -> void:
	paused = value
	if animation_player:
		animation_player.speed_scale = 0.0 if paused else (RUN_PLAYBACK_SPEED if moving else 1.0)
	if hud:
		hud.refresh()

func set_auto(value: bool) -> void:
	auto_demo = value
	auto_wait = 0.0
	if hud:
		hud.refresh()

func toggle_grid() -> void:
	if grid:
		grid.visible = not grid.visible
	if hud:
		hud.refresh()

func reset_actor() -> void:
	auto_demo = false
	route.clear()
	current_cell = HOME
	destination = HOME
	actor.position = cell_to_world(HOME)
	actor.rotation.y = -0.43633
	actor_yaw = actor.rotation.y
	travel_log.clear()
	auto_index = 0
	auto_wait = 0.8
	marker.hide()
	_show_route()
	set_paused(false)
	_play(false)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var cell := _screen_cell(event.position)
		hover_marker.visible = valid_cell(cell) and not paused
		if hover_marker.visible:
			hover_marker.position = cell_to_world(cell) + Vector3(0, 0.025, 0)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		set_auto(false)
		request_move(_screen_cell(event.position))
		get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1: set_camera(1)
			KEY_2: set_camera(2)
			KEY_3: set_camera(3)
			KEY_4: set_camera(4)
			KEY_G: toggle_grid()
			KEY_SPACE: set_paused(not paused)
			KEY_R: reset_actor()
			KEY_ESCAPE: set_auto(false)

func _verify() -> void:
	set_process(false)
	var result: Dictionary = Verifier.new().run(self)
	var target := str(options.get("report", "user://verification.json"))
	var file := FileAccess.open(target, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(result, "\t"))
	print(JSON.stringify(result))
	get_tree().quit(0 if result.passed else 1)

func _verify_input() -> void:
	var result: Dictionary = await Verifier.new().run_input(self)
	var target := str(options.get("report", "user://input-verification.json"))
	var file := FileAccess.open(target, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(result, "\t"))
	print(JSON.stringify(result))
	get_tree().quit(0 if result.passed else 1)

func _measure_performance() -> void:
	set_auto(true)
	await get_tree().create_timer(8.0).timeout
	performance_samples.clear()
	performance_last_usec = Time.get_ticks_usec()
	var started := performance_last_usec
	performance_collecting = true
	await get_tree().create_timer(12.0).timeout
	performance_collecting = false
	var elapsed := float(Time.get_ticks_usec() - started) / 1000000.0
	performance_samples.sort()
	performance_process_ms.sort()
	performance_draw_calls.sort()
	var result := {
		"scope": "本机单角色独立试场正常窗口自动漫游；8秒预热、约12秒取样，无截图写盘，不代表多角色或其他硬件通过",
		"renderer": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(),
		"window_pixels": str(DisplayServer.window_get_size()),
		"logical_viewport": str(get_viewport().get_visible_rect().size),
		"elapsed_seconds": elapsed,
		"sample_count": performance_samples.size(),
		"average_fps": performance_samples.size() / elapsed,
		"frame_interval_ms": {"p50": _percentile(performance_samples, .50), "p95": _percentile(performance_samples, .95), "p99": _percentile(performance_samples, .99), "max": _percentile(performance_samples, 1.0)},
		"engine_time_process_ms_p95": _percentile(performance_process_ms, .95),
		"engine_time_process_note": "Godot TIME_PROCESS监视值，并非隔离CPU耗时；帧时统计以实际相邻_process入口时间差为准",
		"draw_calls_p50": _percentile(performance_draw_calls, .50),
		"draw_calls_max": _percentile(performance_draw_calls, 1.0),
		"last_frame_objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"last_frame_primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"vsync_mode": DisplayServer.window_get_vsync_mode(),
		"fps_limit": Engine.max_fps,
		"taa": get_viewport().use_taa,
		"msaa_3d": get_viewport().msaa_3d,
		"ssao_quality": ProjectSettings.get_setting("rendering/environment/ssao/quality"),
		"ssao_half_size": ProjectSettings.get_setting("rendering/environment/ssao/half_size"),
		"unit_count": 1,
		"actor_scale": ACTOR_SCALE,
		"move_speed": MOVE_SPEED,
		"run_playback_speed": RUN_PLAYBACK_SPEED,
	}
	var target := str(options.get("report", "user://performance.json"))
	var file := FileAccess.open(target, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(result, "\t"))
	print(JSON.stringify(result))
	get_tree().quit()

func _percentile(values: Array[float], fraction: float) -> float:
	if values.is_empty():
		return 0.0
	return values[clampi(ceili((values.size() - 1) * fraction), 0, values.size() - 1)]

func _capture() -> void:
	set_process(false)
	if animation_player:
		animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		var requested_clip := str(options.get("pose", "Idle")).to_lower()
		var selected_clip := run_animation if requested_clip == "run" else idle_animation
		if not str(selected_clip).is_empty():
			animation_player.play(selected_clip, 0.0)
			animation_player.seek(float(options.get("time", "0.6")), true)
	if options.has("destination"):
		var pair: PackedStringArray = str(options.destination).split(",")
		if pair.size() == 2:
			request_move(Vector2i(int(pair[0]), int(pair[1])))
	for unused in range(32):
		await get_tree().process_frame
	if options.has("sequence"):
		var directory := str(options.sequence)
		DirAccess.make_dir_recursive_absolute(directory)
		var fps := maxi(1, int(options.get("fps", "15")))
		var count := maxi(1, int(float(options.get("duration", "8")) * fps))
		for index in range(count):
			_step_simulation(1.0 / fps)
			if camera_mode == 4:
				_update_detail_camera()
			if animation_player:
				animation_player.advance(1.0 / fps)
			hud.refresh()
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(directory.path_join("frame-%04d.png" % index))
			await get_tree().process_frame
	else:
		await RenderingServer.frame_post_draw
		var path := str(options.capture)
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		var code := get_viewport().get_texture().get_image().save_png(path)
		print("CAPTURE ", path, " code=", code)
	get_tree().quit()
