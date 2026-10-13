extends RefCounted

func run(board: Node3D) -> Dictionary:
	var checks: Array[Dictionary] = []
	_check(checks, "真实角色资源已载入", board.asset_loaded)
	_check(checks, "Run 与 Idle 动画具备", not str(board.run_animation).is_empty() and not str(board.idle_animation).is_empty())
	var mappings_ok := true
	for column in range(board.COLS):
		for row in range(board.ROWS):
			var cell := Vector2i(column, row)
			mappings_ok = mappings_ok and board.world_to_cell(board.cell_to_world(cell)) == cell
	_check(checks, "84 个逻辑格与世界脚点双向一致", mappings_ok)
	var offboard_rejected: bool = not board.request_move(Vector2i(-1, 2)) and not board.request_move(Vector2i(12, 2))
	_check(checks, "越界目标拒绝", offboard_rejected)
	board.blocked.append(Vector2i(5, 4))
	var path: Array[Vector2i] = board.find_path(Vector2i(4, 4), Vector2i(6, 4))
	var avoids := not path.is_empty() and not path.has(Vector2i(5, 4))
	var previous := Vector2i(4, 4)
	for cell in path:
		avoids = avoids and absi(cell.x - previous.x) + absi(cell.y - previous.y) == 1
		previous = cell
	_check(checks, "寻路绕开阻挡且逐格相邻", avoids)
	board.blocked.clear()
	board.reset_actor()
	board.request_move(Vector2i(9, 1))
	board._step_simulation(0.1)
	var before: Vector3 = board.actor.position
	board.set_paused(true)
	board._step_simulation(1.0)
	_check(checks, "暂停冻结世界移动", board.actor.position.is_equal_approx(before))
	_check(checks, "暂停期间拒绝改目标", not board.request_move(Vector2i(1, 1)))
	board.set_paused(false)
	var ground := true
	for frame in range(900):
		board._step_simulation(1.0 / 60.0)
		ground = ground and is_zero_approx(board.actor.position.y)
	_check(checks, "抵达目标格心并停止", board.current_cell == Vector2i(9, 1) and board.route.is_empty() and not board.moving and board.actor.position.distance_to(board.cell_to_world(Vector2i(9, 1))) < 0.0001)
	_check(checks, "人物只在 XZ 平面移动", ground)
	board.reset_actor()
	board.request_move(Vector2i(9, 4))
	board._step_simulation(0.13)
	before = board.actor.position
	board.request_move(Vector2i(3, 2))
	_check(checks, "中途改目标不瞬移", board.actor.position.is_equal_approx(before))
	for frame in range(500):
		board._step_simulation(1.0 / 60.0)
	_check(checks, "中途重新寻路抵达新目标", board.current_cell == Vector2i(3, 2) and board.route.is_empty())
	var camera_ok := true
	for mode in [1, 2, 3, 4]:
		board.set_camera(mode)
		camera_ok = camera_ok and board.camera_mode == mode and board.camera.current
	_check(checks, "四镜头共用同一真实三维世界", camera_ok)
	board.reset_actor()
	board.set_auto(true)
	for frame in range(3600):
		board._step_simulation(1.0 / 60.0)
	_check(checks, "自动漫游持续真实走格", board.travel_log.size() > 40)
	board.set_auto(false)
	board.reset_actor()
	var passed := true
	for check in checks:
		passed = passed and check.passed
	return {"passed": passed, "scope": "隔离三维候选的程序逻辑与资源检查；不替代图形点击、正常窗口视觉或性能验收", "checks": checks, "animations": board.animation_names, "rendering_method": RenderingServer.get_current_rendering_method()}

func _check(checks: Array[Dictionary], title: String, passed: bool) -> void:
	checks.append({"name": title, "passed": passed})

func run_input(board: Node3D) -> Dictionary:
	var checks: Array[Dictionary] = []
	var tree := board.get_tree()
	for unused in range(3):
		await tree.process_frame
	board.reset_actor()
	var target := Vector2i(7, 3)
	var screen: Vector2 = board.camera.unproject_position(board.cell_to_world(target))
	_check(checks, "相机投影拾取与格心一致", board._screen_cell(screen) == target)
	_click(board.get_viewport().get_final_transform() * screen)
	await tree.process_frame
	await tree.process_frame
	_check(checks, "真实视口输入分发接受地面点击", board.destination == target and not board.route.is_empty())
	_key(KEY_SPACE)
	await tree.process_frame
	var before: Vector3 = board.actor.position
	var animation_before: float = board.animation_player.current_animation_position
	await tree.create_timer(0.2).timeout
	_check(checks, "空格暂停位置与骨骼播放", board.paused and board.actor.position.distance_to(before) < 0.00001 and absf(board.animation_player.current_animation_position - animation_before) < 0.00001)
	_key(KEY_SPACE)
	await tree.process_frame
	_check(checks, "空格恢复状态与动画速率", not board.paused and is_equal_approx(board.animation_player.speed_scale, board.RUN_PLAYBACK_SPEED if board.moving else 1.0))
	var elapsed := 0.0
	while not board.route.is_empty() and elapsed < 6.0:
		await tree.create_timer(0.1).timeout
		elapsed += 0.1
	_check(checks, "点击后真实时钟抵达并切回Idle", board.current_cell == target and board.route.is_empty() and board.animation_player.current_animation == board.idle_animation)
	_key(KEY_1)
	await tree.process_frame
	_check(checks, "数字键切换镜头", board.camera_mode == 1)
	var prior_grid: bool = board.grid.visible
	_key(KEY_G)
	await tree.process_frame
	_check(checks, "G键切换格线", board.grid.visible != prior_grid)
	_click(board.get_viewport().get_final_transform() * board.hud.auto_button.get_global_rect().get_center())
	await tree.process_frame
	await tree.process_frame
	_check(checks, "GUI按钮点击启动漫游且不穿透棋盘", board.auto_demo)
	_key(KEY_R)
	await tree.process_frame
	_check(checks, "R归位停止漫游并清空路径", not board.auto_demo and board.current_cell == board.HOME and board.route.is_empty())
	if board.spell_loaded:
		var buttons: Array = board.hud.find_children("*", "Button", true, false)
		var layout_ok := true
		for index in range(buttons.size()):
			var rect: Rect2 = buttons[index].get_global_rect()
			layout_ok = layout_ok and board.get_viewport().get_visible_rect().encloses(rect)
			for other in range(index + 1, buttons.size()):
				layout_ok = layout_ok and not rect.intersects(buttons[other].get_global_rect())
		_check(checks, "新增动作按钮与原控件在视口内且互不重叠", layout_ok)
		_key(KEY_F)
		await tree.process_frame
		await tree.process_frame
		_check(checks, "F键触发真实火攻动作", board.attacking and board.animation_player.current_animation == board.attack_animation)
		_key(KEY_SPACE)
		await tree.process_frame
		var attack_before: float = board.attack_time
		var launches_before: int = board.launch_count
		await tree.create_timer(0.3).timeout
		_check(checks, "起手暂停不偷偷发射火球", board.paused and is_equal_approx(board.attack_time, attack_before) and board.launch_count == launches_before)
		_key(KEY_SPACE)
		await tree.create_timer(1.8).timeout
		_check(checks, "恢复后仅发射一次并收回待机", board.launch_count == 1 and not board.attacking and board.animation_player.current_animation == board.idle_animation)
		_click(board.get_viewport().get_final_transform() * board.hud.attack_button.get_global_rect().get_center())
		await tree.process_frame
		await tree.process_frame
		_check(checks, "火攻按钮触发动画且不穿透为地面移动", board.attacking and board.route.is_empty())
		_key(KEY_R)
		await tree.process_frame
		_check(checks, "R键取消动作且清除残余火球", not board.attacking and not board.attack_effects.is_active() and board.launch_count == 0)
	var passed := true
	for check in checks:
		passed = passed and check.passed
	return {"passed": passed, "scope": "通过Input.parse_input_event向真实Godot视口注入点击和按键，验证GUI事件分发；不是真人鼠标/OS自动化验收", "checks": checks, "rendering_method": RenderingServer.get_current_rendering_method()}

func _click(position: Vector2) -> void:
	var move := InputEventMouseMotion.new()
	move.position = position
	move.global_position = position
	Input.parse_input_event(move)
	for is_pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.position = position
		click.global_position = position
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = is_pressed
		Input.parse_input_event(click)

func _key(keycode: Key) -> void:
	for is_pressed in [true, false]:
		var key := InputEventKey.new()
		key.physical_keycode = keycode
		key.keycode = keycode
		key.pressed = is_pressed
		Input.parse_input_event(key)
